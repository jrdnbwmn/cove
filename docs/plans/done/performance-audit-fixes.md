> Ticket: COV-98
> Branch: chore/cov-98-performance-audit

# Plan: Performance audit fixes

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Lock down the Action Text embeds endpoint | Master | ✅   |
| 2    | 1     | 1          | Rate-limit 2FA sign-in, sudo, and API auth/sign-up | Master | ✅   |
| 3    | 1     | 1          | Cap avatar upload size | Clone  | ✅   |
| 4    | 2     | 2          | Skip the notification-count query for web requests | Master | ✅   |
| 5    | 2     | 2          | Memoize `Account#paid_premium?` and `User#family` | Master | ✅   |
| 6    | 2     | 2          | Remove repeated admin/avatar queries on family settings | Clone  | ✅   |
| 7    | 2     | 3          | Pricing: single plan query + cache plan grid for signed-out visitors | Clone  | ✅   |
| 8    | 2     | 3          | Paginate billing charge history | Clone  | ✅   |
| 9    | 2     | 3          | Charges/payment-method 404s, receipt ETags, announcements read-marking | Clone  | ✅   |
| 10   | 3     | 4          | Run Loops jobs at low priority | Master | ✅   |
| 11   | 3     | 4          | Add missing indexes; index-friendly `User.by_email` | Master | ✅   |
| 12   | 3     | 4          | Throttle API token `last_used_at` writes | Clone  | ✅   |
| 13   | 4     | 5          | Delete unused JS (motion pins, lazysrc, accounts controller) | Clone  | ✅   |
| 14   | 4     | 5          | Lazy-load Stimulus controllers | Master | ✅   |
| 15   | 4     | 5          | Load Stripe.js only on checkout | Master |      |
| 16   | 4     | 6          | Move Lexxy (rich text) JS out of the global bundle | Master | ✅   |
| 17   | 4     | 6          | Load Lexxy CSS/JS only on announcement pages | Master | ✅   |
| 18   | 4     | 6          | Homepage hero image sizing + font preloads | Clone  | ✅   |

## Prerequisites

- Design: No design doc. Source is the COV-98 performance audit run 2026-10-02
  (report: `.context/perf-audit-report.md` in the `bissau` workspace — gitignored, so
  every finding this plan acts on is restated inside its task below; you do not need
  the report). Scope decisions were made with the user in conversation and are recorded
  under **Decisions** and **Excluded findings**.
- Prototype: None (no visual changes intended anywhere in this plan).
- Feature branch exists: `chore/cov-98-performance-audit`.
- Environment: prepend mise shims before any `bin/rails`/`bin/rubocop` command:
  `export PATH="$HOME/.local/share/mise/shims:$PATH"` and confirm `ruby -v` → 4.0.5.
- Convention: this repo edits the vendored Jumpstart engine under `lib/jumpstart/`
  directly (see git history for COV-72/73/74/96/97). Editing `lib/jumpstart/...` files
  in place is expected; do not create app-level copies unless a task says so.

## Decisions (made with the user)

1. **Stimulus eager loading goes.** The `AIDEV-NOTE` in `app/javascript/controllers/index.js`
   (from COV-12) says eager loading is fine because "import maps load controllers on
   demand." That premise is wrong: `eagerLoadControllersFrom` in `stimulus-loading.js`
   calls `import(path)` for **every** controller at page load. `lazyLoadControllersFrom`
   is the on-demand version. The `ui-*` collision naming is unaffected (lazy loading
   derives identifiers from filenames the same way).
2. **The `motion` / `framer-motion` pins are deleted.** They were vendored in COV-12 because
   Rails Blocks lists motion as a toast dependency, but `ui_toast_controller.js` has never
   imported it, and nothing else does. All importmap pins default to `preload: true`, so
   ~130 KB is modulepreloaded on every page for nothing.
3. **Avatar uploads get a size cap of 5 MB** (content type is *already* validated by
   `ResizableImageValidator` — the audit's "no content-type check" claim was wrong; only
   size is missing). 5 MB is the plan's default; change the constant if the user picks another.

## Excluded findings (do NOT build these)

- User-excluded: production Active Storage on Render's ephemeral disk; 512 MB
  Puma+Solid Queue memory; Stripe calls inside `Account#destroy`'s transaction.
- `data-turbo-permanent` on the sidebar/toast host — would freeze the active-nav highlight
  and drop new flash messages.
- Fragment-caching the sidebar account menu — it contains the sign-out `button_to`, so the
  cached CSRF token would go stale.
- Public `Cache-Control` on static pages — pages carry a per-session CSRF meta tag.
- Per-path `public_file_server` headers, `touch: true` chains — need custom middleware / no cache uses them.
- Not rendering the mobile drawer on desktop; deferring drawer/tooltip setup — needs a
  viewport-aware endpoint or edits to Rails Blocks controllers for a few DOM nodes.
- Rendering the free pricing card once — changes the pricing grid layout (design call).
- Replacing Gravatar/ui-avatars fallbacks with local initials — design call.
- Trimming `tailwindcss-stimulus-components` registrations — it's one 11 KB module either
  way; dropping it would mean rewriting `toggle`.
- CSS cleanup (`braintree.css`, `docs.css`, inert dark rules in `tom_select.css`) — measure
  compiled CSS size first.
- Schema/index drops, `pay_*` `.select` tuning, `marketing_subscribed` partial index —
  need production `pg_stat_*` data.
- Narrowing `LoopsWebhookEventJob`'s `retry_on StandardError` — changes failure semantics
  documented in its `AIDEV-NOTE`.
- Dead-code removals with no runtime cost (`Current#other_accounts`,
  `User#personal_account`, `accounts/index`), maintainability-only refactors (fat
  controllers, duplicated class strings), admin-only Madmin dashboard query, and every
  "no action" row in the report.

## Tasks

---

### Phase 1 — Security-adjacent fixes

### Task 1 [Master]: Lock down the Action Text embeds endpoint

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/users/sessions_controller.rb:7` for the
project's `rate_limit` style; `lib/jumpstart/app/models/action_text/embed.rb:95-103`.

**Problem:** `POST /action_text/embeds` (`config/routes/jumpstart.rb:18-20`) is served by
`lib/jumpstart/app/controllers/action_text/embeds_controller.rb`, which has **no**
`authenticate_user!`. It calls `ActionText::Embed.from_url`, which does a blocking
`Net::HTTP.get` to an oEmbed provider with **no timeout**, then `create`s a row. Anonymous
callers can tie up all 3 Puma threads and fill `action_text_embeds`.

**In scope:**

- Add `before_action :authenticate_user!` and
  `rate_limit to: 20, within: 1.minute, only: :create, with: -> { head :too_many_requests }`
  to `ActionText::EmbedsController`.
- In `ActionText::Embed.from_oembed`, replace `Net::HTTP.get(uri)` with a call that sets
  `open_timeout: 5` and `read_timeout: 5` (e.g. `Net::HTTP.start(uri.host, uri.port,
  use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 5) { it.get(uri.request_uri).body }`),
  and rescue `Net::OpenTimeout, Net::ReadTimeout` alongside the existing `JSON::ParserError`
  (return nil → controller already responds `head :not_found`).
- `# AIDEV-NOTE:` on the controller explaining why auth + rate limit exist.

**NOT in scope:** removing the route (announcement rich text uses embeds); admin-only
restriction; changing provider list.

**Build order:**

1. **Test:** `test/integration/action_text_embeds_test.rb`:
   - "signed-out visitor cannot create embeds": `post action_text_embeds_path(id: "https://www.youtube.com/watch?v=x")` → redirected to sign-in, `ActionText::Embed.count` unchanged, and WebMock asserts no request to youtube.com.
   - "signed-in user gets an embed": sign in `users(:one)`, stub the YouTube oEmbed endpoint with WebMock returning JSON → 200 with `sgid`.
   - "a slow oEmbed provider returns not found instead of hanging": stub with `.to_timeout` → `:not_found`.
   - Rate limit: the test env cache is `:null_store`, and `rate_limit` captures the store at class load. Test it by stubbing the captured store: `ActionText::EmbedsController.cache_store.stub(:increment, 21) { post ... }` (Minitest `stub`) → `:too_many_requests`.
2. **Implement:** `lib/jumpstart/app/controllers/action_text/embeds_controller.rb`, `lib/jumpstart/app/models/action_text/embed.rb`.
3. **Verify:** `bin/rails test test/integration/action_text_embeds_test.rb`

---

### Task 2 [Master]: Rate-limit 2FA sign-in, sudo, and API auth/sign-up

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/users/sessions_controller.rb`, `app/controllers/users/registrations_controller.rb:3`.

**Problem:**
- `Users::SessionsController` declares `prepend_before_action :authenticate_with_two_factor`
  and then `rate_limit ... only: :create`. `rate_limit` is a normal `before_action`, so the
  2FA filter runs **first** and renders/redirects (halting the chain) before the limit is
  counted. Result: OTP code guesses — and password guesses for 2FA-enabled users — are
  never rate-limited.
- `POST /sudo` (`Users::SudoController#create`, a password check), `POST /api/v1/auth`
  (`Api::V1::AuthsController#create`, password + OTP check) and `POST /api/v1/users`
  (`app/controllers/api/v1/users_controller.rb#create`, sign-up) have no rate limit.

**In scope:**

- Sessions: make the rate limit run before the 2FA filter. `rate_limit` forwards `**options`
  to `before_action`, so add `prepend: true` and place the `rate_limit` line **after** the
  `prepend_before_action` line (later prepends go first). Add an `# AIDEV-NOTE:` explaining the ordering.
- Sudo: `rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_back fallback_location: root_path, alert: I18n.t("try_again_later") }`.
- API auth + API users: `rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render json: {error: I18n.t("try_again_later")}, status: :too_many_requests }`.
  For `Api::V1::AuthsController`, the `authenticate` before_action must not run before the
  limit — use `prepend: true` there too.

**NOT in scope:** rack-attack or any new gem; changing existing limits; GET endpoints.

**Build order:**

1. **Test:** Rate limits are untestable through the real store (test cache is `:null_store`, captured at class load). Stub the controller's captured store: `Users::SessionsController.cache_store.stub(:increment, 11) { ... }`.
   - `test/integration/users/sign_in_rate_limit_test.rb`: "OTP attempts are rate limited": put a 2FA user mid-sign-in (POST valid email/password for an `otp_required_for_login` user fixture, or create one), then with the stub POST an `otp_attempt` → redirected to `new_user_session_path` with `try_again_later` alert, and the user is not signed in.
   - Same pattern for sudo (`test/integration/users/sudo_test.rb` or extend the existing one if present), `test/controllers/api/v1/auths_controller_test.rb`, `test/controllers/api/v1/users_controller_test.rb` (look under `test/controllers/api/` for existing files to extend) → `429` JSON.
   - Also assert the happy path still works without the stub (one normal OTP sign-in).
2. **Implement:** `lib/jumpstart/app/controllers/users/sessions_controller.rb`, `lib/jumpstart/app/controllers/users/sudo_controller.rb`, `lib/jumpstart/app/controllers/api/v1/auths_controller.rb`, `app/controllers/api/v1/users_controller.rb`.
3. **Verify:** `bin/rails test test/integration/users test/controllers/api`

---

### Task 3 [Clone]: Cap avatar upload size

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/validators/resizable_image_validator.rb` (used by both `lib/jumpstart/app/models/user/profile.rb:10` and `lib/jumpstart/app/models/account/types.rb:21`).

**In scope:**

- Extend `ResizableImageValidator` with a size check: `MAX_SIZE = 5.megabytes`; if
  `value.blob.byte_size > MAX_SIZE`, add `:image_too_large` with `count: 5` (MB). Keep the
  existing content-type check unchanged.
- Add the `image_too_large` error message next to wherever `image_format_not_supported`
  is defined (`grep -rn image_format_not_supported config/locales lib/jumpstart/config`),
  e.g. "must be smaller than %{count} MB".

**NOT in scope:** content-type changes (already validated); direct uploads; client-side size checks; changing `accept:` attributes.

**Build order:**

1. **Test:** `test/validators/resizable_image_validator_test.rb` (create): "a user can't save an avatar larger than 5 MB" (attach `io: StringIO.new("x" * (5.megabytes + 1))`, `content_type: "image/png"` → `user.valid?` false, error on `:avatar`); "a family can't save an oversized avatar" (same with `accounts(:one)` or whichever account fixture exists); "a normal-size PNG avatar is still valid" (use a real small PNG fixture from `test/fixtures/files/` if one exists, else a tiny generated one).
2. **Implement:** `lib/jumpstart/app/validators/resizable_image_validator.rb`, the locale file.
3. **Verify:** `bin/rails test test/validators/resizable_image_validator_test.rb`, then run **review-changes-mini for Checkpoint 1 (Tasks 1–3)**. If Tasks 1–3 ran as a parallel batch, the master runs this review once the whole batch returns instead of this task. Either way it runs exactly once for the checkpoint.

---

### Phase 2 — Per-request query reductions

### Task 4 [Master]: Skip the notification-count query for web requests

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/concerns/users/navbar_notifications.rb`

**Problem:** `before_action :set_notification_counts, if: :user_signed_in?` runs a grouped
count on every signed-in request (POSTs included). `@notification_counts` is only read by
`application/_notifications.html.erb` (rendered only from `_navbar.html.erb`, which the
layout shows to **signed-out** users only — `layouts/application.html.erb:7`) and by the
Hotwire Native navbar `lib/jumpstart/app/views/application/_navbar.html+native.erb`.

**In scope:** change the condition to `if: -> { user_signed_in? && hotwire_native_app? }` and add an `# AIDEV-NOTE:` with the reasoning above.

**NOT in scope:** removing the notifications feature, partials, or controller.

**Build order:**

1. **Test:** `test/integration/navbar_notifications_test.rb`: subscribe to `sql.active_record` and collect statements mentioning `noticed_notifications`. "signed-in web page loads don't count notifications" → `get root_path` (signed in) → zero such queries. "Hotwire Native page loads still count notifications" → same request with a Hotwire Native user agent (see `test/controllers/hotwire_native_controller_test.rb` for the UA string) → at least one, and response 200.
2. **Implement:** `lib/jumpstart/app/controllers/concerns/users/navbar_notifications.rb`
3. **Verify:** `bin/rails test test/integration/navbar_notifications_test.rb test/controllers/notifications_controller_test.rb test/controllers/hotwire_native_controller_test.rb`

---

### Task 5 [Master]: Memoize `Account#paid_premium?` and `User#family`

**Skills:** write-tests
**Reference:** `app/models/pay/subscription/plan_schedule.rb` (existing memoization) and `test/models/pay/subscription/plan_schedule_test.rb:112-119` (`assert_queries_count` / `assert_no_queries` style).

**Problem:** `Account#paid_premium?` (`app/models/account.rb:62`) runs an `EXISTS` query on
every call; `premium?`, `free?`, `plan_status`, `students_allowed`,
`PlanPricingHelper#premium_student_limit`, `pricing/_plans`, `billing/_plan_state` and
`AccountDeletionHelper` all call it, so one page repeats it 3–5×. `User#family`
(`app/models/user.rb:13`) runs a join on every request (`SetCurrentRequestDetails:18`) and
again from views/helpers; `must_transfer_family_before_deletion?` calls it twice.

**In scope:**

- `Account#paid_premium?`: memoize with a `defined?` guard (it can be `false`):
  `return @paid_premium if defined?(@paid_premium)`. Override `reload` to
  `remove_instance_variable(:@paid_premium) if defined?(@paid_premium)` then `super`.
- `User#family`: `@family ||= accounts.active.first`; clear `@family` in a `reload` override.
  `create_default_account` must still work when `family` was nil (`||=` doesn't cache nil — good).
- `must_transfer_family_before_deletion?`: works unchanged once memoized; no other edits.
- `# AIDEV-NOTE:` on each: memoized per instance; callers that change subscriptions or
  membership mid-request must `reload`.

**NOT in scope:** cross-request caching (Stripe webhook timing makes invalidation risky); changing what counts as premium.

**Build order:**

1. **Test:** in `test/models/account_test.rb`: "checking premium status repeatedly only queries once" (`assert_queries_count(1) { 3.times { account.paid_premium? } }`); "reload picks up a new subscription" (call `paid_premium?` → false, create an active `Pay::Subscription` for the account's customer following existing fixtures/tests in `test/models/account_test.rb` or `test/integration/premium_access_test.rb`, `account.reload.paid_premium?` → true). In `test/models/user_test.rb`: "looking up a user's family repeatedly only queries once"; "reload clears the cached family".
2. **Implement:** `app/models/account.rb`, `app/models/user.rb`
3. **Verify:** `bin/rails test test/models test/integration/premium_access_test.rb test/integration/subscriptions_test.rb test/integration/accounts_test.rb` — then the full `bin/rails test` (memoization can surface stale-state assumptions in other tests; fix tests only by adding `reload` where a test mutates subscriptions/memberships mid-test, never by removing the memo).

---

### Task 6 [Clone]: Remove repeated admin/avatar queries on family settings

**Skills:** write-tests
**Reference:** `app/views/accounts/show.html.erb`, `app/views/billing/show.html.erb`, `lib/jumpstart/app/helpers/accounts_helper.rb:23-25`, `app/models/current.rb:25-28`

**Problem:** `account_admin?(account, user)` does `AccountUser.find_by` per call. `accounts/show`
calls it in the header, once per member row, and 3× per invitation row, plus for the invite
button. Member avatars aren't preloaded. `Current#account_user` does
`includes(:user)` on a single-row `find_by` (extra query; `Current.user` is already loaded).

**In scope:**

- `app/views/accounts/show.html.erb`: compute `<% is_admin = account_admin?(@account, current_user) %>` once at the top and use it everywhere; change `@account.account_users.includes(:user)` to `.includes(user: {avatar_attachment: :blob})`.
- `app/views/billing/show.html.erb:7`: use `Current.account_admin?` (memoized) instead of `account_admin?(current_account, current_user)`.
- `app/models/current.rb:27`: drop `.includes(:user)`.

**NOT in scope:** changing the helper itself, page layout, or authorization rules.

**Build order:**

1. **Test:** in `test/integration/accounts_test.rb` (or a new `test/integration/accounts/family_settings_queries_test.rb`): "family settings page checks admin status once" — count `sql.active_record` statements selecting from `account_users` during `get account_path(account)` with a pending invitation fixture present; assert ≤ 2 (was ~6+). Keep existing assertions that admins see Edit/Invite buttons and non-admin content is hidden (check existing tests cover it; add one if not).
2. **Implement:** the three files above.
3. **Verify:** `bin/rails test test/integration/accounts_test.rb test/integration/accounts test/integration/subscriptions_test.rb`, then run **review-changes-mini for Checkpoint 2 (Tasks 4–6)**. If Tasks 4–6 ran as a parallel batch, the master runs this review once the whole batch returns instead of this task. Either way it runs exactly once for the checkpoint.

---

### Task 7 [Clone]: Pricing — single plan query + cache plan grid for signed-out visitors

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/pricing_controller.rb`, `app/views/pricing/_plans.html.erb` (rendered by both `app/views/pricing/show.html.erb:9` and `app/views/public/index.html.erb:29`).

**In scope:**

- `PricingController#show`: `plans = Plan.visible.sorted.to_a` so `plans.any?` and `partition` share one query.
- `app/views/pricing/_plans.html.erb`: wrap the whole partial body in
  `<% cache_unless user_signed_in?, ["pricing-plans", I18n.locale, Account.default_student_limit, monthly_plans, yearly_plans] do %> … <% end %>`.
  Signed-in visitors see family-specific state (`free_family`, `subscription`), so they
  stay uncached. Plan rows are never re-priced (new row instead), and record cache keys
  include `updated_at`, so hiding/adding a plan busts the key. `# AIDEV-NOTE:` explaining the key.

**NOT in scope:** caching anything for signed-in users; HTTP caching headers; moving the free card.

**Build order:**

1. **Test:** in `test/integration/plans_test.rb` (or `public_test.rb`): "signed-out pricing page shows plans" (existing coverage — confirm); "signed-out visitors get the cached plan grid" — temporarily enable caching: `ActionController::Base.perform_caching = true` and swap `ActionController::Base.cache_store` (and `Rails.cache` if needed) to `ActiveSupport::Cache::MemoryStore.new`, restoring both in `ensure`; GET `pricing_path` twice and assert the second render doesn't query `plans` beyond the controller load (or assert a `cache_read.active_support` hit), and that a newly hidden plan disappears after `update!(hidden: true)` (key busts). "signed-in free family still sees its upgrade state" (existing test — confirm still passes).
2. **Implement:** `lib/jumpstart/app/controllers/pricing_controller.rb`, `app/views/pricing/_plans.html.erb`
3. **Verify:** `bin/rails test test/integration/plans_test.rb test/integration/public_test.rb test/integration/subscriptions_test.rb`

---

### Task 8 [Clone]: Paginate billing charge history

**Skills:** write-tests, style-ui
**Reference:** `lib/jumpstart/app/controllers/accounts_controller.rb:12` + `app/views/accounts/index.html.erb:41` (pagy + `PaginationComponent` pattern); `docs/COMPONENT_CATALOG.md` → `PaginationComponent`.

**Problem:** `app/views/billing/_charges.html.erb:3` queries `current_account.pay_charges.sorted` inside the view with no limit; history grows monthly forever.

**In scope:**

- `lib/jumpstart/app/controllers/billing_controller.rb#show`: `@pagy, @charges = pagy(current_account.pay_charges.sorted, limit: 12)` (confirm pagy 43's keyword is `limit:` by checking the gem/other call sites).
- `_charges.html.erb`: iterate `@charges`; below the table render `PaginationComponent.new(pagy: @pagy, ...)` only when `@pagy.pages > 1`. Keep the empty state.

**NOT in scope:** changing table columns/design; Turbo Frame pagination.

**Build order:**

1. **Test:** in `test/integration/subscriptions_test.rb` (or a new `test/integration/billing_charges_test.rb`): create 13 `Pay::Charge` rows for a subscribed family (follow existing Pay fixtures/tests) → billing page shows 12 rows and a page-2 link; `?page=2` shows the 13th. Also "family with no charges sees the empty state".
2. **Implement:** the controller and partial.
3. **Verify:** `bin/rails test test/integration/subscriptions_test.rb test/integration/billing_charges_test.rb`

---

### Task 9 [Clone]: Charges/payment-method 404s, receipt ETags, announcements read-marking

**Skills:** write-tests
**Reference:** sibling controllers that already use bang finders (`grep -rn "find_by_prefix_id!" lib/jumpstart/app/controllers`).

**In scope:**

- `lib/jumpstart/app/controllers/billing/charges_controller.rb:30`: `find_by_prefix_id!` (bad id → 404, not a `NoMethodError` 500). Wrap each `send_data` in `if stale?(@charge)` so repeat receipt/invoice downloads return 304 without regenerating the PDF.
- `lib/jumpstart/app/controllers/billing/subscriptions/payment_methods_controller.rb:30`: `find_by_prefix_id!`.
- `lib/jumpstart/app/controllers/announcements_controller.rb`: run `mark_as_read` only on `index` (`only: :index`) and use `current_user.update_column(:announcements_read_at, Time.current)` (no validations/callbacks for a timestamp bump on a GET).

**NOT in scope:** PDF content; Pay.sync in checkout returns; announcements UI.

**Build order:**

1. **Test:** "requesting a receipt for an unknown charge returns not found" and "unknown subscription payment-method page returns not found" (integration, signed-in admin) → `:not_found`. "repeat receipt download is served from the browser cache" → second GET with `If-None-Match: response.headers["ETag"]` → `:not_modified`. "viewing an announcement doesn't mark announcements read; the index does" → check `announcements_read_at` (fixtures in `test/fixtures/announcements.yml` if present).
2. **Implement:** the three controllers.
3. **Verify:** `bin/rails test` on the new/edited test files, then run **review-changes-mini for Checkpoint 3 (Tasks 7–9)**. If Tasks 7–9 ran as a parallel batch, the master runs this review once the whole batch returns instead of this task. Either way it runs exactly once for the checkpoint.

---

### Phase 3 — Jobs and database

### Task 10 [Master]: Run Loops jobs at low priority

**Skills:** write-tests
**Reference:** `app/jobs/*.rb`, `config/queue.yml`

**Problem:** every job (mailers, Pay webhooks, Loops sync) shares one `queues: "*"` worker
with 3 threads. `LoopsContactBackfillJob` sleeps 0.2 s per HTTP call (≥20 s per 100-user
batch). With `"*"`, Solid Queue orders ready jobs by `priority ASC` (default 0), so a
priority is enough — no queue-config change.

**In scope:** add `queue_with_priority 10` to `LoopsContactBackfillJob`, `LoopsContactSyncJob`,
`LoopsContactDeletionJob`, `LoopsEventJob`, `LoopsWebhookEventJob`, with one `# AIDEV-NOTE:`
(in `LoopsContactBackfillJob`) explaining that lower number = higher priority and
mail/Pay jobs stay at 0.

**NOT in scope:** `config/queue.yml` changes; `LoopsMailDeliveryJob` (it's mail — stays 0); retry behavior; the backfill throttle.

**Build order:**

1. **Test:** `test/jobs/loops_job_priority_test.rb`: "marketing sync jobs yield to mail and billing jobs" — for each of the five classes, `assert_equal 10, klass.new.priority` (or assert the enqueued job's `priority` via `assert_enqueued_with(job: klass, priority: 10)`).
2. **Implement:** the five job files.
3. **Verify:** `bin/rails test test/jobs`

---

### Task 11 [Master]: Add missing indexes; index-friendly `User.by_email`

**Skills:** safe-migration, write-tests
**Reference:** `db/schema.rb` (`loops_webhook_events` ~148-157, `pay_charges` ~210-226, `connected_accounts` ~126-139); `app/models/loops_webhook_event.rb:6-7`; `app/jobs/loops_webhook_event_{pruning,sweep}_job.rb`.

**In scope:**

- One migration (follow the safe-migration skill — `disable_ddl_transaction!` + `algorithm: :concurrently`):
  - `loops_webhook_events(created_at)` — pruning job.
  - `loops_webhook_events(created_at) WHERE processed_at IS NULL` (named, partial) — sweep job.
  - `pay_charges(subscription_id)`.
  - `connected_accounts(provider, uid)` (non-unique) — OAuth login lookup.
- `app/models/user.rb:11`: `scope :by_email, ->(email) { where(email: email.to_s.strip.downcase) }` — emails are already normalized (`normalizes :email` in `lib/jumpstart/app/models/user/authenticatable.rb:13`), so this hits the unique index instead of seq-scanning on `LOWER(email)`.
- **Schema drift gotcha (AGENTS.md):** `db:migrate` rewrites all four schema dumps with reordered columns and `Schema[8.1]`. After migrating, `git checkout -- db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb`; in `db/schema.rb` keep only the new `t.index` lines and the version-number bump — restore everything else (e.g. `git checkout -- db/schema.rb` then hand-add the index lines + new version).

**NOT in scope:** dropping any index/column (needs production data); unique constraints.

**Build order:**

1. **Test:** `test/models/user_test.rb`: "finds a user by email regardless of case or surrounding spaces" (`User.by_email("  #{user.email.upcase} ")` returns the user). `test/db/performance_indexes_test.rb`: "the webhook, charge, and OAuth lookups are indexed" — `assert ActiveRecord::Base.connection.index_exists?(...)` for each index.
2. **Implement:** migration, `app/models/user.rb`, `db/schema.rb`.
3. **Verify:** `bin/rails db:migrate && bin/rails test test/models/user_test.rb test/db test/integration/loops_webhook_test.rb` and `git diff --stat db/` shows only `schema.rb` + the migration.

---

### Task 12 [Clone]: Throttle API token `last_used_at` writes

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/api/base_controller.rb:32`; `test/controllers/api_base_controller_test.rb`.

**Problem:** `user_from_token` does `touch(:last_used_at)` — a DB write on every authenticated API request.

**In scope:** only touch when `last_used_at` is nil or older than 5 minutes (put the rule in an `ApiToken#touch_last_used!` method if that reads cleaner; `# AIDEV-NOTE:` with the 5-minute reason).

**NOT in scope:** token expiry, other API changes.

**Build order:**

1. **Test:** in `test/controllers/api_base_controller_test.rb`: "token use is recorded at most every five minutes" — set `last_used_at` to 1 minute ago, make an API request (e.g. `GET /api/v1/me` with the Bearer token), assert unchanged; set to 10 minutes ago, request, assert updated.
2. **Implement:** `lib/jumpstart/app/controllers/api/base_controller.rb` (+ `ApiToken` model if used).
3. **Verify:** `bin/rails test test/controllers/api_base_controller_test.rb test/controllers/api`, then run **review-changes-mini for Checkpoint 4 (Tasks 10–12)**. If Tasks 10–12 ran as a parallel batch, the master runs this review once the whole batch returns instead of this task. Either way it runs exactly once for the checkpoint.

---

### Phase 4 — Frontend payload

All Phase 4 tasks change JavaScript loading. For each: run the full `bin/rails test:system`
(sequentially, never alongside another test process) **and** do the browser checklist in the
task using a temporary local server. Check the browser console for
`Failed to register controller` / `Stripe is not defined` / module 404s.

### Task 13 [Clone]: Delete unused JS (motion pins, lazysrc, accounts controller)

**Skills:** write-tests
**Reference:** `config/importmap.rb:27-30`, `app/javascript/src/index.js`, `app/javascript/controllers/accounts_controller.js`

**In scope:**

- Remove the `motion`, `framer-motion/dom`, `motion-dom`, `motion-utils` pins and delete
  `vendor/javascript/{motion.js,framer-motion--dom.js,motion-dom.js,motion-utils.js}`.
  First re-confirm: `grep -rnE "from ['\"](motion|framer-motion|motion-dom|motion-utils)" app lib vendor/javascript` returns nothing outside those four files.
- Delete `app/javascript/src/lazysrc.js` and its import in `src/index.js` (nothing uses `data-src`; re-confirm with `grep -rn "data-src\|src:.*data" app lib/jumpstart/app`).
- Delete `app/javascript/controllers/accounts_controller.js` (account switching, which never happens; re-confirm no `data-controller` / `data-action` references `accounts` with `grep -rnE "accounts#|controller: \"accounts\"|controller=\"accounts\"" app lib/jumpstart/app`).
- Use plain edits/deletes (not `bin/importmap unpin`, which may touch other lines).

**NOT in scope:** `channels/`, `notifications_controller.js` (Hotwire Native navbar uses it), `tailwindcss-stimulus-components`.

**Build order:**

1. **Test:** `test/integration/javascript_payload_test.rb`: "pages don't ship the unused animation library" — `get root_path` → response body doesn't include `motion-dom` or `framer-motion`.
2. **Implement:** the edits/deletions above.
3. **Verify:** `bin/rails test test/integration/javascript_payload_test.rb`, full `bin/rails test`, `bin/rails test:system`. Browser: signed-in dashboard + a page with a toast (e.g. update profile) — toast appears and animates, no console errors.

---

### Task 14 [Master]: Lazy-load Stimulus controllers

**Skills:** write-tests
**Reference:** `app/javascript/controllers/index.js`; `stimulus-loading.js` in the `stimulus-rails` gem (`bundle show stimulus-rails`) for `lazyLoadControllersFrom`.

**In scope:**

- `app/javascript/controllers/index.js`: replace `eagerLoadControllersFrom` with
  `lazyLoadControllersFrom` (update the import). Replace the old `AIDEV-NOTE` with:
  eager mode `import()`s every controller at boot; lazy mode imports a controller only when
  its `data-controller` appears (also for elements added later); `ui-*` filenames still
  avoid Rails Blocks/Jumpstart identifier collisions. Keep the explicit
  `tailwindcss-stimulus-components` registrations as they are.
- Large libraries (`tom-select`, `@floating-ui/*`, `clipboard`) are pinned with the
  default `preload: true`, which still modulepreloads them everywhere. Add `preload: false` to
  `tom-select` and `clipboard` pins in `config/importmap.rb` (they're only imported by
  `select_controller.js` / `clipboard_controller.js`). Leave `@floating-ui/*` preloaded
  (used by tooltips/dropdowns in the signed-in shell on every page).

**NOT in scope:** rewriting any controller; removing pins; registration changes for tailwindcss-stimulus-components.

**Build order:**

1. **Test:** in `test/integration/javascript_payload_test.rb`: "pages don't preload the select library" — `get root_path` → body has no `modulepreload` link for `tom-select`. Existing system tests cover controller behavior.
2. **Implement:** `app/javascript/controllers/index.js`, `config/importmap.rb`.
3. **Verify:** full `bin/rails test` + `bin/rails test:system`. Browser checklist (signed in, desktop and a ≤767px viewport): sidebar collapse/expand + tooltips on the collapsed rail; account dropdown; flash toast; mobile drawer opens/closes; profile edit page's select (Tom Select) works; family page "Copy link" (clipboard); settings tabs; pricing monthly/yearly toggle (signed out); signed-out navbar `toggle` menu; no `Failed to register controller` in console.

---

### Task 15 [Master]: Load Stripe.js only on checkout

**Skills:** write-tests
**Reference:** `app/views/application/_head.html.erb:8` → `lib/jumpstart/app/views/application/_payments_dependencies.html.erb`; `app/javascript/controllers/stripe/embedded_checkout_controller.js` (only Stripe.js user, via `app/views/checkouts/forms/_stripe.html.erb`).

**Problem:** `<script src="https://js.stripe.com/v3/">` is a render-blocking script in `<head>` on every page, including the marketing homepage.

**In scope:**

- In `lib/jumpstart/app/views/application/_payments_dependencies.html.erb`, remove the Stripe line (leave the Braintree/PayPal branches untouched — they're off in config).
- In `embedded_checkout_controller.js`, load Stripe.js on demand before calling `Stripe(...)`:
  a small `loadStripe()` helper that returns a cached Promise, reuses an existing
  `script[src="https://js.stripe.com/v3/"]` if present, otherwise appends one to `<head>`
  and resolves on `load` (reject on `error`); `connect()` awaits it. Guard against
  `disconnect()` happening before the promise resolves.
- `// AIDEV-NOTE:` explaining why Stripe.js is loaded here instead of in `<head>`.

**NOT in scope:** checkout flow logic, Pay config, CSP (not enabled), other processors.

**Build order:**

1. **Test:** `test/integration/javascript_payload_test.rb`: "marketing pages don't load Stripe" — `get root_path` and `get pricing_path` → body excludes `js.stripe.com`. Keep `test/integration/checkouts_test.rb` passing.
2. **Implement:** the partial and the controller.
3. **Verify:** `bin/rails test test/integration/javascript_payload_test.rb test/integration/checkouts_test.rb` + `bin/rails test:system`. Browser: as a Free family admin, start a checkout from pricing **via a Turbo link** (not a hard reload) — the embedded Stripe checkout mounts; hard reload of the checkout page also mounts. If local Stripe test keys aren't configured, say so in the report and flag this for staging verification — don't mark the task Done on unverified checkout.

   Then run **review-changes-mini for Checkpoint 5 (Tasks 13–15)**. If Tasks 13–15 ran as a parallel batch, the master runs this review once the whole batch returns instead of this task. Either way it runs exactly once for the checkpoint.

   **Status (2026-10-02):** code + focused tests done. Browser checkout check NOT done locally (no eligible Free family admin session); deferred to **staging verification** — Turbo-link checkout from pricing and hard reload must both mount Stripe. Left unmarked per the rule above.

---

### Task 16 [Master]: Move Lexxy (rich text) JS out of the global bundle

**Skills:** write-tests
**Reference:** `app/javascript/application.js:3`, `app/javascript/src/index.js`, `app/javascript/src/lexxy_extensions.js`, `config/importmap.rb:12,15`.

**Context:** the app's only rich-text content is `Announcement#description`
(`lib/jumpstart/app/models/announcement.rb:8`). The admin editor lives in Madmin, which
loads its **own** Lexxy (`madmin` gem `config/importmap.rb` + `engine.rb`), so the app
bundle's Lexxy is only needed to style/highlight announcement content. Today Lexxy JS,
`@rails/actiontext`, and `Lexxy.highlightCode()` on every `turbo:load` ship on every page.

**In scope:**

- First `grep -rnE "lexxy|@rails/actiontext" app lib/jumpstart/app` — if anything other than the files listed here (plus `_head.html.erb`/`application.css`, handled in Task 17) imports them, STOP and report.
- `git mv app/javascript/src/lexxy_extensions.js app/javascript/rich_text.js` (out of the preloaded `src/` directory); add `import "@rails/actiontext"` at its top and call `Lexxy.highlightCode()` once immediately (the first Turbo visit may already have fired `turbo:load`) in addition to the existing listeners.
- `config/importmap.rb`: `pin "rich_text", preload: false`; add `preload: false` to the `lexxy` and `@rails/actiontext` pins.
- Remove `import "@rails/actiontext"` from `application.js` and `import "src/lexxy_extensions"` from `src/index.js`.

**NOT in scope:** loading `rich_text` on announcement pages and the Lexxy stylesheet (Task 17); Madmin; Lexxy version.

**Build order:**

1. **Test:** `test/integration/javascript_payload_test.rb`: "regular pages don't preload the rich-text editor" — `get root_path` → no `modulepreload` link for `lexxy` or `actiontext`.
2. **Implement:** the four files above.
3. **Verify:** `bin/rails test test/integration/javascript_payload_test.rb` + full `bin/rails test`. (Browser check happens in Task 17, which wires the module back onto announcement pages — do Tasks 16 and 17 back to back.)

---

### Task 17 [Master]: Load Lexxy CSS/JS only on announcement pages

**Skills:** write-tests
**Reference:** `app/views/application/_head.html.erb:7`, `lib/jumpstart/app/views/announcements/{index,show}.html.erb`, `app/assets/tailwind/application.css:189`.

**In scope:**

- `_head.html.erb`: `stylesheet_link_tag "tailwind", ...` (drop `"lexxy"`).
- Announcement `index` and `show` views: `content_for :head` with `stylesheet_link_tag "lexxy"` (no `data-turbo-track`, so navigating away doesn't force a full reload) and `javascript_import_module_tag "rich_text"`.
- Remove `@import "./components/lexxy.css";` from `app/assets/tailwind/application.css` and delete the 0-byte `app/assets/tailwind/components/lexxy.css`.

**NOT in scope:** Madmin; announcement layout/design.

**Build order:**

1. **Test:** `test/integration/javascript_payload_test.rb`: "regular pages don't load rich-text styles" (`get root_path` → no `lexxy` stylesheet link); "announcement pages load rich-text styles and script" (`get announcement_path(...)` → includes the `lexxy` stylesheet and the `rich_text` module tag). Use or create an announcement fixture (`test/fixtures/announcements.yml` + its `action_text_rich_texts` description fixture).
2. **Implement:** `_head.html.erb`, the two announcement views, `application.css` (+ delete the empty file).
3. **Verify:** focused tests + full `bin/rails test` + `bin/rails test:system`. Browser: open an announcement with formatted content (and a code block if possible) via a Turbo link and via hard reload — styled and highlighted, no console errors; then Madmin → Announcements → edit — editor still works.

---

### Task 18 [Clone]: Homepage hero image sizing + font preloads

**Skills:** write-tests
**Reference:** `app/views/public/index.html.erb:9`, `app/views/application/_head.html.erb`, `app/assets/tailwind/application.css:11-49` (`@font-face`).

**In scope:**

- Hero `image_tag "homepage-lake-sunset.webp"`: add `width: 1448, height: 1086, fetchpriority: "high"` (intrinsic size; Tailwind preflight sets `img { height: auto }` and the existing `w-full` class keeps the rendered size — no visual change).
- `_head.html.erb`: `preload_link_tag "Geist-Regular.woff2", as: "font", type: "font/woff2", crossorigin: "anonymous"` and the same for `"FabricSerifWeb-Regular.woff2"` (the body font and the h1/h2 font, both used above the fold on every page). Confirm the rendered `href` is the digested Propshaft path matching the `@font-face` URL in compiled CSS (otherwise the browser downloads twice).

**NOT in scope:** responsive `srcset`/new image variants; preloading the other Geist weights; font changes.

**Build order:**

1. **Test:** `test/integration/public_test.rb`: "homepage hero image reserves its space" (`assert_select "img[src*='homepage-lake-sunset'][width='1448'][height='1086']"`); `test/integration/layouts_test.rb`: "pages preload the main fonts" (`assert_select "link[rel=preload][as=font][href*='Geist-Regular']"` and FabricSerifWeb).
2. **Implement:** the two views.
3. **Verify:** `bin/rails test test/integration/public_test.rb test/integration/layouts_test.rb`; browser: homepage looks identical, DevTools Network shows each font fetched once. Then run **review-changes-mini for Checkpoint 6 (Tasks 16–18)**. If Tasks 16–18 ran as a parallel batch, the master runs this review once the whole batch returns instead of this task. Either way it runs exactly once for the checkpoint.

## Task Dependencies

- Phases are independently deployable; run them in order 1 → 4.
- Checkpoint 1: Tasks 1, 2, 3 are independent (parallel OK).
- Checkpoint 2: Tasks 4, 5, 6 are independent. Run Task 5 before the **full** suite in Task 6 so memoization fallout is already handled.
- Checkpoint 3: Tasks 7, 8, 9 are independent (7 benefits from 5's memoization but doesn't require it).
- Checkpoint 4: Tasks 10, 11, 12 are independent.
- Checkpoint 5: Task 13 before Task 14 (both edit `config/importmap.rb`). Task 15 is independent.
- Checkpoint 6: strictly sequential 16 → 17 → 18. Task 16 needs Task 13 done (both edit `config/importmap.rb` / `src/index.js`); Task 17 wires up what 16 moved; Task 18 and Task 17 both edit `_head.html.erb`.
- Run Rails test processes sequentially — never system tests concurrently with another test process in this worktree.
