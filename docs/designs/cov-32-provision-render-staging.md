> Ticket: COV-32
> Branch: feature/cov-32-provision-render-staging-dns-first-green-deploy
> Plan created: docs/plans/cov-32-provision-render-staging.md

# Feature: Provision Render staging, DNS, and first green deploy

## Problem
The staging blueprint (`render.yaml`) and per-environment credentials
(COV-30/COV-31) are merged, but nothing is running. Cove needs a live
`staging.covehomeschool.com` with valid TLS, working Google sign-in and Stripe
test billing, and auto-deploy from `main`, so changes can be verified in a
production-like environment before the paid production cutover.

## Approach
An ops/runbook ticket — the code is already written. Execute the manual
provisioning steps in order (Render blueprint → secrets → DNS/TLS → OAuth →
Stripe webhook → skeleton walk), driven in-browser where possible. One small
code change ships alongside: staging's Active Job adapter is set to `:inline`
(see Code Change below).

**Who does what:** Claude drives Render, Google Cloud Console, the Stripe
test-mode dashboard, and the Namecheap CNAME via the Chrome tools. The user
steps in only for logins/2FA, typing secrets they don't want shared, and the
day-30 calendar reminder.

## Code Change (the only non-ops part)
Set the Active Job adapter to `:inline` for staging in
`config/environments/staging.rb`. This makes background jobs run
**synchronously inside the web request** — no Solid Queue supervisor,
dispatcher, or worker, so none of the 512MB memory pressure that
`SOLID_QUEUE_IN_PUMA` caused and that broke Render earlier (commit #29).

- Do **not** set `SOLID_QUEUE_IN_PUMA` — that path is rejected.
- Consequence: a request that fires a job (e.g. sending an email) blocks until
  the job finishes. On single-user free-tier staging this is fine, and it keeps
  emails / Stripe webhook processing / notifications actually working during the
  skeleton walk.
- Needs a test asserting staging resolves the inline adapter (TDD per project
  rules). Keep production/other envs untouched.

## Acceptance Criteria
1. `https://staging.covehomeschool.com/up` returns 200 with valid managed TLS.
2. Google sign-in completes end to end and creates a user + personal account.
3. A Stripe test-mode checkout succeeds and the webhook is received **and
   processed** (subscription state syncs).
4. Merging to `main` auto-deploys and the change appears on staging.
5. **(Reframed)** A background job executes within the web process via the
   inline adapter — replaces the original "Solid Queue processes a job inside
   the web process," which is impossible on free tier (see COV-31 handoff and
   commit #29). Verifiable by triggering any `deliver_later`/job path (e.g. an
   email) and confirming it ran.
6. A day-25 calendar reminder exists to recreate the free Postgres before it is
   deleted at day 30.

## Expected free-tier behavior (not bugs — do not chase)
- First request after ~15 min idle takes ~1 minute (cold start).
- Free Postgres has no backups and is deleted at day 30.

## Prototype
None.

## Data Model
No changes.

## Screens / Flows — the runbook (execute top to bottom)

### 0. Preconditions to confirm
- `render.yaml` is on `main` (it is). Render account + workspace exist and the
  GitHub repo is connected/authorized.
- `config/credentials/staging.key` exists locally (its contents = the
  `RAILS_MASTER_KEY` value). Staging Stripe **test** keys + Google client
  id/secret are populated in `staging.yml.enc`
  (`bin/rails credentials:edit --environment staging`) — if empty, fill during
  step 4/5.

### 1. Create the Render blueprint
- New → Blueprint → pick the repo/branch `main` → Render reads `render.yaml`
  and proposes `cove-staging` (web, free, Oregon) + `cove-staging-db` (free
  Postgres, Oregon).
- Apply. This provisions the service and DB. `RAILS_MASTER_KEY` is `sync:false`
  so the first deploy will fail/wait until step 2.

### 2. Load secrets on Render
- `cove-staging` service → Environment → set `RAILS_MASTER_KEY` = contents of
  `config/credentials/staging.key` (**user types/pastes this**).
- Everything else (`RAILS_ENV=staging`, `RACK_ENV=staging`,
  `WEB_CONCURRENCY=0`, `DATABASE_URL`) is already wired by the blueprint.
- Trigger a deploy; watch logs. `db:prepare` runs at container start and must
  create the primary DB plus the derived `_cache` / `_queue` / `_cable`
  databases (single free Postgres, path-swapped URLs — see `database.yml`
  `staging_role_database_url`). If `db:prepare` can't create those, that's the
  first thing to debug here.

### 3. DNS + managed TLS
- `cove-staging` → Settings → Custom Domains → add
  `staging.covehomeschool.com`. Render shows a CNAME target
  (`<service>.onrender.com`).
- Namecheap → domain `covehomeschool.com` → Advanced DNS → add CNAME:
  host `staging` → value = Render's target. (Subdomain CNAME is fine; no
  Cloudflare, no nameserver move.)
- Wait for Render to verify and auto-issue TLS. **AC #1:** `curl -I
  https://staging.covehomeschool.com/up` → `200` with a valid cert.

### 4. Google OAuth (staging redirect URI)
- Google Cloud Console → APIs & Services → Credentials. Find the client whose
  id/secret are in `staging.yml.enc` (or create a dedicated staging client if
  none). Add Authorized redirect URI:
  `https://staging.covehomeschool.com/users/auth/google_oauth2/callback`
  (and the JS origin `https://staging.covehomeschool.com` if required).
- Ensure that client's id/secret are in `staging.yml.enc` under
  `omniauth.google_oauth2` (`public_key` = client ID, `private_key` = secret).
  If edited, redeploy.

### 5. Stripe test-mode webhook
- Stripe dashboard in **Test mode** → Developers → Webhooks → Add endpoint:
  URL `https://staging.covehomeschool.com/pay/webhooks/stripe` (confirm the
  Pay engine's mounted path live before saving). Subscribe to the events Pay
  expects (checkout/subscription/invoice/customer events).
- Copy the endpoint's **signing secret** → put it in `staging.yml.enc` under
  the Stripe config the Pay gem reads → redeploy so the new secret is live.

### 6. Auto-deploy check (AC #4)
- Blueprint sets `autoDeploy: true` on `branch: main`. Merge a trivial visible
  change to `main` (or confirm the just-merged COV-32 change) and confirm it
  appears on staging.

### 7. Skeleton walk by hand
- `/up` → 200 (AC #1).
- Google sign-in → new user + personal account created (AC #2).
- Stripe **test** checkout → success; webhook received in Stripe dashboard and
  subscription state syncs on staging (AC #3).
- Trigger a job path (e.g. an email via `deliver_later`) and confirm it ran
  inline (AC #5).

### 8. Day-30 reminder (AC #6)
- **User** creates a calendar reminder for ~day 25 from DB creation:
  "Recreate Cove free Render Postgres before it's deleted at day 30."

## Scope
**In:** Render blueprint apply, secrets load, `staging` CNAME at Namecheap +
managed TLS, Google staging redirect URI, Stripe test webhook, auto-deploy
verification, by-hand skeleton walk, inline-adapter code change + test, day-25
calendar reminder.

**Deferred:** Production service/DB (dormant in `render.yaml` until the cutover
ticket), Cloudflare/CDN/WAF, any paid-tier upgrade, real background-worker
infrastructure, live Stripe/Google production credentials.

## Open Questions
None.

## More Info
- Predecessors (both merged, in `docs/designs/done/`):
  `render-staging-blueprint.md`, `cov-31-split-credentials-per-env.md`.
- COV-31 handoff (`docs/designs/cov-31-credentials-handoff.md`) documents the
  original manual steps this runbook supersedes.
- `render.yaml`: production block is commented out; only `cove-staging` +
  `cove-staging-db` are active. Region must stay `oregon` across service and DB
  for internal keys.
