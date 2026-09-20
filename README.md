# Rails AI Gateway

Mountable Rails engine providing an OpenAI-compatible AI gateway, ActiveRecord persistence, ordered fallbacks, streaming, encrypted provider credentials, request logs, and an admin UI.

## Requirements

- Ruby 3.3 or newer
- Rails 8.0 or newer
- SQLite or PostgreSQL
- ActiveRecord encryption configured by host application

## Install

```ruby
# Gemfile
gem "rails-ai-gateway"
```

```bash
bundle install
bin/rails generate rails_ai_gateway:install
bin/rails db:migrate
```

Generator mounts engine at `/ai`. Change mount path in `config/routes.rb` when needed:

```ruby
mount RailsAiGateway::Engine, at: "/gateway"
```

Host app must configure [ActiveRecord encryption](https://guides.rubyonrails.org/active_record_encryption.html). Provider API keys use encrypted columns.

## Initializer

`config/initializers/rails_ai_gateway.rb` controls runtime and security policy:

```ruby
RailsAiGateway.configure do |config|
  config.admin_controller = "ApplicationController"
  config.admin_authorization = ->(controller) { controller.current_user&.admin? == true }

  config.open_timeout = 5
  config.read_timeout = 60
  config.write_timeout = 30
  config.request_timeout = 120
  config.max_request_bytes = 2 * 1024 * 1024
  config.max_response_bytes = 16 * 1024 * 1024
  config.max_attempts = 3

  config.allow_private_networks = false
  config.allow_http = false
end
```

Admin access denies every request until `admin_authorization` returns exactly `true`. Keep `allow_private_networks` and `allow_http` disabled for public providers. Enable both only for trusted internal endpoints such as local Ollama.

Provider definitions, model routes, gateway keys, and request logs remain database-backed and editable through UI.

## Configure

Open `/ai/admin` and create:

1. Provider with API base URL, such as `https://api.openai.com/v1`.
2. Public model route mapping to provider model, such as `fast-chat` to `gpt-4o-mini`.
3. Gateway key. Token appears once; only SHA-256 digest remains stored.

Routes sharing public model name form fallback chain ordered by priority. Gateway retries only connection failures before upstream accepts request and HTTP `429`, `500`, `502`, `503`, or `504`. It never retries ambiguous timeouts or started streams.

## Use

```bash
curl http://localhost:3000/ai/v1/chat/completions \
  -H "Authorization: Bearer rag_REPLACE_ME" \
  -H "Content-Type: application/json" \
  -d '{"model":"fast-chat","messages":[{"role":"user","content":"Hello"}]}'
```

Endpoints:

- `GET /ai/v1/models`
- `POST /ai/v1/chat/completions`
- `POST /ai/v1/embeddings`

OpenAI clients can use `http://localhost:3000/ai/v1` as base URL. Chat streaming uses SSE. Prompts and responses are proxied but never persisted; logs contain request metadata, attempts, latency, status, and reported non-streaming token usage.

## Test

```bash
bundle exec ruby test/check.rb
gem build rails_ai_gateway.gemspec
```

Set PostgreSQL URL to run same integration check against PostgreSQL:

```bash
DATABASE_URL=postgresql:///rails_ai_gateway_test bundle exec ruby test/check.rb
```

## Current Scope

OpenAI-compatible chat completions, embeddings, and models endpoints. Native Anthropic, Gemini, Bedrock, budgets, semantic caching, and multi-tenancy are not included.

## License

[MIT](LICENSE)
