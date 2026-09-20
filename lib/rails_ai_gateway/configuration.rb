module RailsAiGateway
  class Configuration
    attr_accessor :admin_authorization, :admin_controller, :open_timeout, :read_timeout,
      :write_timeout, :request_timeout, :max_request_bytes, :max_response_bytes,
      :max_attempts, :allow_private_networks, :allow_http

    def initialize
      @admin_controller = "ActionController::Base"
      @admin_authorization = ->(_controller) { false }
      @open_timeout = 5
      @read_timeout = 60
      @write_timeout = 30
      @request_timeout = 120
      @max_request_bytes = 2 * 1024 * 1024
      @max_response_bytes = 16 * 1024 * 1024
      @max_attempts = 3
      @allow_private_networks = false
      @allow_http = false
    end

    def validate!
      %i[open_timeout read_timeout write_timeout request_timeout].each do |name|
        value = public_send(name)
        raise ArgumentError, "#{name} must be positive and finite" unless value.is_a?(Numeric) && value.finite? && value.positive?
      end
      %i[max_request_bytes max_response_bytes max_attempts].each do |name|
        value = public_send(name)
        raise ArgumentError, "#{name} must be a positive integer" unless value.is_a?(Integer) && value.positive?
      end
      %i[allow_private_networks allow_http].each do |name|
        raise ArgumentError, "#{name} must be boolean" unless [true, false].include?(public_send(name))
      end
      raise ArgumentError, "admin_authorization must be callable" unless admin_authorization.respond_to?(:call)
      raise ArgumentError, "admin_controller must be a class name" unless admin_controller.is_a?(String) && !admin_controller.empty?
    end
  end
end
