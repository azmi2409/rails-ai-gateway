# Run: bundle exec ruby test/check.rb
require "bundler/setup"
require "tmpdir"
require "fileutils"
require "socket"
require "timeout"
require "rack/mock"
require "cgi"

ROOT = File.expand_path("..", __dir__)
TEMP = Dir.mktmpdir("rails-ai-gateway-check")
at_exit { FileUtils.remove_entry(TEMP) }
ENV["RAILS_ENV"] = "test"
ENV["DATABASE_URL"] ||= "sqlite3:#{TEMP}/gateway.sqlite3"
$LOAD_PATH.unshift("#{ROOT}/lib")
require "rails_ai_gateway"

class CheckHost < Rails::Application
  config.root = TEMP
  config.eager_load = false
  config.secret_key_base = "test-only-secret-" * 8
  config.hosts.clear
  config.logger = Logger.new(File::NULL)
  config.active_record.encryption.primary_key = "test-primary-key-" * 4
  config.active_record.encryption.deterministic_key = "test-deterministic-" * 4
  config.active_record.encryption.key_derivation_salt = "test-salt-" * 4
  config.action_dispatch.show_exceptions = :none
end
Rails.application.initialize!
Rails.application.routes.draw { mount RailsAiGateway::Engine, at: "/nested/ai" }
require "#{ROOT}/db/migrate/20260920000000_create_rails_ai_gateway"
ActiveRecord::Migration.verbose = false
CreateRailsAiGateway.new.migrate(:up)
at_exit { CreateRailsAiGateway.new.migrate(:down) }

def assert(condition, message)
  raise message unless condition
end

def rejects(message, error = ArgumentError)
  begin
    yield
  rescue error
    return
  end
  raise message
end

# Scripted local upstream uses real HTTP sockets, no provider accounts or network calls.
class Upstream
  attr_reader :url, :received, :plans

  def initialize
    @server = TCPServer.new("127.0.0.1", 0)
    @url = "http://127.0.0.1:#{@server.addr[1]}/v1"
    @received, @plans = Queue.new, Queue.new
    @thread = Thread.new do
      loop do
        socket = @server.accept
        begin
          headers = +""
          headers << socket.read(1) until headers.end_with?("\r\n\r\n")
          size = headers[/Content-Length: (\d+)/i, 1].to_i
          @received << [headers, JSON.parse(socket.read(size))]
          @plans.pop.call(socket)
        rescue Errno::EPIPE, Errno::ECONNRESET
          nil
        ensure
          socket.close
        end
      end
    rescue IOError, Errno::EBADF
      nil
    end
  end

  def respond(status = 200, body = { choices: [], usage: { total_tokens: 7 } }, headers = {})
    plans << ->(socket) do
      body = body.is_a?(String) ? body : JSON.generate(body)
      extra = headers.map { |key, value| "#{key}: #{value}\r\n" }.join
      socket.write("HTTP/1.1 #{status} Result\r\nContent-Type: application/json\r\nContent-Length: #{body.bytesize}\r\nConnection: close\r\n#{extra}\r\n#{body}")
    end
  end

  def close
    @thread.kill
    @thread.join
    @server.close
  end
end

upstream = Upstream.new
at_exit { upstream.close }
RailsAiGateway.configure do |config|
  config.allow_http = true
  config.allow_private_networks = true
end
config = RailsAiGateway.configuration
assert(!config.admin_authorization.call(nil), "admin must default to denied")
rejects("zero timeout accepted") { RailsAiGateway::Configuration.new.tap { |c| c.open_timeout = 0 }.validate! }
rejects("fractional attempts accepted") { RailsAiGateway::Configuration.new.tap { |c| c.max_attempts = 1.5 }.validate! }
rejects("truthy string accepted") { RailsAiGateway::Configuration.new.tap { |c| c.allow_http = "false" }.validate! }

provider = RailsAiGateway::Provider.create!(name: "Local", base_url: upstream.url, api_key: "fake-upstream-key")
assert(!provider.api_key_before_type_cast.include?("fake-upstream-key"), "provider credential stored unencrypted")
assert(!RailsAiGateway::Provider.new(name: "bad", base_url: "http://user:pass@example.com/v1").valid?, "URL credentials accepted")
canonical = RailsAiGateway::Provider.new(name: "canonical", base_url: "  #{upstream.url}/chat/completions/  ")
canonical.valid?
assert(canonical.base_url == upstream.url, "provider endpoint path not normalized")
route = RailsAiGateway::ModelRoute.create!(provider: provider, name: "chat", upstream_model: "upstream-chat")
RailsAiGateway::ModelRoute.create!(provider: provider, name: "embedding", upstream_model: "upstream-embedding")
key, token = RailsAiGateway::GatewayKey.issue!(name: "test", allowed_models: ["chat"])
assert(!key.attributes.values.include?(token), "raw client token persisted")
assert(RailsAiGateway::GatewayKey.authenticate(token) == key, "issued key rejected")
key.update!(expires_at: 1.second.ago)
assert(!RailsAiGateway::GatewayKey.authenticate(token), "expired key accepted")
key.update!(expires_at: nil)
client = Rack::MockRequest.new(Rails.application)
base = "/nested/ai"
auth = { "HTTP_AUTHORIZATION" => "Bearer #{token}" }
payload = { model: "chat", messages: [{ role: "user", content: "private prompt" }] }
post = ->(body = payload, extra = {}) { client.post("#{base}/v1/chat/completions", auth.merge("CONTENT_TYPE" => "application/json", input: JSON.generate(body)).merge(extra)) }

assert(client.get("#{base}/v1/models").status == 401, "unauthenticated API allowed")
models = JSON.parse(client.get("#{base}/v1/models", auth).body)
assert(models["data"].map { |item| item["id"] } == ["chat"], "models escaped key scope")
assert(post.call(payload.merge(model: "embedding")).status == 403, "forbidden model accepted")
assert(post.call(payload.merge(messages: [])).status == 400, "invalid messages accepted")
assert(post.call(payload.merge(stream: "true")).status == 400, "invalid stream accepted")
assert(post.call(payload, input: "{").status == 400, "invalid JSON accepted")
assert(post.call(payload, "CONTENT_TYPE" => "text/plain").status == 415, "invalid content type accepted")
config.max_request_bytes = 10
assert(post.call.status == 413, "oversized input accepted")
config.max_request_bytes = 2 * 1024 * 1024

upstream.respond
response = post.call(payload.merge(temperature: 0.3, tools: [{ type: "function" }]))
assert(response.status == 200, "proxy failed: #{response.status} #{response.body}")
headers, forwarded = upstream.received.pop
assert(headers.include?("POST /v1/chat/completions") && headers.include?("Bearer fake-upstream-key"), "upstream path/auth incorrect")
assert(!headers.include?(token), "client credential forwarded")
assert(forwarded["model"] == "upstream-chat" && forwarded["temperature"] == 0.3 && forwarded["tools"], "payload not forwarded")
log = RailsAiGateway::RequestLog.last
assert(log.status == 200 && log.usage["total_tokens"] == 7 && log.attempts.size == 1, "usage/logging failed")
assert(!log.attributes.to_json.include?("private prompt"), "prompt persisted")

config.allow_private_networks = false
assert(post.call.status == 502, "private destination permitted")
config.allow_private_networks = true
config.allow_http = false
assert(post.call.status == 502, "HTTP destination permitted")
config.allow_http = true

fallback = RailsAiGateway::ModelRoute.create!(provider: provider, name: "chat", upstream_model: "fallback-chat", priority: 1)
upstream.respond(429, { error: { message: "busy" } })
upstream.respond
assert(post.call.status == 200, "429 failover failed")
upstream.received.pop
assert(upstream.received.pop.last["model"] == "fallback-chat", "fallback model not selected")
assert(RailsAiGateway::RequestLog.last.attempts.map { |a| a["status"] } == [429, 200], "attempt log incomplete")
config.max_attempts = 1
upstream.respond(503, { error: { message: "unavailable" } })
assert(post.call.status == 503, "attempt cap ignored")
upstream.received.pop
config.max_attempts = 3
upstream.respond(400, { error: { message: "bad request", type: "provider_specific" } })
bad_request = post.call
bad_request_body = JSON.parse(bad_request.body)
assert(bad_request.status == 400, "upstream error status not preserved")
assert(bad_request_body == { "error" => { "message" => "bad request", "type" => "invalid_request_error", "code" => "invalid_request" } }, "upstream error not normalized")
upstream.received.pop
upstream.respond(429, { message: "slow down" }, { "Retry-After" => "17" })
fallback.destroy!
limited = post.call
assert(limited.status == 429 && limited["retry-after"] == "17", "retry-after not preserved")
assert(JSON.parse(limited.body).dig("error", "type") == "rate_limit_error", "rate limit error not normalized")
upstream.received.pop
upstream.respond(302, "", { "Location" => "http://example.com/" })
assert(post.call.status == 502, "redirect followed")
upstream.received.pop
upstream.respond(200, "not JSON")
assert(post.call.status == 502, "invalid upstream JSON accepted")
upstream.received.pop
config.max_response_bytes = 8
upstream.respond
assert(post.call.status == 502, "response bound ignored")
upstream.received.pop
config.max_response_bytes = 16 * 1024 * 1024

# An upstream that already accepted the POST must not be retried after a read timeout.
config.read_timeout = 0.05
upstream.plans << ->(socket) { sleep 0.15; socket.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\n{}") }
assert(post.call.status == 504, "read timeout not mapped")
assert(RailsAiGateway::RequestLog.last.attempts.size == 1, "ambiguous failure retried")
upstream.received.pop
config.read_timeout = 60
sleep 0.2

# Require the first event before upstream releases the second: proves incremental delivery.
release = Queue.new
upstream.plans << ->(socket) do
  socket.write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n")
  first = "data: {\"choices\":[]}\n\n"
  socket.write("#{first.bytesize.to_s(16)}\r\n#{first}\r\n")
  release.pop
  last = "data: [DONE]\n\n"
  socket.write("#{last.bytesize.to_s(16)}\r\n#{last}\r\n0\r\n\r\n")
end
env = Rack::MockRequest.env_for("#{base}/v1/chat/completions", method: "POST", input: JSON.generate(payload.merge(stream: true)), "CONTENT_TYPE" => "application/json", **auth)
status, headers, body = Rails.application.call(env)
assert(status == 200 && headers["content-type"].include?("text/event-stream"), "SSE headers incorrect")
events = []
Timeout.timeout(3) do
  body.each do |chunk|
    events << chunk
    release << true if events.length == 1
  end
end
body.close if body.respond_to?(:close)
assert(events.join.include?("[DONE]"), "stream incomplete")
upstream.received.pop

upstream.plans << ->(socket) do
  socket.write("HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nTransfer-Encoding: chunked\r\n\r\n")
  first = "data: {\"choices\":[]}\n\n"
  socket.write("#{first.bytesize.to_s(16)}\r\n#{first}\r\n")
end
status, _, body = Rails.application.call(Rack::MockRequest.env_for("#{base}/v1/chat/completions", method: "POST", input: JSON.generate(payload.merge(stream: true)), "CONTENT_TYPE" => "application/json", **auth))
broken_chunks = []
body.each { |chunk| broken_chunks << chunk }
broken_events = broken_chunks.join
body.close if body.respond_to?(:close)
assert(status == 200 && broken_events.include?("Upstream stream failed") && broken_events.end_with?("data: [DONE]\n\n"), "broken stream lacks terminal error")
upstream.received.pop

key.update!(allowed_models: [])
upstream.respond(200, { data: [{ embedding: [0.1] }] })
embedding = client.post("#{base}/v1/embeddings", **auth, "CONTENT_TYPE" => "application/json", input: JSON.generate(model: "embedding", input: "hello"))
assert(embedding.status == 200, "embeddings failed")
assert(upstream.received.pop.first.include?("POST /v1/embeddings"), "embedding path incorrect")
upstream.respond(200, { object: "list" })
malformed_embedding = client.post("#{base}/v1/embeddings", **auth, "CONTENT_TYPE" => "application/json", input: JSON.generate(model: "embedding", input: "hello"))
assert(malformed_embedding.status == 502, "malformed embedding response accepted")
upstream.received.pop

assert(client.get("#{base}/admin").status == 403, "admin default not closed")
config.admin_authorization = ->(_controller) { true }
response = client.get("#{base}/admin")
assert(response.status == 200 && response.body.include?("Gateway overview"), "admin render failed")
assert(response.body.include?("/nested/ai/admin/providers"), "mounted form URL incorrect")
assert(!response.body.include?("fake-upstream-key") && !response.body.include?(token), "admin disclosed credentials")
assert(client.get("#{base}/admin/style").body.include?(":root"), "stylesheet missing")
rejects("admin accepted request without CSRF", ActionController::InvalidAuthenticityToken) do
  client.post("#{base}/admin/providers", input: "provider[name]=bad")
end
csrf = CGI.unescapeHTML(response.body[/name="csrf-token" content="([^"]+)"/, 1])
cookie = Array(response["set-cookie"]).map { |value| value.split(";", 2).first }.join("; ")
admin_headers = { "HTTP_COOKIE" => cookie, "HTTP_X_CSRF_TOKEN" => csrf, "CONTENT_TYPE" => "application/x-www-form-urlencoded" }
created = client.post("#{base}/admin/providers", **admin_headers, input: URI.encode_www_form("provider[name]" => "Another", "provider[base_url]" => upstream.url))
assert(created.status == 303, "provider UI create failed: #{created.status}")
created = client.post("#{base}/admin/gateway_keys", **admin_headers, input: URI.encode_www_form("gateway_key[name]" => "UI key", "gateway_key[allowed_models]" => "chat, embedding"))
assert(created.status == 201 && created.body.match?(/rag_[0-9a-f]{64}/), "key UI create failed")
assert(created["cache-control"] == "no-store", "one-time key page cacheable")
key.update!(revoked_at: Time.current)
assert(client.get("#{base}/v1/models", auth).status == 401, "revoked key accepted")

Rails.application.eager_load!
puts "PASS: configuration, migrations, encryption, auth, routing, HTTP proxy, failover, limits, streaming, embeddings, admin, CSRF, eager loading"
