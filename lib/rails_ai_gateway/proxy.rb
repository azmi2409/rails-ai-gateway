require "net/http"
require "json"
require "ipaddr"
require "socket"
require "timeout"
require "securerandom"

module RailsAiGateway
  class Proxy
    class Failure < StandardError
      attr_reader :status

      def initialize(message, status = 502)
        @status = status
        super(message)
      end
    end

    # Bounded queue applies backpressure. Rack closes the body on disconnect.
    class Stream
      def initialize(queue, thread)
        @queue, @thread = queue, thread
      end

      def each
        loop do
          chunk = @queue.pop
          break if chunk.nil?
          yield chunk
        end
      ensure
        close
      end

      def close
        @thread.kill if @thread.alive?
        @thread.join
      end
    end

    RETRY_STATUSES = [429, 500, 502, 503, 504].freeze
    ERROR_TYPES = {
      400 => ["invalid_request_error", "invalid_request"],
      401 => ["authentication_error", "invalid_api_key"],
      403 => ["permission_error", "permission_denied"],
      404 => ["invalid_request_error", "model_not_found"],
      409 => ["conflict_error", "conflict"],
      422 => ["invalid_request_error", "unprocessable_entity"],
      429 => ["rate_limit_error", "rate_limit_exceeded"]
    }.freeze
    PRIVATE_RANGES = %w[0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16
      172.16.0.0/12 192.0.0.0/24 192.0.2.0/24 192.168.0.0/16 198.18.0.0/15
      198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 ::/128 ::1/128
      fc00::/7 fe80::/10 ff00::/8 2001:db8::/32].map { |range| IPAddr.new(range) }.freeze

    def initialize(endpoint)
      @endpoint = endpoint
    end

    def call(env)
      request = Rack::Request.new(env)
      token = request.get_header("HTTP_AUTHORIZATION").to_s[/\ABearer (\S+)\z/i, 1]
      key = GatewayKey.authenticate(token)
      return error("Invalid or expired gateway key", 401) unless key

      if @endpoint == "models"
        names = ModelRoute.available.distinct.pluck(:name).select { |name| key.allows?(name) }.sort
        return json(200, object: "list", data: names.map { |name| { id: name, object: "model", created: 0, owned_by: "rails_ai_gateway" } })
      end

      payload = parse_request(request)
      return error("Model is not allowed", 403) unless key.allows?(payload["model"])
      routes = ModelRoute.available.where(name: payload["model"]).includes(:provider).order(:priority).limit(config.max_attempts).to_a
      return error("No route for requested model", 404) if routes.empty?

      log = RequestLog.create!(request_id: SecureRandom.uuid, gateway_key: key, model: payload["model"], endpoint: @endpoint)
      if payload["stream"]
        stream_response(routes, payload, log.id, log.request_id)
      else
        perform(routes, payload, log.id, log.request_id)
      end
    rescue JSON::ParserError
      error("Invalid JSON", 400)
    rescue Failure => exception
      error(exception.message, exception.status)
    end

    private

    def config
      RailsAiGateway.configuration
    end

    def parse_request(request)
      raise Failure.new("Content-Type must be application/json", 415) unless request.media_type == "application/json"
      raise Failure.new("Request body too large", 413) if request.content_length.to_i > config.max_request_bytes
      raw = request.body.read(config.max_request_bytes + 1)
      raise Failure.new("Request body too large", 413) if raw.bytesize > config.max_request_bytes
      payload = JSON.parse(raw)
      unless payload.is_a?(Hash) && payload["model"].is_a?(String) && payload["model"].present? && payload["model"].length <= 255
        raise Failure.new("A model name is required", 400)
      end
      if payload.key?("stream") && ![true, false].include?(payload["stream"])
        raise Failure.new("stream must be boolean", 400)
      end
      if @endpoint == "chat/completions"
        messages = payload["messages"]
        unless messages.is_a?(Array) && messages.any? && messages.all? { |message| message.is_a?(Hash) && %w[developer system user assistant tool function].include?(message["role"]) }
          raise Failure.new("messages must be a nonempty array with valid roles", 400)
        end
      else
        input = payload["input"]
        valid = input.is_a?(String) && !input.empty? || input.is_a?(Array) && !input.empty? && (
          input.all? { |item| item.is_a?(String) && !item.empty? } ||
          input.all? { |item| item.is_a?(Integer) && item >= 0 } ||
          input.all? { |item| item.is_a?(Array) && item.any? && item.all? { |id| id.is_a?(Integer) && id >= 0 } })
        raise Failure.new("input must contain text or token IDs; embeddings cannot stream", 400) unless valid && !payload["stream"]
      end
      payload
    end

    def stream_response(routes, payload, log_id, request_id)
      ready, chunks = Queue.new, SizedQueue.new(4)
      thread = Thread.new do
        Thread.current.report_on_exception = false
        Rails.application.executor.wrap do
          sent_headers = false
          begin
            result = perform(routes, payload, log_id, request_id) do |headers, response|
              sent_headers = true
              ready << [response.code.to_i, headers]
              response.read_body { |chunk| chunks << chunk }
            end
            if sent_headers && result.first >= 400
              chunks << "data: #{JSON.generate(error_payload("Upstream stream failed", result.first))}\n\ndata: [DONE]\n\n"
            end
            ready << result unless sent_headers
          rescue StandardError
            ready << error("Gateway failed", 500) unless sent_headers
          ensure
            chunks.close
          end
        end
      end
      result = ready.pop
      if result.length == 2
        [*result, Stream.new(chunks, thread)]
      else
        thread.join
        result
      end
    rescue Exception
      thread&.kill
      thread&.join
      raise
    end

    def perform(routes, payload, log_id, request_id)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      attempts, usage, status, streaming = [], nil, 502, false
      Timeout.timeout(config.request_timeout, Failure, "Upstream deadline exceeded") do
        routes.each_with_index do |route, index|
          attempt = { provider_id: route.provider_id, upstream_model: route.upstream_model }
          attempts << attempt
          begin
            uri, address = destination(route.provider)
            http = Net::HTTP.new(uri.hostname, uri.port, nil) # Do not inherit HTTP_PROXY or leak credentials to it.
            http.ipaddr = address # Pin validated DNS result, preserving hostname for TLS verification.
            http.use_ssl = uri.scheme == "https"
            http.open_timeout, http.read_timeout, http.write_timeout = config.open_timeout, config.read_timeout, config.write_timeout
            http.max_retries = 0
            request = Net::HTTP::Post.new(uri.request_uri)
            request["Content-Type"] = "application/json"
            request["Accept"] = payload["stream"] ? "text/event-stream" : "application/json"
            request["Accept-Encoding"] = "identity"
            request["Authorization"] = "Bearer #{route.provider.api_key}" if route.provider.api_key.present?
            request.body = JSON.generate(payload.merge("model" => route.upstream_model))
            result = nil
            http.start do
              http.request(request) do |response|
                status = attempt[:status] = response.code.to_i
                raise Failure, "Upstream redirects are not supported" if (300..399).cover?(status)
                headers = { "content-type" => "application/json", "cache-control" => "no-store", "x-request-id" => request_id }
                retry_after = response["retry-after"].to_s
                headers["retry-after"] = retry_after if retry_after.match?(/\A\d{1,10}\z/)
                if payload["stream"] && (200..299).cover?(status)
                  raise Failure, "Upstream did not return an event stream" unless response["content-type"].to_s.split(";").first == "text/event-stream"
                  headers.merge!("content-type" => "text/event-stream", "x-accel-buffering" => "no")
                  streaming = true
                  yield headers, response
                  result = [status, headers, []]
                else
                  body = +""
                  response.read_body do |chunk|
                    raise Failure, "Upstream response too large" if body.bytesize + chunk.bytesize > config.max_response_bytes
                    body << chunk
                  end
                  unless RETRY_STATUSES.include?(status) && index < routes.length - 1
                    begin
                      parsed = JSON.parse(body)
                    rescue JSON::ParserError
                      raise Failure, "Upstream did not return JSON"
                    end
                    raise Failure, "Upstream did not return a JSON object" unless parsed.is_a?(Hash)
                    usage = parsed["usage"].slice("prompt_tokens", "completion_tokens", "total_tokens").select { |_, value| value.is_a?(Integer) && value >= 0 } if parsed["usage"].is_a?(Hash)
                    if (200..299).cover?(status)
                      raise Failure, "Upstream embeddings response is malformed" if @endpoint == "embeddings" && !parsed["data"].is_a?(Array)
                      result = [status, headers, [body]]
                    else
                      message = parsed.dig("error", "message") || parsed["message"] || parsed["error"]
                      message = "Upstream request failed" unless message.is_a?(String) && message.present?
                      result = [status, headers, [JSON.generate(error_payload(message, status))]]
                    end
                  end
                end
              end
            end
            return result if result
          rescue Net::OpenTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => exception
            attempt[:error] = exception.class.name
            raise Failure, "Upstream connection failed" if streaming || index == routes.length - 1
          end
        end
      end
    rescue Failure, Timeout::Error, IOError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => exception
      status = exception.is_a?(Timeout::Error) || exception.message == "Upstream deadline exceeded" ? 504 : 502
      attempts.last[:error] = exception.class.name if attempts.last
      # Never replay an ambiguous failure or append a second provider to a partial stream.
      error(exception.is_a?(Failure) ? exception.message : "Upstream request failed", status, request_id)
    ensure
      duration = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
      begin
        RequestLog.connection_pool.with_connection do
          RequestLog.find(log_id).update!(status: status, duration_ms: duration, attempts: attempts, usage: usage)
        end
      rescue StandardError => exception
        Rails.logger.error("RailsAiGateway request log write failed: #{exception.class}")
      end
    end

    def destination(provider)
      raise Failure, "Invalid provider URL" unless provider.valid?
      uri = URI.parse("#{provider.base_url.delete_suffix('/')}/#{@endpoint}")
      addresses = Addrinfo.getaddrinfo(uri.hostname, uri.port, nil, :STREAM).map(&:ip_address).uniq
      raise Failure, "Provider address unavailable" if addresses.empty?
      unless config.allow_private_networks
        addresses.each do |address|
          ip = IPAddr.new(address)
          ip = ip.native if ip.ipv4_mapped?
          raise Failure, "Private provider networks are disabled" if PRIVATE_RANGES.any? { |range| range.include?(ip) } || ip.ipv6? && !IPAddr.new("2000::/3").include?(ip)
        end
      end
      [uri, addresses.first]
    end

    def error(message, status, request_id = nil)
      response = json(status, error_payload(message, status))
      response[1]["www-authenticate"] = "Bearer" if status == 401
      response[1]["x-request-id"] = request_id if request_id
      response
    end

    def json(status, payload)
      [status, { "content-type" => "application/json", "cache-control" => "no-store" }, [JSON.generate(payload)]]
    end

    def error_payload(message, status)
      type, code = ERROR_TYPES.fetch(status, ["server_error", status == 504 ? "gateway_timeout" : "bad_gateway"])
      { error: { message: message, type: type, code: code } }
    end
  end
end
