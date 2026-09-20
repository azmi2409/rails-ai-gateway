module RailsAiGateway
  module ModelHelper
    module_function

    def models(capabilities: nil, provider: nil)
      routes = ModelRoute.available.includes(:provider).order(:name, :priority)
      routes = routes.where(provider_id: provider.id) if provider.is_a?(Provider)
      routes = routes.where(rails_ai_gateway_providers: { name: provider.to_s }) if provider.present? && !provider.is_a?(Provider)
      required = Array(capabilities).map(&:to_s)

      routes.group_by(&:name).filter_map do |name, model_routes|
        model_capabilities = model_routes.flat_map(&:capabilities).uniq.sort
        next unless (required - model_capabilities).empty?

        {
          id: name,
          capabilities: model_capabilities,
          routes: model_routes.map { |route| route_metadata(route) }
        }
      end
    end

    def model(name)
      models.find { |entry| entry[:id] == name.to_s }
    end

    def route_for(model:, query:)
      route = ModelRoute.ranked_for_query(name: model, query: query).first
      route_metadata(route) if route
    end

    def route_metadata(route)
      {
        id: route.id,
        provider: route.provider.name,
        upstream_model: route.upstream_model,
        priority: route.priority,
        capabilities: route.capabilities,
        query_keywords: route.query_keywords
      }
    end
    private_class_method :route_metadata
  end
end
