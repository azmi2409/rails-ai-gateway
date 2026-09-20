module RailsAiGateway
  class RequestLog < ApplicationRecord
    belongs_to :gateway_key, optional: true
  end
end
