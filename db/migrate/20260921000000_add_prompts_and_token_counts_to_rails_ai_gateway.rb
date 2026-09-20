class AddPromptsAndTokenCountsToRailsAIGateway < ActiveRecord::Migration[8.0]
  def change
    add_column :rails_ai_gateway_model_routes, :system_prompt, :text
    add_column :rails_ai_gateway_request_logs, :input_tokens, :bigint, null: false, default: 0
    add_column :rails_ai_gateway_request_logs, :output_tokens, :bigint, null: false, default: 0
    add_check_constraint :rails_ai_gateway_request_logs, "input_tokens >= 0", name: "gateway_log_input_tokens"
    add_check_constraint :rails_ai_gateway_request_logs, "output_tokens >= 0", name: "gateway_log_output_tokens"
  end
end
