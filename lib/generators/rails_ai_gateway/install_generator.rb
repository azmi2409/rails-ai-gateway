require "rails/generators"

module RailsAiGateway
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("templates", __dir__)
    desc "Install Rails AI Gateway configuration, migrations, and mount route"

    def install
      template "initializer.rb", "config/initializers/rails_ai_gateway.rb"
      rake "railties:install:migrations"
      route 'mount RailsAIGateway::Engine, at: "/ai"'
      say "Configure admin_authorization and ActiveRecord encryption, then run bin/rails db:migrate."
    end
  end
end
