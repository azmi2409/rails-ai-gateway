RailsAiGateway.configure do |config|
  # Deny by default. With Devise, for example:
  # config.admin_controller = "ApplicationController"
  # config.admin_authorization = ->(controller) { controller.current_user&.admin? == true }

  config.open_timeout = 5
  config.read_timeout = 60
  config.write_timeout = 30
  config.request_timeout = 120 # Total deadline across fallback attempts, including streams.
  config.max_request_bytes = 2 * 1024 * 1024
  config.max_response_bytes = 16 * 1024 * 1024 # Buffered, non-streaming responses.
  config.max_attempts = 3

  # Enable only for trusted internal providers, such as a local Ollama server.
  config.allow_private_networks = false
  config.allow_http = false
end
