require "rails_ai_gateway/version"
require "rails_ai_gateway/configuration"

module RailsAiGateway
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield configuration
    configuration.validate!
  end
end

require "rails_ai_gateway/engine"
