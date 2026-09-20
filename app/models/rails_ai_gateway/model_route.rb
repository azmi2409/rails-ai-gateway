module RailsAiGateway
  class ModelRoute < ApplicationRecord
    belongs_to :provider
    validates :name, :upstream_model, presence: true, length: { maximum: 255 }
    validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :name }
    scope :available, -> { joins(:provider).where(rails_ai_gateway_providers: { enabled: true }) }
  end
end
