# Rails AI Gateway

[![Gem Version](https://badge.fury.io/rb/rails-ai-gateway.svg)](https://rubygems.org/gems/rails-ai-gateway)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Put one OpenAI-compatible endpoint in front of your AI providers without running another
service. Rails AI Gateway mounts inside your Rails app, stores configuration and request
metadata with ActiveRecord, and includes a Web UI for providers, model routes, and keys.

## What You Get

- OpenAI-compatible chat completions, embeddings, and model-list endpoints
- Streaming chat completions over server-sent events
- Public model aliases with ordered provider fallbacks
- Encrypted provider API keys using ActiveRecord encryption
- Scoped gateway keys stored as SHA-256 digests
- Request status, latency, attempt, and reported token-usage logs
- Durable input/output token totals grouped by public model
- Optional system prompt injection configured per model route
- One-key provider templates for OpenAI, OpenRouter, Groq, DeepSeek, Mistral, Cerebras,
  Nebius AI, and Perplexity
- Explicit model capabilities exposed through UI and `/v1/models`
- Configurable timeouts, body limits, fallback attempts, and network policy
- SSRF protection with DNS validation and address pinning
- Server-rendered, responsive, accessible admin UI
- SQLite and PostgreSQL support through host Rails database
- No prompts or responses persisted

## Get Started

Add gem:

```ruby
gem "rails-ai-gateway"
```

Set it up:

```bash
bundle install
bin/rails generate rails_ai_gateway:install
bin/rails db:migrate
```

Generator creates `config/initializers/rails_ai_gateway.rb`, copies migrations, and mounts
engine at `/ai`. Configure admin authorization, restart Rails, then visit:

<http://localhost:3000/ai/admin>

Host app must configure
[ActiveRecord encryption](https://guides.rubyonrails.org/active_record_encryption.html).
Provider API keys cannot be saved without it.

## Configure Gateway

Web UI guides initial setup:

1. Add provider with full API base URL, such as `https://api.openai.com/v1`.
2. Add public model route, such as `fast-chat` mapped to `gpt-5.6-luna`.
3. Create gateway key and save token when shown. Raw token cannot be displayed again.

Popular provider templates need only API key. Custom OpenAI-compatible provider form remains
available for self-hosted and less common endpoints.

Routes with same public model name form fallback chain. Lower priority runs first. Gateway
retries connection failures before upstream accepts request and HTTP `429`, `500`, `502`,
`503`, or `504`. Ambiguous timeouts and started streams are never retried.

## Initializer

Runtime and security policy live in `config/initializers/rails_ai_gateway.rb`:

```ruby
RailsAIGateway.configure do |config|
  config.admin_controller = "ApplicationController"
  config.admin_authorization = ->(controller) {
    controller.current_user&.admin? == true
  }

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

Rails acronym inflection exposes `RailsAIGateway` as the preferred constant while keeping
`RailsAiGateway` compatible. Use the endpoint constant instead of repeating a URL path:

```ruby
OpenAI::Client.new(uri_base: "#{ENV.fetch("APP_URL")}#{RailsAIGateway::ENDPOINT}")
```

`RailsAIGateway::ENDPOINT` is `/ai/v1`, matching the generator's default mount. If host app
changes mount path, build endpoint from that route instead.

Admin requests are denied until `admin_authorization` returns exactly `true`. Provider
definitions, model routes, gateway keys, and logs stay database-backed and editable through
Web UI.

Need another mount path? Change host route:

```ruby
mount RailsAIGateway::Engine, at: "/gateway"
```

## Make Requests

```bash
curl http://localhost:3000/ai/v1/chat/completions \
  -H "Authorization: Bearer rag_REPLACE_ME" \
  -H "Content-Type: application/json" \
  -d '{"model":"fast-chat","messages":[{"role":"user","content":"Hello"}]}'
```

Available endpoints:

- `GET /ai/v1/models`
- `POST /ai/v1/chat/completions`
- `POST /ai/v1/embeddings`

OpenAI clients can use `http://localhost:3000/ai/v1` as base URL.

Each model route can prepend an optional system message to chat requests. Injected prompts
are stored on route and are never copied into request logs. Token dashboards use only usage
reported by upstream providers; missing usage remains zero rather than being estimated.
Routes declare capabilities from `text`, `vision`, `embedding`, `audio`, `video`, `tools`,
and `reasoning`; clients receive merged capabilities in each `/v1/models` entry. Capability
metadata does not add unsupported transport endpoints by itself.

Host Rails code can inspect active models without making an HTTP request:

```ruby
RailsAIGateway.models
RailsAIGateway.models(capabilities: %w[vision tools])
RailsAIGateway.models(provider: "OpenAI")
RailsAIGateway.model("fast-chat")
RailsAIGateway.route_for(model: "fast-chat", query: "Review this Ruby code")
```

Helpers return provider names and routing metadata, never provider API keys. `route_for`
uses same literal keyword ranking as proxy: matching specialized routes first, then generic
fallback routes.

## Development

```bash
git clone https://github.com/azmi2409/rails-ai-gateway.git
cd rails-ai-gateway
bundle install
bundle exec ruby test/check.rb
gem build rails_ai_gateway.gemspec
```

SQLite integration runs by default. Run same suite against PostgreSQL with an empty test
database:

```bash
DATABASE_URL=postgresql:///rails_ai_gateway_test bundle exec ruby test/check.rb
```

Found bug or have focused improvement? Read [CONTRIBUTING.md](CONTRIBUTING.md), then open
issue or pull request. Release notes live in [CHANGELOG.md](CHANGELOG.md).

## Security

Never expose admin UI without host authentication and authorization. Keep
`allow_private_networks` and `allow_http` disabled for public providers. Enable both only
for trusted internal endpoints, such as local Ollama. Never commit provider or database
credentials.

Report security issues privately through
[GitHub security advisories](https://github.com/azmi2409/rails-ai-gateway/security/advisories/new),
not public issues.

## Current Scope

Current release supports OpenAI-compatible chat completions, embeddings, and model-list
endpoints. Native Anthropic, Gemini, Bedrock, budgets, semantic caching, and multi-tenancy
are not included.

## License

[MIT](LICENSE).
