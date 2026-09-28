require "digest"
require "json"

module RailsAiGateway
  # Lightweight response cache backed by Rails.cache.
  #
  # Keys derive from the endpoint, public model name, and a normalized request
  # payload, so identical calls share one upstream round-trip. Streaming
  # requests and client-variable fields never touch the cache.
  # @api private
  module Cache
    # @return [String] Rails.cache namespace for gateway entries
    NAMESPACE = "rails_ai_gateway".freeze
    # @return [Array<String>] endpoints eligible for caching
    CACHEABLE_ENDPOINTS = %w[chat/completions embeddings].freeze
    # @return [Array<String>] payload fields excluded from the cache key
    EXCLUDED_FIELDS = %w[stream user].freeze

    # @param endpoint [String] proxy endpoint, e.g. "chat/completions"
    # @param payload [Hash] parsed request payload
    # @return [Boolean] whether the request is eligible for a cache lookup
    def self.enabled?(endpoint, payload)
      RailsAiGateway.configuration.cache_enabled &&
        !payload["stream"] &&
        CACHEABLE_ENDPOINTS.include?(endpoint)
    end

    # @param endpoint [String] proxy endpoint
    # @param payload [Hash] parsed request payload
    # @return [String] stable cache key for the request
    def self.key(endpoint, payload)
      normalized = payload.reject { |field, _| EXCLUDED_FIELDS.include?(field) }
      digest = Digest::SHA256.hexdigest(JSON.generate({ endpoint: endpoint, payload: normalized }))
      "#{NAMESPACE}:#{endpoint.tr("/", "-")}:#{digest}"
    end

    # @param cache_key [String] key from {.key}
    # @return [Hash, nil] cached entry with "body" and "usage", or nil on miss
    def self.read(cache_key)
      Rails.cache.read(cache_key)
    end

    # Stores a successful upstream response. Oversized bodies are skipped so the
    # cache never bypasses the configured response bound.
    #
    # @param cache_key [String] key from {.key}
    # @param body [String] raw upstream response body
    # @param usage [Hash, nil] normalized token usage
    # @return [Boolean] whether the entry was written
    def self.write(cache_key, body:, usage:)
      return false if body.bytesize > RailsAiGateway.configuration.max_response_bytes

      Rails.cache.write(
        cache_key,
        { "body" => body, "usage" => usage },
        expires_in: RailsAiGateway.configuration.cache_ttl
      )
      true
    end
  end
end
