# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Jumpstart Pro Rails is a commercial multi-tenant SaaS starter application built with Rails 8. It provides subscription billing, team management, authentication, and modern Rails patterns for building subscription-based web applications.

Docs: https://jumpstartrails.com/docs

## Development Commands

```bash
# Initial setup
bin/setup                    # Install dependencies and setup database

# Development server
bin/dev                      # Start development server with Overmind (includes Rails server, asset watching)
bin/rails server            # Standard Rails server only

# Database
bin/rails db:prepare         # Setup database (creates, migrates, seeds)
bin/rails db:migrate         # Run migrations
bin/rails db:seed           # Seed database

# Testing
bin/rails test              # Run test suite (Minitest)
bin/rails test:system       # Run system tests (Capybara + Selenium)

# Code quality
bin/rubocop                 # Run RuboCop linter (configured in .rubocop.yml)
bin/rubocop -a              # Auto-fix RuboCop issues

# Background jobs
bin/jobs                    # Start SolidQueue worker (if using SolidQueue)
bundle exec sidekiq         # Start Sidekiq worker (if using Sidekiq)
```

## Architecture

### Multi-tenancy System
- **Account-based tenancy**: Users belong to Accounts (personal or team)
- **AccountUser model**: Join table managing user-account relationships with roles
- **Current account switching**: Users can switch between accounts via `switch_account(account)`
- **Authorization**: Pundit policies scope data by current account

### Modular Models
Models use Ruby modules for organization:
```ruby
# app/models/user.rb
class User < ApplicationRecord
  include Accounts, Agreements, Authenticatable, Mentions, Notifiable, Searchable, Theme
end

# app/models/account.rb  
class Account < ApplicationRecord
  include Billing, Domains, Transfer, Types
end
```

### Jumpstart Configuration System
- **Dynamic configuration**: `config/jumpstart.rb` controls enabled features
- **Runtime gem loading**: `Gemfile.jumpstart` loads gems based on configuration
- **Feature toggles**: Payment processors, integrations, background jobs, etc.
- Access via `Jumpstart.config.payment_processors`, `Jumpstart.config.stripe?`, etc.

### Payment Architecture
- **Pay gem (~11.0)**: Unified interface for multiple payment processors
- **Processor-agnostic**: Stripe, Paddle, Braintree, PayPal, Lemon Squeezy support
- **Per-seat billing**: Team accounts with usage-based pricing
- **Subscription management**: In `app/models/account/billing.rb`
- **Email delivery**: Mailgun, Mailpace, Postmark, and Resend use API gems instead of SMTP
- **API client errors**: Raise `UnprocessableContent` for 422 responses (rfc9110)

## Technology Stack

- **Rails 8** with Hotwire (Turbo + Stimulus) and Hotwire Native
- **PostgreSQL** (primary), **SolidQueue** (jobs), **SolidCache** (cache), **SolidCable** (websockets)
- **Import Maps** for JavaScript (no Node.js dependency)
- **TailwindCSS v4** via tailwindcss-rails gem
- **Devise** for authentication with custom extensions
- **Pundit** for authorization
- **Minitest** for testing with parallel execution

## Testing

- **Minitest** with fixtures in `test/fixtures/`
- **System tests** use Capybara with Selenium WebDriver
- **Test parallelization** enabled via `parallelize(workers: :number_of_processors)`
- **WebMock** configured to disable external HTTP requests
- **Test database** reset between runs

### Test data

**Fixtures-only.** Test data lives in `test/fixtures/<table>.yml` (Minitest
fixtures, the Jumpstart/Rails default). Every new model gets a fixture file
with a small, named, hand-written set of records.

- **No FactoryBot, no Faker, no new gems.** Values are hand-written literals.
  If a slice believes it genuinely needs a factory library, stop and raise it
  as a product decision first — do not add it unilaterally.
- **Naming.** Use generic labels `one` and `two` for the baseline records,
  plus intent-named labels for records that exist to exercise a specific state
  (e.g. `subscribed`, `invited`, `admin`, `hidden`). This matches the existing
  `accounts.yml` / `users.yml` style and lets fixtures double as a readable
  data catalog.
- **Associations by label, never IDs.** Reference other fixtures by their
  fixture name (`owner: one`, `account: company`, `user: two`). Rails resolves
  the label to the record's id at load time. Never hard-code numeric ids.
- **Literals by default; ERB only for computed values.** Prefer plain literal
  values. Use ERB only where a literal can't express the value — e.g.
  timestamps (`<%= Time.current %>`) or derived secrets
  (`<%= Devise::Encryptor.digest(User, UNIQUE_PASSWORD) %>`), as `users.yml`
  already does. Don't use ERB to generate fake/random data.
- **Signing in / switching accounts in tests.** Reuse the existing helpers —
  don't reinvent them:
  - `sign_in(user)` (Devise) in integration and system tests.
  - `switch_account(account)` (defined in `test_helper.rb` and
    `application_system_test_case.rb`) to set the current account.

## Routes Organization

Routes are modularized in `config/routes/`:
- `accounts.rb` - Account management, switching, invitations
- `billing.rb` - Subscription, payment, receipt routes
- `users.rb` - User profile, settings, authentication
- `api.rb` - API v1 endpoints with JWT authentication

## Key Directories

- `app/controllers/accounts/` - Account-scoped controllers
- `app/models/concerns/` - Shared model modules
- `app/policies/` - Pundit authorization policies
- `lib/jumpstart/` - Core Jumpstart engine and configuration
- `config/routes/` - Modular route definitions
- `app/components/` - View components for reusable UI

## Current Project Decisions

- Dark mode is intentionally disabled. Keep the inert Tailwind `@variant dark`
  declaration so existing `dark:` utilities stay inactive; do not restore theme
  wiring or a system-preference fallback without an explicit product decision.

## Development Notes

- **Current account** available via `current_account` helper in controllers/views
- **Account switching** via `switch_account(account)` in tests
- **Billing features** conditionally loaded based on `Jumpstart.config.payments_enabled?`
- **Background jobs** configurable between SolidQueue and Sidekiq
- **Multi-database** setup with separate databases for cache, jobs, and cable

## Known Gotchas

### Environment
- The shell used by coding agents in this checkout doesn't pick up mise's Ruby
  shims by default — `bin/rails` fails against system Ruby (2.6.10) with a
  `Bundler::GemfileError` about an invalid `windows` platform, then a missing
  bundler version. Prepend the shims dir before any `bin/rails`/`bin/rubocop`
  command: `export PATH="$HOME/.local/share/mise/shims:$PATH"`. Confirm with
  `ruby -v` (should report 4.0.5, matching `.ruby-version`) before trusting
  test/migration output.
- Don't run RuboCop directly on `.erb` paths — it parses them as Ruby and
  fails. Use the project-wide `bin/rubocop` command instead.
- `ApplicationController.render` isn't usable for smoke-testing authenticated
  views — the app layout expects Devise/Warden state it doesn't have. Use a
  temporary Rails/Puma server plus curl against `/dev/kitchen_sink` or
  `/lookbook` instead.

### System tests
- `bin/rails test:system TEST=path/to/test.rb -n /pattern/` is unreliable in
  this checkout (incompatible syntax / deprecation warning on `-n`). Run a
  specific test with the positional file argument and `-i` instead, e.g.
  `bin/rails test:system test/system/foo_test.rb -i "test name"`.
- This Capybara version does not reliably resolve `click_button` against
  `aria-label` attributes. Use CSS attribute selectors
  (`find("[aria-label='...']").click`) instead.

### Design-system components
- `DropdownComponent#with_item_link` has no `data_turbo` option — passing one
  is silently unsupported. For a non-Turbo link (e.g. `target: :_blank`,
  `data: { turbo: false }`), use `with_item_custom` instead.
- `CheckboxComponent` doesn't render Rails' hidden unchecked-value field the
  way `f.check_box` does. When replacing `f.check_box` with it, add an
  explicit hidden `"0"` field immediately before the checkbox or the param
  will be missing entirely when unchecked.
- `ButtonComponent`'s `href` expects a literal URL string (e.g.
  `api_token_path(record)`) — it does not do polymorphic routing on a record.
- A component that calls app helpers (e.g. `PlanCardComponent` + `PlanHelper`)
  must `include` the helper module itself — Lookbook preview rendering
  doesn't reliably expose `helpers.*` through the component's render context.
- A caller block yielded into a layout partial does NOT inherit that
  partial's lazy-i18n scope — `t('.foo')` inside the block resolves relative
  to the calling view, not the layout. Verify translation keys explicitly
  when migrating views that render through `layout: "..." do ... end`.
- Before installing a component from Rails Blocks, check for name collisions
  in both `app/components/` and `lib/jumpstart/app/components/` — several
  Jumpstart-engine components (`ToastComponent`, `ModalComponent`,
  `TabsComponent`) only live under the `lib/` path and are easy to miss.
- Pagination previews/tests using `Pagy::Offset` need a `Pagy::Request`, or
  the link helpers can't derive a base URL.
- `importmap pin --download` isn't supported by this project's importmap CLI;
  use the plain `importmap pin` form.

### CSS / Tailwind
- Tailwind v4 compiles variants with nested CSS rules. Don't use naive CSSOM
  traversal with `Element.matches()` to identify the winning rule — nested
  `CSSStyleRule`s can be skipped. Search the compiled Tailwind CSS text
  instead.
- The app still has legacy Jumpstart token styles alongside newer
  RailsBlocks/Tailwind styles. If native controls look wrong, first check for
  competing bare `[type="checkbox"]` or `[type="radio"]` rules before
  changing the component.
- Braintree's dark-mode selector is a mixed `:is(.dark .braintree-placeholder,
  .braintree-heading)` rule — it is not fully dark-mode-only. Preserve the
  light-mode `.braintree-heading` branch when stripping dark-mode CSS.
