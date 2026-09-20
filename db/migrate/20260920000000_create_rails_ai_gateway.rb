class CreateRailsAiGateway < ActiveRecord::Migration[8.0]
  def change
    create_table :rails_ai_gateway_providers do |t|
      t.string :name, null: false
      t.string :base_url, null: false
      t.text :api_key
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end
    add_index :rails_ai_gateway_providers, :name, unique: true

    create_table :rails_ai_gateway_model_routes do |t|
      t.references :provider, null: false, foreign_key: { to_table: :rails_ai_gateway_providers }
      t.string :name, null: false
      t.string :upstream_model, null: false
      t.integer :priority, null: false, default: 0
      t.timestamps
    end
    add_index :rails_ai_gateway_model_routes, [:name, :priority], unique: true
    add_check_constraint :rails_ai_gateway_model_routes, "priority >= 0", name: "gateway_route_priority"

    create_table :rails_ai_gateway_gateway_keys do |t|
      t.string :name, null: false
      t.string :token_digest, null: false
      t.string :prefix, null: false
      t.json :allowed_models, null: false, default: []
      t.datetime :expires_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :rails_ai_gateway_gateway_keys, :token_digest, unique: true

    create_table :rails_ai_gateway_request_logs do |t|
      t.string :request_id, null: false
      t.references :gateway_key, foreign_key: { to_table: :rails_ai_gateway_gateway_keys }
      t.string :model, null: false
      t.string :endpoint, null: false
      t.integer :status
      t.integer :duration_ms
      t.json :attempts, null: false, default: []
      t.json :usage
      t.timestamps
    end
    add_index :rails_ai_gateway_request_logs, :request_id, unique: true
    add_index :rails_ai_gateway_request_logs, :created_at
    add_index :rails_ai_gateway_request_logs, [:model, :created_at]
  end
end
