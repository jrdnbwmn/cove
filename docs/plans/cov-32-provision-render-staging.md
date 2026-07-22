> Ticket: COV-32
> Branch: feature/cov-32-provision-render-staging-dns-first-green-deploy

# Plan: Provision Render staging, DNS, and first green deploy

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Set staging Active Job adapter to `:inline` + test | Master | |
| 2 | 2 | 2 | Confirm preconditions (render.yaml on main, credentials, key) | Master | |
| 3 | 2 | 2 | Create Render blueprint, load `RAILS_MASTER_KEY`, first deploy | Master | |
| 4 | 3 | 3 | Add `staging` CNAME + managed TLS (AC #1) | Master | |
| 5 | 3 | 3 | Add Google OAuth staging redirect URI | Master | |
| 6 | 3 | 3 | Add Stripe test-mode webhook + signing secret | Master | |
| 7 | 4 | 4 | Verify auto-deploy from `main` (AC #4) | Master | |
| 8 | 4 | 4 | By-hand skeleton walk (AC #2, #3, #5) | Master | |
| 9 | 4 | 4 | Day-25 Postgres-recreate reminder (AC #6) | Master | |

Every task is Master: the code task is the pattern-setting first task touching
shared environment config, and the ops tasks are sequential, browser-driven, and
require judgment plus user hand-offs (logins/2FA/secrets) — nothing parallelizes,
so there is no clone work to fan out.

## Prerequisites

- Design: `docs/designs/cov-32-provision-render-staging.md`
- Prototype: None
- Feature branch exists: `feature/cov-32-provision-render-staging-dns-first-green-deploy` (current)
- Chrome browser tools available for Render / Google Cloud Console / Stripe / Namecheap
- User available for logins, 2FA, and typing secrets they don't want shared

---

## Tasks

### Task 1 [Master]: Set staging Active Job adapter to `:inline` + test

**Skills:** write-tests
**Reference:** `config/environments/staging.rb:53-55` (current adapter wiring); `test/config/render_blueprint_test.rb` (precedent for a standalone file-parsing config test in `test/config/`)

**In scope:**

- In `config/environments/staging.rb`, replace `config.active_job.queue_adapter = Jumpstart.config.queue_adapter` (line 54) with `config.active_job.queue_adapter = :inline`. Leave `config.solid_queue.connects_to = {database: {writing: :queue}}` (line 55) as-is — `db:prepare` still provisions the `_queue` DB; nothing runs a worker.
- Do **not** add `SOLID_QUEUE_IN_PUMA` anywhere.
- Add a `# AIDEV-NOTE:` above the line explaining inline runs jobs synchronously in the web request to avoid the 512MB free-tier memory pressure that `SOLID_QUEUE_IN_PUMA` caused (commit #29).
- Add a test in `test/config/` asserting the staging environment resolves the inline Active Job adapter and does not reference `Jumpstart.config.queue_adapter` / `SOLID_QUEUE_IN_PUMA` — following the standalone-file-assertion style already used by `render_blueprint_test.rb`.

**NOT in scope:**

- Any change to `production.rb` / `development.rb` / `test.rb` adapters.
- Adding gems, changing `render.yaml`, or touching Solid Queue schema/config.

**Build order:**

1. **Test:** Add `test/config/staging_inline_adapter_test.rb`. Assert the staging env config sets Active Job to `:inline` and refute presence of `Jumpstart.config.queue_adapter` and `SOLID_QUEUE_IN_PUMA` in `config/environments/staging.rb`. Run it first and watch it fail.
2. **Implement:** Edit `config/environments/staging.rb` line 54 to `:inline` + AIDEV-NOTE.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/config/staging_inline_adapter_test.rb` (confirm `ruby -v` reports 4.0.5 first).
4. **Review:** Run review-changes-mini over Task 1 (Checkpoint 1). This is the only code checkpoint; ops checkpoints below are verified by their acceptance criteria instead.

---

### Task 2 [Master]: Confirm preconditions (runbook step 0)

**In scope:**

- Confirm `render.yaml` is on `main` and only `cove-staging` + `cove-staging-db` are active (production block commented out); region is `oregon` on both.
- Confirm `config/credentials/staging.key` exists locally (contents = the `RAILS_MASTER_KEY` value to load later).
- Inspect `staging.yml.enc` via `bin/rails credentials:edit --environment staging` (or `credentials:show`) to check whether Stripe **test** keys, Google `omniauth.google_oauth2` (`public_key`=client ID, `private_key`=secret), and Stripe webhook signing secret slots are present or empty. Note which are empty — they get filled in Tasks 5/6.

**NOT in scope:**

- Editing any secret yet, provisioning anything on Render, or touching production config.

**Build order:**

1. Verify files/branch state via git + `Read`/`Bash`.
2. Report a checklist of what's present vs. what must be filled during Tasks 5/6. If a precondition fails (e.g. `staging.key` missing), stop and surface it to the user before proceeding to Task 3.

---

### Task 3 [Master]: Create Render blueprint, load master key, first deploy (runbook steps 1–2)

**In scope:**

- In Render (Chrome tools; user handles login/2FA): New → Blueprint → repo/branch `main` → apply the proposed `cove-staging` (web, free, Oregon) + `cove-staging-db` (free Postgres, Oregon).
- On the `cove-staging` service → Environment: set `RAILS_MASTER_KEY` = contents of `config/credentials/staging.key` (**user types/pastes this** — do not echo it).
- Trigger a deploy and watch logs. Confirm `db:prepare` at container start creates the primary DB plus the derived `_cache` / `_queue` / `_cable` databases (single free Postgres, path-swapped URLs per `database.yml`). If `db:prepare` cannot create those, debug that first before moving on.

**NOT in scope:**

- Custom domain / TLS (Task 4), OAuth (Task 5), Stripe (Task 6). Production service/DB.

**Build order:**

1. Drive the blueprint apply in-browser; pause for user login/2FA.
2. Load `RAILS_MASTER_KEY` (user-entered), redeploy.
3. Verify a green deploy and the four databases in logs. Report deploy status.

---

### Task 4 [Master]: DNS + managed TLS (runbook step 3, AC #1)

**In scope:**

- `cove-staging` → Settings → Custom Domains → add `staging.covehomeschool.com`; capture Render's CNAME target (`<service>.onrender.com`).
- Namecheap → `covehomeschool.com` → Advanced DNS → add CNAME: host `staging` → value = Render's target (user handles Namecheap login).
- Wait for Render to verify + auto-issue TLS.
- **Verify (AC #1):** `curl -I https://staging.covehomeschool.com/up` → `200` with a valid cert.

**NOT in scope:**

- Cloudflare / CDN / WAF, nameserver moves, or any apex/`www` record.

**Build order:**

1. Add custom domain on Render, copy target.
2. Add CNAME at Namecheap (user login).
3. Poll until TLS issues; run the `curl -I .../up` check and report the result.

---

### Task 5 [Master]: Google OAuth staging redirect URI (runbook step 4)

**In scope:**

- Google Cloud Console → APIs & Services → Credentials (user login). Find the client whose id/secret are in `staging.yml.enc` (or create a dedicated staging client if none).
- Add Authorized redirect URI `https://staging.covehomeschool.com/users/auth/google_oauth2/callback` and JS origin `https://staging.covehomeschool.com` if required.
- Ensure that client's id/secret live in `staging.yml.enc` under `omniauth.google_oauth2` (`public_key`=client ID, `private_key`=secret). If edited, redeploy so the change is live.

**NOT in scope:**

- Production OAuth client, changing scopes, or any non-Google provider.

**Build order:**

1. Add redirect URI / JS origin in console (user login).
2. If credentials were empty (from Task 2), have user fill them via `credentials:edit --environment staging`; commit the encrypted change and redeploy.
3. Confirm the client is wired (full end-to-end sign-in is verified in Task 8).

---

### Task 6 [Master]: Stripe test-mode webhook + signing secret (runbook step 5)

**In scope:**

- Confirm the Pay engine's live mounted webhook path before saving (expected `https://staging.covehomeschool.com/pay/webhooks/stripe` — verify against the running app since routes aren't in `config/routes/`).
- Stripe dashboard in **Test mode** → Developers → Webhooks → Add endpoint at that URL; subscribe to the checkout/subscription/invoice/customer events Pay expects (user login).
- Copy the endpoint's signing secret → put it in `staging.yml.enc` under the Stripe config the Pay gem reads (user-entered); commit encrypted change and redeploy so the secret is live.

**NOT in scope:**

- Live-mode Stripe, product/price setup, or non-Stripe processors.

**Build order:**

1. Verify the mounted webhook path on the deployed app.
2. Create the test-mode endpoint in Stripe (user login), subscribe events.
3. Store signing secret in `staging.yml.enc` (user-entered), redeploy. Full webhook processing is verified in Task 8.

---

### Task 7 [Master]: Verify auto-deploy from `main` (runbook step 6, AC #4)

**In scope:**

- Confirm the blueprint's `autoDeploy: true` on `branch: main`.
- Merge a trivial visible change to `main` (or confirm the just-merged COV-32 change) and confirm it appears on staging without a manual deploy.

**NOT in scope:**

- Changing deploy triggers, adding preview environments, or CI changes.

**Build order:**

1. Confirm auto-deploy setting.
2. Trigger via a merge to `main`; watch Render pick it up and confirm the change is live. Report.

---

### Task 8 [Master]: By-hand skeleton walk (runbook step 7, AC #2, #3, #5)

**In scope:**

- `/up` → 200 (re-confirm AC #1).
- Google sign-in end-to-end → new user + personal account created (AC #2).
- Stripe **test** checkout → success; webhook received in Stripe dashboard **and** subscription state syncs on staging (AC #3).
- Trigger a job path (e.g. an email via `deliver_later`) and confirm it ran inline (AC #5) — expect the request to block until the job completes.

**NOT in scope:**

- Load testing, chasing free-tier cold-start (~1 min after idle) or no-backup behavior — those are expected, not bugs.

**Build order:**

1. Walk each flow in-browser (user handles Google/Stripe logins as needed).
2. Confirm each acceptance criterion and report pass/fail per AC.

---

### Task 9 [Master]: Day-25 Postgres-recreate reminder (runbook step 8, AC #6)

**In scope:**

- **User** creates a calendar reminder ~day 25 from DB creation: "Recreate Cove free Render Postgres before it's deleted at day 30." Claude computes the concrete date from the Task 3 DB-creation date and hands the user the exact reminder text/date.

**NOT in scope:**

- Automating the recreation or upgrading to paid Postgres.

**Build order:**

1. Compute day-25 date from DB creation.
2. Ask the user to set the reminder; confirm done.

---

## Task Dependencies

- Task 1 (code) is independent and can ship first via its own PR/merge; it also doubles as the visible change Task 7 can use to prove auto-deploy.
- Ops tasks are strictly sequential: **2 → 3 → 4 → 5 → 6 → 7 → 8 → 9**. Task 3 needs the master key (Task 2 confirms it exists); Tasks 4–6 need a running service (Task 3); Task 8's sign-in/billing checks need Tasks 5 and 6 live; Task 9 needs the DB-creation date from Task 3.
- No parallelism — every step gates the next, which is why all tasks are Master.
