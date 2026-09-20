module RailsAiGateway
  # Runtime and security settings configured in host Rails initializer.
  class Configuration
    # @return [#call] callback receiving admin controller; must return exactly true
    attr_accessor :admin_authorization
    # @return [String] host controller class inherited by mounted admin controller
    attr_accessor :admin_controller
    # @return [Numeric] upstream connection timeout in seconds
    attr_accessor :open_timeout
    # @return [Numeric] upstream socket read timeout in seconds
    attr_accessor :read_timeout
    # @return [Numeric] upstream socket write timeout in seconds
    attr_accessor :write_timeout
    # @return [Numeric] total deadline across fallback attempts in seconds
    attr_accessor :request_timeout
    # @return [Integer] maximum accepted JSON request size in bytes
    attr_accessor :max_request_bytes
    # @return [Integer] maximum buffered non-streaming response size in bytes
    attr_accessor :max_response_bytes
    # @return [Integer] maximum provider routes attempted per request
    attr_accessor :max_attempts
    # @return [Boolean] whether upstream DNS may resolve to private/reserved networks
    attr_accessor :allow_private_networks
    # @return [Boolean] whether upstream providers may use unencrypted HTTP
    attr_accessor :allow_http

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

    # Validates all settings.
    # @raise [ArgumentError] when a setting is invalid
    # @return [nil]
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
