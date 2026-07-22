> Ticket: COV-31
> Branch: feature/cov-31-split-credentials-per-env
> Plan created: docs/plans/cov-31-split-credentials-per-env.md

# Feature: Split Rails credentials per environment

## Problem
The app has one shared `config/credentials.yml.enc` + `config/master.key`; only
`test.yml.enc` is environment-scoped. A deployed staging environment would read
the same credentials as production — live Stripe keys and a single Google OAuth
client shared across environments. `config/jumpstart.rb` enables
`omniauth_providers: ["google-oauth2"]` and `payment_processors: ["stripe"]`, so
both are real concerns, not hypothetical.

## Approach
Introduce per-environment encrypted credential files so staging carries Stripe
**test** keys and a staging-specific Google OAuth client, and production gets its
own file (created now, populated at cutover). Fix `config/environments/staging.rb`
so generated URLs resolve to the staging host instead of the production domain.
The secret values and the Render key upload are a **manual handoff** the author
completes — a clone can create the files but cannot invent secrets or push the
key to Render.

## Acceptance Criteria
- [ ] `bin/rails credentials:edit --environment staging` opens and saves
- [ ] Same for `--environment production`
- [ ] Staging credentials contain no live Stripe keys
- [ ] No `.key` file appears as stageable in `git status`
- [ ] `staging.rb` URL options resolve to `staging.covehomeschool.com`
- [ ] Handoff note lists required Render env vars by name (no secret values)

## Prototype
None.

## Data Model
No models or migrations. This is configuration only.

Credential key structure each env file must eventually hold (auto-generated
`secret_key_base` + `active_record_encryption` come from the template on first
`credentials:edit`; the rest are filled in by the author):

- `stripe:` → `public_key`, `private_key`, `signing_secret`
  (read by the Pay gem via `Rails.application.credentials.stripe`)
- `omniauth: google_oauth2:` → `public_key` (client ID), `private_key` (secret)
  (read by `Jumpstart::Omniauth.credentials_for`)

## Screens / Flows
No UI. The observable behavior change is that mailer/controller-generated
absolute URLs in the staging environment use `staging.covehomeschool.com`.

## Work split

### Claude (execute-plan)
1. Scaffold `config/credentials/staging.yml.enc` + `staging.key` via a no-op
   editor so the file is created from the template and saved unedited:
   `EDITOR=true bin/rails credentials:edit --environment staging`.
   The file gets a fresh `secret_key_base` + `active_record_encryption` keys and
   the full template with **empty** Stripe/Google placeholders — so "no live
   Stripe keys" holds by construction.
2. Same for `--environment production`.
3. Edit `config/environments/staging.rb`:
   - Replace `action_mailer.default_url_options = {host: Jumpstart.config.domain}`
     (which resolves to the production `covehomeschool.com`) with
     `{host: "staging.covehomeschool.com"}`.
   - Add `config.action_controller.default_url_options = {host: "staging.covehomeschool.com"}`.
   - Leave `asset_host` unset, with a one-line comment noting assets are served
     same-origin (no separate CDN/asset host for staging).
4. Verify `.gitignore` already covers `/config/master.key` and
   `/config/credentials/*.key` (lines 47–48) — confirm no `.key` is stageable in
   `git status`. No edit expected.
5. Write the handoff note at `docs/designs/cov-31-credentials-handoff.md`.
6. Verify by booting the staging env with the generated key and asserting the
   host resolves:
   `RAILS_MASTER_KEY=$(cat config/credentials/staging.key) RAILS_ENV=staging bin/rails runner "puts Rails.application.config.action_mailer.default_url_options[:host]"`
   → expects `staging.covehomeschool.com`.

### Author (manual handoff — a clone cannot complete this)
1. Create a **staging-specific Google OAuth client** in Google Cloud Console
   (none exists yet). Redirect URI:
   `https://staging.covehomeschool.com/users/auth/google_oauth2/callback`.
2. `bin/rails credentials:edit --environment staging` → paste Stripe **test**
   keys and the staging Google client ID/secret.
3. Copy `config/credentials/staging.key` into Render → `cove-staging` service →
   env var `RAILS_MASTER_KEY`.
4. Production stays dormant: `production.yml.enc` is created empty now; live keys,
   a prod Google client, and the prod `RAILS_MASTER_KEY` all wait for the cutover
   ticket.

## Handoff note contents (env vars by name, no values)
`RAILS_MASTER_KEY` is the **only** secret set manually on Render — it equals the
contents of `config/credentials/staging.key`. Everything else in `render.yaml` is
already wired: `RAILS_ENV` / `RACK_ENV` / `SOLID_QUEUE_IN_PUMA` are literals, and
the DB URLs come from `fromDatabase`. Stripe/Google secrets live *inside
credentials*, so they need no additional Render env vars.

## Scope
**In:** two env credential files + keys, `staging.rb` URL fixes, `.gitignore`
verification, handoff note.

**Deferred:**
- Production go-live (cutover ticket).
- Staging **email delivery** — `email_provider` is `""` in `config/jumpstart.rb`,
  so the host fix corrects link *hosts* but staging won't actually send mail until
  a provider is configured. Separate concern; flagged so it isn't a surprise.
- Migrating development off the shared `config/credentials.yml.enc` — untouched.

## Open Questions
None blocking. Notes:
- **No Minitest unit test.** There is no app-code behavior to unit-test; env
  config is verified by booting the staging env (step 6). This is the pragmatic
  exception to the test-first rule for pure config.
- Fresh `secret_key_base` / AR-encryption keys for production are safe because
  production has no encrypted data yet (pre-cutover).

## More Info
- Staging deployment blueprint (`render.yaml`, from COV-30) already declares
  `RAILS_MASTER_KEY` with `sync: false` for the `cove-staging` service, so the
  handoff target already exists.
- Rails resolves `config/credentials/<env>.yml.enc` when present for that env,
  falling back to the shared `config/credentials.yml.enc`. Development has no
  env file, so it keeps using the shared file.
