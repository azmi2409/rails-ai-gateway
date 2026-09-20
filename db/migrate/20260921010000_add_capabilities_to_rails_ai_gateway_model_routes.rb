class AddCapabilitiesToRailsAIGatewayModelRoutes < ActiveRecord::Migration[8.0]
  def change
    add_column :rails_ai_gateway_model_routes, :capabilities, :json, null: false, default: ["text"]
  end
end
