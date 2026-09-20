# Changelog

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
