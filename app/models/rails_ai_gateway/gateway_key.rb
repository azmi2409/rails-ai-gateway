require "digest"
require "securerandom"

module RailsAiGateway
  class GatewayKey < ApplicationRecord
    validates :name, presence: true, length: { maximum: 255 }
    validates :token_digest, :prefix, presence: true
    validates :token_digest, uniqueness: true
    validate :valid_allowed_models

    def self.issue!(**attributes)
      token = "rag_#{SecureRandom.hex(32)}"
      key = create!(**attributes, token_digest: Digest::SHA256.hexdigest(token), prefix: token.first(12))
      [key, token]
    end

    def self.authenticate(token)
      return unless token.is_a?(String) && token.match?(/\Arag_[0-9a-f]{64}\z/)
      key = find_by(token_digest: Digest::SHA256.hexdigest(token), revoked_at: nil)
      key if key && (!key.expires_at || key.expires_at.future?)
    end

    def allows?(model)
      allowed_models.empty? || allowed_models.include?(model)
    end

    private

    def valid_allowed_models
      unless allowed_models.is_a?(Array) && allowed_models.all? { |name| name.is_a?(String) && name.present? && name.length <= 255 }
        errors.add(:allowed_models, "must be an array of model names")
      end
    end
  end
end
