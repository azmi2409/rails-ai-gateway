class AddCacheToRailsAIGateway < ActiveRecord::Migration[8.0]
  def change
    add_column :rails_ai_gateway_request_logs, :cached, :boolean, default: false, null: false
    add_column :rails_ai_gateway_request_logs, :response_cache_key, :string
  end
end
