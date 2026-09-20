require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "rails_ai_gateway/proxy"

module RailsAiGateway
  class Engine < ::Rails::Engine
    isolate_namespace RailsAiGateway

    initializer "rails_ai_gateway.filter_parameters" do |app|
      app.config.filter_parameters += %i[api_key token token_digest authorization]
    end

    config.after_initialize { RailsAiGateway.configuration.validate! }
  end
end
