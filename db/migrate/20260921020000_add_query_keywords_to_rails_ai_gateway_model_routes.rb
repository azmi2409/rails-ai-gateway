class AddQueryKeywordsToRailsAIGatewayModelRoutes < ActiveRecord::Migration[8.0]
  def change
    add_column :rails_ai_gateway_model_routes, :query_keywords, :json, null: false, default: []
  end
end
