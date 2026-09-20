RailsAiGateway::Engine.routes.draw do
  get "v1/models", to: RailsAiGateway::Proxy.new("models")
  post "v1/chat/completions", to: RailsAiGateway::Proxy.new("chat/completions")
  post "v1/embeddings", to: RailsAiGateway::Proxy.new("embeddings")

  root to: redirect("admin")
  get "admin", to: "admin#index", as: :admin
  post "admin/providers", to: "admin#create_provider", as: :providers
  patch "admin/providers/:id", to: "admin#update_provider", as: :provider
  delete "admin/providers/:id", to: "admin#destroy_provider"
  post "admin/model_routes", to: "admin#create_model_route", as: :model_routes
  patch "admin/model_routes/:id", to: "admin#update_model_route", as: :model_route
  delete "admin/model_routes/:id", to: "admin#destroy_model_route"
  post "admin/gateway_keys", to: "admin#create_gateway_key", as: :gateway_keys
  delete "admin/gateway_keys/:id", to: "admin#revoke_gateway_key", as: :gateway_key
  get "admin/style", to: "admin#style", as: :style
  get "admin/logo", to: "admin#logo", as: :logo
  get "admin/favicon", to: "admin#favicon", as: :favicon
  get "admin/script", to: "admin#script", as: :script
  get "admin/providers/:template/logo", to: "admin#provider_logo", as: :provider_logo
end
