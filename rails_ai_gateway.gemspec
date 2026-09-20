require_relative "lib/rails_ai_gateway/version"

Gem::Specification.new do |spec|
  spec.name = "rails-ai-gateway"
  spec.version = RailsAiGateway::VERSION
  spec.authors = ["Rails AI Gateway contributors"]
  spec.summary = "Mountable Rails AI gateway with ActiveRecord and an admin UI"
  spec.description = "OpenAI-compatible AI gateway mounted inside Rails, with ActiveRecord routing, encrypted provider keys, request logs, fallbacks, streaming, and an admin UI."
  spec.homepage = "https://github.com/azmi2409/rails-ai-gateway"
  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/rails-ai-gateway/#{spec.version}",
    "rubygems_mfa_required" => "true"
  }
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3"
  spec.files = Dir["{app,config,db,lib}/**/*", "README.md", "CHANGELOG.md", "CONTRIBUTING.md", "LICENSE", ".yardopts"].select { |path| File.file?(path) }
  spec.add_dependency "railties", ">= 8.0", "< 9"
  spec.add_dependency "activerecord", ">= 8.0", "< 9"
  spec.add_dependency "actionpack", ">= 8.0", "< 9"
  spec.add_dependency "net-http", ">= 0.4", "< 1"
  spec.add_dependency "json", ">= 2.7", "< 3" # Rails 8 passes a positional options hash to JSON.parse.
end
