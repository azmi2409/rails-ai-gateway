require "rails_ai_gateway/version"
require "rails_ai_gateway/configuration"
require "active_support/inflector"

ActiveSupport::Inflector.inflections(:en) { |inflect| inflect.acronym "AI" }

module RailsAiGateway
  # Default OpenAI-compatible API path created by the install generator.
  #
  # Host applications using a custom engine mount path should derive their URL
  # from that route instead.
  ENDPOINT = "/ai/v1"

  # Returns global gateway configuration.
  #
  # @return [Configuration]
  def self.configuration
    @configuration ||= Configuration.new
  end

  # Configures gateway runtime and security policy.
  #
  # @yieldparam config [Configuration]
  # @return [Configuration]
  def self.configure
    yield configuration
    configuration.validate!
  end

  # Lists active public models and their routes.
  #
  # @param capabilities [Array<String>, String, nil] capabilities every result must support
  # @param provider [Provider, String, nil] provider record or provider name
  # @return [Array<Hash>] model metadata without provider credentials
  # @example Find vision models
  #   RailsAIGateway.models(capabilities: %w[vision text])
  def self.models(**filters)
    ModelHelper.models(**filters)
  end

  # Finds one active public model by ID.
  #
  # @param name [String]
  # @return [Hash, nil]
  def self.model(name)
    ModelHelper.model(name)
  end

  # Selects route proxy would use for query and required capabilities.
  #
  # Literal query-keyword matches rank before generic fallback routes.
  #
  # @param model [String] public model ID
  # @param query [String] text used for keyword routing
  # @param capabilities [Array<String>, String] required route capabilities
  # @return [Hash, nil] safe route metadata without system prompt or API key
  # @example Select coding route
  #   RailsAIGateway.route_for(
  #     model: "fast-chat",
  #     query: "Review this Ruby code",
  #     capabilities: %w[text tools]
  #   )
  def self.route_for(model:, query:, capabilities: [])
    ModelHelper.route_for(model: model, query: query, capabilities: capabilities)
  end
end

RailsAIGateway = RailsAiGateway unless defined?(RailsAIGateway)

require "rails_ai_gateway/engine"
require "rails_ai_gateway/model_helper"
