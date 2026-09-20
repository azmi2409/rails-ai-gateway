# Changelog

## 0.2.1 - 2026-09-20

- Add durable input/output token totals grouped by public model.
- Add per-route system prompt injection without prompt logging.
- Add `RailsAIGateway::ENDPOINT`, `AI` inflection, and `RailsAIGateway` namespace alias.
- Add one-key templates for popular OpenAI-compatible providers.
- Add model capability metadata to routes, admin UI, and `/v1/models`.
- Add provider logos, modal connection flow, and deterministic keyword query routing.
- Add `models`, `model`, and `route_for` helpers for host Rails code.

## 0.2.0 - 2026-09-20

- Redesign admin UI as a responsive AI gateway operations console.
- Add generated WebP brand mark and favicon served under any engine mount path.
- Improve dashboard metrics, provider and route summaries, key status, and request-log scanning.
- Add mobile card tables, stronger keyboard focus, and reduced-motion support.

## 0.1.1 - 2026-09-20

- Fix automatic Bundler loading for hyphenated gem name.
- Fix install generator migration task for host Rails applications.
- Normalize provider API roots to prevent duplicated endpoint paths.
- Normalize upstream errors, preserve safe `Retry-After`, and terminate failed SSE streams.
- Validate successful embedding response shape.
- Improve installation, security, development, and contribution documentation.

## 0.1.0 - 2026-09-20

- Add mountable Rails engine with OpenAI-compatible chat, embedding, and model endpoints.
- Add ActiveRecord providers, model routing, gateway keys, request logs, and admin UI.
- Add encrypted provider credentials, ordered fallback, bounded responses, SSE streaming, and SSRF protections.
- Add initializer configuration for authorization, timeouts, limits, attempts, and network policy.
