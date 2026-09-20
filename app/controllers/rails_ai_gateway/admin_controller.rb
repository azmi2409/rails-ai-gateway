module RailsAiGateway
  class AdminController < RailsAiGateway.configuration.admin_controller.constantize
    layout "rails_ai_gateway/admin"
    protect_from_forgery with: :exception
    skip_forgery_protection only: :script
    before_action :authorize_admin
    rescue_from ActiveRecord::RecordInvalid, with: :invalid_record
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from ActiveRecord::RecordNotUnique, with: -> { render plain: "Name or priority already exists", status: 422 }

    def index
      require_current_schema!
      @providers = Provider.order(:name)
      @provider_templates = Provider::TEMPLATES
      @routes = ModelRoute.includes(:provider).order(:name, :priority)
      @keys = GatewayKey.order(created_at: :desc)
      recent = RequestLog.where(created_at: 24.hours.ago..)
      @requests = recent.count
      @errors = recent.where(status: 400..599).count
      @latency = recent.average(:duration_ms)&.round || 0
      @model_usage = RequestLog.group(:model).order(:model).pluck(
        :model,
        Arel.sql("COALESCE(SUM(input_tokens), 0)"),
        Arel.sql("COALESCE(SUM(output_tokens), 0)")
      )
      logs = RequestLog.order(id: :desc)
      logs = logs.where(model: params[:model]) if params[:model].is_a?(String) && params[:model].present?
      logs = logs.where(status: params[:status].to_i) if params[:status].to_s.match?(/\A[1-5][0-9]{2}\z/)
      logs = logs.where("id < ?", params[:before].to_i) if params[:before].to_s.match?(/\A[0-9]+\z/)
      @logs = logs.limit(50)
    end

    def create_provider
      if params[:template].present?
        template = Provider::TEMPLATES.fetch(params[:template]) { raise ActiveRecord::RecordNotFound }
        provider = Provider.new(name: template[:name], base_url: template[:base_url], api_key: params[:api_key])
        provider.errors.add(:api_key, "is required for provider templates") if params[:api_key].blank?
        raise ActiveRecord::RecordInvalid, provider if provider.errors.any?
        provider.save!
      else
        Provider.create!(provider_params)
      end
      redirect_to admin_path, status: :see_other
    end

    def update_provider
      attributes = provider_params
      attributes.delete(:api_key) if attributes[:api_key].blank?
      attributes[:api_key] = nil if params[:clear_api_key] == "1"
      Provider.find(params[:id]).update!(attributes)
      redirect_to admin_path, status: :see_other
    end

    def create_model_route
      ModelRoute.create!(route_params)
      redirect_to admin_path, status: :see_other
    end

    def update_model_route
      ModelRoute.find(params[:id]).update!(route_params)
      redirect_to admin_path, status: :see_other
    end

    def destroy_model_route
      ModelRoute.find(params[:id]).destroy!
      redirect_to admin_path, status: :see_other
    end

    def create_gateway_key
      attributes = params.require(:gateway_key).permit(:name, :allowed_models, :expires_at).to_h
      attributes["allowed_models"] = attributes["allowed_models"].to_s.split(/[,\s]+/).reject(&:empty?).uniq
      @key, @token = GatewayKey.issue!(**attributes.symbolize_keys)
      render :key, status: :created
    end

    def revoke_gateway_key
      GatewayKey.find(params[:id]).update!(revoked_at: Time.current)
      redirect_to admin_path, status: :see_other
    end

    def style
      send_file Engine.root.join("app/assets/stylesheets/rails_ai_gateway/admin.css"), type: "text/css", disposition: "inline"
    end

    def logo
      send_file Engine.root.join("app/assets/images/rails_ai_gateway/logo.webp"), type: "image/webp", disposition: "inline"
    end

    def favicon
      send_file Engine.root.join("app/assets/images/rails_ai_gateway/favicon.webp"), type: "image/webp", disposition: "inline"
    end

    def script
      send_file Engine.root.join("app/assets/javascripts/rails_ai_gateway/admin.js"), type: "text/javascript", disposition: "inline"
    end

    def provider_logo
      raise ActiveRecord::RecordNotFound unless Provider::TEMPLATES.key?(params[:template])

      send_file Engine.root.join("app/assets/images/rails_ai_gateway/providers/#{params[:template]}.webp"), type: "image/webp", disposition: "inline"
    end

    private

    def require_current_schema!
      missing = {
        ModelRoute => %w[system_prompt capabilities query_keywords],
        RequestLog => %w[input_tokens output_tokens]
      }.flat_map { |model, columns| columns.reject { |column| model.column_names.include?(column) } }
      return if missing.empty?

      raise ActiveRecord::PendingMigrationError, "Rails AI Gateway database is outdated (missing: #{missing.join(", ")}). Run bin/rails railties:install:migrations && bin/rails db:migrate."
    end

    def authorize_admin
      response.headers["Cache-Control"] = "no-store"
      response.headers["Referrer-Policy"] = "same-origin"
      head :forbidden unless RailsAiGateway.configuration.admin_authorization.call(self) == true
    end

    def provider_params
      params.require(:provider).permit(:name, :base_url, :api_key, :enabled)
    end

    def route_params
      permitted = params.require(:model_route).permit(:name, :provider_id, :upstream_model, :priority, :system_prompt, :query_keywords, capabilities: [])
      permitted[:capabilities] = Array(permitted[:capabilities]).reject(&:blank?).uniq
      permitted[:query_keywords] = permitted[:query_keywords].to_s.split(/[,\n]/).map { |keyword| keyword.strip.downcase }.reject(&:blank?).uniq
      permitted
    end

    def invalid_record(exception)
      @errors = exception.record.errors.full_messages
      render :errors, status: 422
    end
  end
end
