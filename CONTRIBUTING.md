# Contributing to Rails AI Gateway

Bug reports, fixes, tests, documentation, and focused feature proposals are welcome.

## Report Bugs

Open GitHub issue with:

- Rails, Ruby, database adapter, and gem versions
- Minimal reproduction steps
- Expected and actual behavior
- Relevant exception and backtrace with secrets removed
- Browser name and version for Web UI bugs
- Upstream provider and endpoint type without API credentials

Never include provider API keys, gateway keys, database passwords, prompts, responses, or
other private application data.

Report vulnerabilities privately through
[GitHub security advisories](https://github.com/azmi2409/rails-ai-gateway/security/advisories/new).

## Development Setup

```bash
git clone https://github.com/azmi2409/rails-ai-gateway.git
cd rails-ai-gateway
bundle install
bundle exec ruby test/check.rb
```

Test uses temporary SQLite database and local fake upstream. No provider account or network
request is required.

To test PostgreSQL, create empty disposable database and pass its URL:

```bash
createdb rails_ai_gateway_test
DATABASE_URL=postgresql:///rails_ai_gateway_test bundle exec ruby test/check.rb
dropdb rails_ai_gateway_test
```

## Changes

- Keep changes focused and backward compatible after public release.
- Add or update integration checks for behavior changes.
- Preserve Ruby 3.3 and Rails 8 compatibility.
- Support SQLite and PostgreSQL unless change explicitly targets one adapter.
- Avoid runtime dependencies when Ruby, Rails, or current dependencies cover need.
- Keep Web UI dependency-free, responsive, keyboard-accessible, and screen-reader friendly.
- Never weaken gateway-key authentication, credential encryption, request limits, SSRF
  protections, CSRF protection, or default-deny admin authorization.
- Never persist prompts, responses, raw gateway keys, or unencrypted provider credentials.
- Never retry ambiguous upstream failures or a stream after response bytes are sent.

## Pull Requests

1. Create branch from `main`.
2. Make focused change with test coverage.
3. Run `bundle exec ruby test/check.rb`.
4. Run PostgreSQL integration when changing migrations, models, or queries.
5. Run `gem build rails_ai_gateway.gemspec`.
6. Open pull request describing problem, solution, security impact, and verification.

By contributing, you agree your contribution is licensed under project MIT license.
