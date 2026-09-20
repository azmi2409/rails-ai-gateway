require "rails_ai_gateway/version"
require "rails_ai_gateway/configuration"
require "active_support/inflector"

ActiveSupport::Inflector.inflections(:en) { |inflect| inflect.acronym "AI" }

module RailsAiGateway
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
    configuration.validate!
  end

  def self.models(**filters)
    ModelHelper.models(**filters)
  end

  def self.model(name)
    ModelHelper.model(name)
  end

  def self.route_for(model:, query:)
    ModelHelper.route_for(model: model, query: query)
  end
end

RailsAIGateway = RailsAiGateway unless defined?(RailsAIGateway)
RailsAIGateway::ENDPOINT = "/ai/v1" unless RailsAIGateway.const_defined?(:ENDPOINT, false)

require "rails_ai_gateway/engine"
require "rails_ai_gateway/model_helper"
