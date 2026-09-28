class AddCacheToRailsAiGateway < ActiveRecord::Migration[8.0]
  def change
    add_column :rails_ai_gateway_request_logs, :cached, :boolean, default: false, null: false
    add_column :rails_ai_gateway_request_logs, :cache_key, :string
  end
end
