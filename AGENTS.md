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
- **Don't compare `Time.current` across fixture files.** Each ERB
  `Time.current` is evaluated when its file loads, so two "now" values in
  different files differ by microseconds in an unpredictable order. Code that
  compares them (e.g. `marketing_opt_in_at` vs a webhook event's `event_time`)
  flakes ~1 run in 10. Give the earlier value an explicit offset
  (`<%= 1.day.ago %>`).
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
- Product docs in `docs/product/`: `product-brief.md` — behavior rules;
  read before changing families, learners, billing, plan status,
  notifications, AI behavior, or anything that stores learner data.
  `ux-notes.md` — read before writing user-facing text, screen states, or page layout.
  `strategy-brief.md` — who Cove is for, its positioning, and what it doesn't do.
  Only add to these docs what is cross-cutting, not visible in code, and true now.
  Specs for features not yet built live in their tickets. When a ticket ships
  something that meets that bar, update the doc in the same PR.
- Glossary (use these terms in UI copy and docs):
  - **Family** = `Account`. **Parent** = an `AccountUser` (all are admins);
    **Owner** = the one parent who can delete the family or transfer ownership.
  - **Learner** = a record owned by the family, not a login.
  - **Class** = `Course` (the UI says class; `class` is reserved in Ruby).
    **Subject** = a field on a class. **Enrollment** = the internal learner–class
    link; never use it in UI copy.
  - **Premium** = the paid plan (or Complimentary Premium) — never a design
    adjective; say "polished". **Complimentary** = superadmin-granted Premium.
  - **Plan** in code = billing plan (`Plan` model). In UI copy, the
    learning plan is a **school plan**.
  - **Today** = the signed-in home page (the sidebar says "Home" until Today
    is built). **Planner** = where school plans are built and viewed (the
    `/schedules` placeholder is renamed when the Planner is built; never
    "calendar" for the page). Its items are **schedule blocks**. Schedule
    blocks are **done**; classes are **completed**.
- Adding or removing a parent must not change subscription quantity.
- Normal sessions never switch families; derive the current family from the
  user membership rather than an account cookie.
- Personal accounts no longer exist: `accounts.personal` is DB-constrained to
  always be `false` (`accounts_personal_must_be_false` check constraint in
  `db/schema.rb`, added by COV-72). `Account#personal?`-gated code paths and
  test fixtures for personal accounts are unreachable — don't write tests
  that assume a `personal: true` fixture can exist.
- Plan rows are never deleted or re-priced — a price change is a new Stripe Price + new Plan row, old row hidden. Follow `docs/runbooks/price-change-checklist.md`.
- No feature logic may depend on a price, amount, plan name, or Stripe ID — prices will change. Gate features on `Account#premium?` / `#plan_status`.
- Brand palette: teal (`--primary`, `--primary-hover`), cream (`--background`), coral (`--accent-brand`, used only via `--bg-accent`/`--border-accent`). Reference these tokens; don't repeat the hex values. Neutrals (`neutral-*`, and `gray-*` which maps to it) point at Tailwind's warm `stone` scale, and the red/orange/yellow/green/blue/purple/pink scales are redefined muted in `application.css` `@theme` (same lightness steps as Tailwind's defaults, so contrast is unchanged).
- Typography: only `h1`/`h2` (and `.font-display`) use the serif (`--font-serif`, self-hosted Fabric Serif Web, 400 only — no other weight is installed); `h3`–`h6` and body use the sans (`--font-sans`, self-hosted Geist, static 400/500/600/700; `h3`–`h6` are weight 500, `h1` is 1.75rem). Settings pages (`layouts/sidebar.html.erb`, wrapper class `settings-content`) render their sub headings (`.h3`/`.h4`, plus billing's `.section-heading`) in the serif. Both carry OpenType feature settings via Tailwind v4's paired `--font-sans--font-feature-settings` / `--font-serif--font-feature-settings` theme keys — see the CSS/Tailwind gotcha below for why raw `font-family: var(--font-serif)` rules need that variable set explicitly. Buttons and inputs have no drop shadows (the opt-in `fancy` button style keeps its own).

- Brand assets: `app/assets/images/logo.svg` is the full wordmark (mark + "Cove"), used via `application/_brand` (keep its `sr-only` app name — it is the logo link's accessible name and tests assert it); `mark.svg` is the icon-only version of it, shown by `SidebarComponent`'s `collapsed_logo` slot. Both have hardcoded fills (not `currentColor`). Update `mark.svg` whenever the logo's icon changes.
- Page content is capped at `max-w-[88rem]` and centered by a wrapper in each shell (`layouts/application.html.erb` for signed-out, `application/_sidebar.html.erb` for signed-in). Only one renders per request.

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
- Running `bin/rails db:migrate` (or `db:drop db:create db:migrate`) locally
  regenerates `db/cable_schema.rb`, `db/cache_schema.rb`, and
  `db/queue_schema.rb` with reordered columns and a different header — a
  pre-existing drift between the committed dumps and the locked Rails 8.1.3
  dumper, not something caused by app changes. After any local
  migration/seed verification, `git checkout --` those three files so the
  noise doesn't get committed. `db/schema.rb` itself is now in sync and only
  diffs for the real change (confirmed in COV-109), but still `git diff` it.
- `bin/rails db:rollback` aborts here because the app is multi-database. Use
  `bin/rails db:rollback:primary` to check a migration is reversible.
- Renaming a model/term app-wide (COV-109, students → learners): a blanket
  find-and-replace over `test/` also rewrites tests that intentionally assert
  the *old* word is absent (e.g. `assert_no_match(/student/i, ...)` in
  `terms_page_test.rb`) and the rename migration's own test — exclude those
  and re-read them. A table-rename migration can't be verified in isolation:
  fixtures with association labels (`account: one`) need the renamed model, so
  do the migration, model, and fixtures in one step. Do copy changes first,
  then the mechanical identifier rename. Compiled `app/assets/builds/` is
  gitignored but stale after a CSS-token rename — run
  `bin/rails tailwindcss:build`.
- `User` does not include Devise `:confirmable` (see
  `lib/jumpstart/app/models/user/authenticatable.rb`), even though the
  `users` table has a `confirmed_at` column that seeds/fixtures set.
  `user.confirmed?` is not a valid method — check `confirmed_at.present?`
  instead.

- A leftover gitignored `public/assets/` (from `assets:precompile`) makes the
  dev server serve its manifest's stale digested files instead of the freshly
  built Tailwind CSS — CSS edits then "do nothing" even after a rebuild or a
  `bin/dev` restart (compiled `app/assets/builds/tailwind.css` is correct, but
  the page links an old `tailwind-<digest>.css`). Fix: `bin/rails assets:clobber`,
  then restart the server.

### Staging (Render) and Stripe credential workflow
- Render Free-tier services provide no Shell or One-Off Jobs — there's no way
  to run `bin/rails console` against staging directly. Any console-only
  operation needed there has to go through a purpose-built, temporary,
  operator-gated authenticated bridge (removed once its job is done), not an
  ad hoc console session.
- Render's masked environment-variable editor doesn't reliably confirm a
  saved value. Verify env var/config changes landed by checking observable
  app behavior (a status endpoint, logs) after redeploy, not the editor UI.
- This checkout has no `config/credentials/staging.key` on disk. Editing/
  viewing staging credentials requires the real `RAILS_MASTER_KEY` (from
  Render's env vars) `export`ed in the **same terminal** as the
  `credentials:edit`/`credentials:show --environment staging` command — a
  one-off `KEY=... command` prefix does not persist for a later command in
  the same session. A wrong/malformed key fails differently depending on
  what boots first: `AEAD authentication tag verification failed` if the key
  can't decrypt the file at all, or a deeper `key must be 16 bytes` boot
  failure (from an initializer touching credentials before the command's own
  output prints) if the key string isn't valid 32-hex-char format — sanity
  check with `echo -n "$RAILS_MASTER_KEY" | wc -c` (expect `32`) before
  troubleshooting anything else. No `$EDITOR`/`$VISUAL` is set by default;
  use `VISUAL="zed --wait" mise exec -- bin/rails credentials:edit
  --environment staging`.
- Stripe webhook destination signing secrets can silently drift from what's
  in credentials with zero errors until an actual delivery is attempted
  (manifests as HTTP 400, empty body, from `/webhooks/stripe` —
  `Pay::Webhooks::StripeController` rescuing
  `Stripe::SignatureVerificationError`). Compare the destination's revealed
  secret against credentials directly rather than assuming they match.
- Different Stripe accounts can look identical in casual conversation ("test
  mode", "sandbox") while being entirely separate. Compare the account id
  embedded in the publishable key (`pk_test_51<account_id>...`) rather than
  assuming "test mode" means "the same account." A local `Pay::Customer`/
  `Pay::Subscription` row's `processor_id`/`processor_plan` can reference an
  object that doesn't exist for whatever Stripe account credentials
  currently point at (stale from an earlier session or a mid-flow
  credentials fix) — this fails late inside
  `CheckoutsController#set_checkout_session` as `Stripe::InvalidRequestError`,
  not as a validation error.
- Specific-commit Render deploys are manual, easy to mis-select from the
  commit list, and disable auto-deploy. Always confirm the exact deployed
  SHA after a deploy, not just that "a deploy succeeded."

### Jumpstart configuration
- Don't run the Jumpstart config generator (`Jumpstart.config.save`, or Save in
  the `/jumpstart` UI) to turn on an integration. It bundles three actions and
  only one is wanted: `copy_configs` copies a template from `lib/templates/`
  (wanted); `write_config` regenerates `config/jumpstart.rb` through
  `pretty_inspect`, reformatting/reordering the whole file; and
  `update_procfiles` **creates a root `Procfile`**, which this repo
  deliberately does not have — deploy start commands live in `render.yaml`'s
  `startCommand`, and a `Procfile` would state a different, migration-less
  start command. Instead: hand-edit the array in `config/jumpstart.rb` and copy
  the template file yourself.
- Integration predicates (`Jumpstart.config.honeybadger?`, `.sentry?`, …) are
  auto-defined from the `INTEGRATIONS` hash in
  `lib/jumpstart/lib/jumpstart/configuration.rb`, driven solely by the
  `integrations` array — and `Gemfile.jumpstart` already carries a
  `gem "..." if Jumpstart.config.x?` line for every supported integration. So
  adding the name to the array plus `bundle install` is the entire gem install;
  there is no "Gemfile entry to generate."

### System tests
- `bin/rails test:system TEST=path/to/test.rb -n /pattern/` is unreliable in
  this checkout (incompatible syntax / deprecation warning on `-n`).
  `bin/rails test:system` ignores a positional file and runs every system
  test. To run one system test file, use `bin/rails test test/system/foo_test.rb`
  (add `-i "test name"` for a single test).
- Don't run system tests concurrently with another Rails test process in this
  linked worktree — it causes unrelated browser/authentication failures. Keep
  Rails test runs sequential.
- Stimulus controllers load lazily, so a system test that assigns a remote
  `<turbo-frame>`'s `src` before its fetch stub is installed races the
  controller load. Assign `src` only after the stub exists — this is a real
  ordering bug (seen in `TurboResilience`), not a flaky parallel run.
- Browser-side date assertions need fixture timestamps at noon UTC; otherwise
  a timezone shift moves the rendered date by a day.
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
- The `app/helpers/` name-collision risk isn't limited to ViewComponents
  (see the collision note above) — a same-named file there doesn't *reopen*
  a same-named engine module. `app/helpers/flash_helper.rb` does not merge
  with Jumpstart's `lib/jumpstart/app/helpers/flash_helper.rb`; Zeitwerk only
  loads one file per constant path, so the app-level file silently replaces
  the engine's module wholesale (this broke `impersonation_banner` and the
  `toasts` flash helper entirely, with no load-time error). Add new helper
  methods to an already app-owned module (e.g. `ApplicationHelper`) instead
  of a filename that collides with a vendored one.
- `UiToastComponent` (+ `ui_toast_controller.js`) is a page-wide toast host
  meant to be rendered exactly once, globally, via `application/_flash`. A
  second instance rendered on an individual page (e.g. a demo/preview)
  creates a competing `[popover]` host that fights the first for the
  "primary controller" role, producing duplicated/misplaced toasts.

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
- Fonts are self-hosted from `app/assets/fonts/` via `@font-face` in `application.css`: Geist (static 400/500/600/700, no variable font) for `--font-sans`, Fabric Serif Web (400 only, a purchased web license) for `--font-serif`. Use a plain filename in `url("...")` (not `/assets/...`) so Propshaft rewrites it to the digested path. A new `app/assets/*` subfolder isn't picked up by an already-running dev server — restart `bin/dev`. Before self-hosting any other downloaded font (trial or otherwise), check its actual `usWeightClass` and glyph coverage with `fonttools` rather than trusting the filename — a "Medium" file isn't always weight 500, and Klim/Monokrom trial cuts silently drop punctuation glyphs like the apostrophe (falls back to the next font in the stack, per-glyph, with no error).
- Tailwind v4's paired `--font-<name>--font-feature-settings` theme key (e.g. `--font-serif--font-feature-settings`) only applies automatically through the generated `.font-sans`/`.font-serif` utility *classes*. A raw CSS rule that sets `font-family: var(--font-serif)` directly (as `typography.css`'s `h1`/`h2`/`.font-display` rules do) does NOT get the paired feature-settings for free — since `font-feature-settings` inherits, it silently picks up whatever the nearest ancestor set (usually `--font-sans`'s, from `<body>`) instead. Set `font-feature-settings: var(--font-serif--font-feature-settings)` explicitly on any such rule.
- Shared control class names can be defined in more than one stylesheet with
  no error. `.form-control` is defined in both
  `app/assets/tailwind/components/forms.css` (hand-written: a real
  `border-width` at rest and on `:focus`) and
  `app/assets/tailwind/rails_blocks/base.css` (Tailwind-generated: `border-width: 0`
  plus a box-shadow ring). Because `rails_blocks/base.css` imports after
  `forms.css`, its `border-width: 0` wins at rest — but `forms.css`'s
  `:focus` rule (a pseudo-class, so it still applies) set a real border,
  which grew the field by 2px and pushed surrounding layout on focus. Check
  both files before changing a shared class, not just the one you think
  owns it; prefer a box-shadow-only focus ring so a border-width mismatch
  like this can't reflow anything. Same duplicate-definition trap bit again
  as a ring *color* mismatch: `rails_blocks/base.css`'s `.form-control` and
  `select` had a leftover `focus:ring-neutral-600` never updated when COV-36
  moved form focus rings to `--primary` (teal) — check this file too when a
  focus ring looks like the wrong color, not just when it reflows.
- `h1`/`h2` tag selectors in `typography.css` set the serif display font
  app-wide, so any component that renders its title into a bare `<h2>` (or
  `<h1>`) — not a `.h3`-style class override — silently inherits it even
  when the title is meant to be a small sans UI label. Hit this
  independently in `EmptyStateComponent`, `UiModalComponent`, and
  `Drawer::Component`'s title, all fixed the same way (add `font-sans` to
  the title's class string). Check any *other* component that renders a
  title into a bare heading tag for the same bug before it's reported.
- Elements using the native Popover API (`showPopover()` / `popover`
  attribute — `UiToastComponent`'s container is one) get a UA-stylesheet
  default `background-color: canvas` (opaque white) and border. Nothing in
  this app's CSS overrides that automatically; any `[popover]`-based
  component needs its own explicit `bg-transparent border-0` (or an
  intentional background) or it silently renders an unwanted white box.
- `muted` is a *background* token (`bg-muted`), so stock Jumpstart views' `text-muted`
  would render near-white text. An unlayered `.text-muted` rule at the end of
  `application.css` points it at `--muted-foreground`. It has to be unlayered: a
  Tailwind `@utility text-muted` override is ignored (the theme-derived utility wins),
  and layer order is components < utilities < unlayered. In app code use
  `text-muted-foreground`.
- A heading tag with a sans-only class inherits the tag rule's font features: `h1`/`h2`
  rules set the *serif* `font-feature-settings`, so `<h1 class="h3">` got Geist with serif
  features (no `ss05`/`ss08` slab "I") until `.h3`–`.h6` set
  `font-feature-settings: var(--font-sans--font-feature-settings)` themselves. Any class
  that swaps a heading's font-family must also set its paired feature settings.
- Google OAuth avatars (`lh3.googleusercontent.com`) fail to load in browsers when the
  request carries the page's referrer (incl. `localhost`). Render them with
  `referrerpolicy: "no-referrer"` (see `users/connected_accounts/_connected_account`);
  don't set it app-wide — `redirect_back` depends on the Referer header.
