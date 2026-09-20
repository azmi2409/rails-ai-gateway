require "uri"

module RailsAiGateway
  class Provider < ApplicationRecord
    TEMPLATES = {
      "openai" => { name: "OpenAI", base_url: "https://api.openai.com/v1" },
      "openrouter" => { name: "OpenRouter", base_url: "https://openrouter.ai/api/v1" },
      "groq" => { name: "Groq", base_url: "https://api.groq.com/openai/v1" },
      "deepseek" => { name: "DeepSeek", base_url: "https://api.deepseek.com" },
      "mistral" => { name: "Mistral AI", base_url: "https://api.mistral.ai/v1" },
      "cerebras" => { name: "Cerebras", base_url: "https://api.cerebras.ai/v1" },
      "nebius" => { name: "Nebius AI", base_url: "https://api.studio.nebius.ai/v1" },
      "perplexity" => { name: "Perplexity", base_url: "https://api.perplexity.ai" }
    }.freeze

    encrypts :api_key
    has_many :model_routes, dependent: :restrict_with_error
    before_validation :normalize_base_url
    validates :name, presence: true, uniqueness: true, length: { maximum: 255 }
    validates :base_url, presence: true, length: { maximum: 2048 }
    validates :api_key, format: { without: /[\r\n]/ }, allow_nil: true
    validate :valid_base_url

    private

    def normalize_base_url
      self.base_url = base_url.to_s.strip.sub(%r{/+(?:chat/completions|responses|embeddings)?/*\z}, "")
    end

    def valid_base_url
      uri = URI.parse(base_url.to_s)
      schemes = RailsAiGateway.configuration.allow_http ? %w[https http] : %w[https]
      unless schemes.include?(uri.scheme) && uri.host.present? && !uri.userinfo && !uri.query && !uri.fragment
        errors.add(:base_url, "must be an HTTPS URL without credentials, query, or fragment")
      end
    rescue URI::InvalidURIError
      errors.add(:base_url, "is invalid")
    end
  end
end
