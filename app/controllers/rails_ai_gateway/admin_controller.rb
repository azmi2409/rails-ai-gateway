module RailsAiGateway
  class AdminController < RailsAiGateway.configuration.admin_controller.constantize
    layout "rails_ai_gateway/admin"
    protect_from_forgery with: :exception
    before_action :authorize_admin
    rescue_from ActiveRecord::RecordInvalid, with: :invalid_record
    rescue_from ActiveRecord::RecordNotFound, with: -> { head :not_found }
    rescue_from ActiveRecord::RecordNotUnique, with: -> { render plain: "Name or priority already exists", status: 422 }

    def index
      @providers = Provider.order(:name)
      @routes = ModelRoute.includes(:provider).order(:name, :priority)
      @keys = GatewayKey.order(created_at: :desc)
      recent = RequestLog.where(created_at: 24.hours.ago..)
      @requests = recent.count
      @errors = recent.where(status: 400..599).count
      @latency = recent.average(:duration_ms)&.round || 0
      logs = RequestLog.order(id: :desc)
      logs = logs.where(model: params[:model]) if params[:model].is_a?(String) && params[:model].present?
      logs = logs.where(status: params[:status].to_i) if params[:status].to_s.match?(/\A[1-5][0-9]{2}\z/)
      logs = logs.where("id < ?", params[:before].to_i) if params[:before].to_s.match?(/\A[0-9]+\z/)
      @logs = logs.limit(50)
    end

    def create_provider
      Provider.create!(provider_params)
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

    private

    def authorize_admin
      response.headers["Cache-Control"] = "no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
      head :forbidden unless RailsAiGateway.configuration.admin_authorization.call(self) == true
    end

    def provider_params
      params.require(:provider).permit(:name, :base_url, :api_key, :enabled)
    end

    def route_params
      params.require(:model_route).permit(:name, :provider_id, :upstream_model, :priority)
    end

    def invalid_record(exception)
      @errors = exception.record.errors.full_messages
      render :errors, status: 422
    end
  end
end
