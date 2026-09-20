module RailsAiGateway
  class ModelRoute < ApplicationRecord
    CAPABILITIES = %w[text vision embedding audio video tools reasoning].freeze

    belongs_to :provider
    before_validation :normalize_metadata
    validates :name, :upstream_model, presence: true, length: { maximum: 255 }
    validates :system_prompt, length: { maximum: 20_000 }, allow_blank: true
    validate :valid_capabilities
    validate :valid_query_keywords
    validates :priority, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, uniqueness: { scope: :name }
    scope :available, -> { joins(:provider).where(rails_ai_gateway_providers: { enabled: true }) }

    def self.ranked_for_query(name:, query:)
      routes = available.where(name: name).includes(:provider).order(:priority).to_a
      normalized_query = query.to_s.downcase
      matched, generic = routes.partition { |route| route.query_keywords.any? { |keyword| normalized_query.include?(keyword) } }
      matched + generic.select { |route| route.query_keywords.empty? }
    end

    private

    def normalize_metadata
      self.capabilities = Array(capabilities).map(&:to_s).reject(&:blank?).uniq
      self.query_keywords = Array(query_keywords).map { |keyword| keyword.to_s.strip.downcase }.reject(&:blank?).uniq
    end

    def valid_capabilities
      unless capabilities.is_a?(Array) && capabilities.any? && capabilities.all? { |capability| CAPABILITIES.include?(capability) }
        errors.add(:capabilities, "must include at least one supported capability")
      end
    end

    def valid_query_keywords
      unless query_keywords.is_a?(Array) && query_keywords.length <= 50 && query_keywords.all? { |keyword| keyword.is_a?(String) && keyword.present? && keyword.length <= 100 }
        errors.add(:query_keywords, "must contain up to 50 nonempty keywords of 100 characters or fewer")
      end
    end
  end
end
