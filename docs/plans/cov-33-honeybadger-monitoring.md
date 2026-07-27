> Ticket: COV-33
> Branch: feature/cov-33-add-honeybadger-error-tracking

# Plan: Honeybadger error tracking and uptime monitoring

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Write `test/config/honeybadger_config_test.rb` (red) | Master | ✅ |
| 2 | 1 | 1 | Add `config/honeybadger.yml`, flip integrations flag, bundle | Master | ✅ |
| 3 | 1 | 1 | `AIDEV-NOTE` in filter_parameter_logging.rb | Master | ✅ |
| 4 | 2 | 2 | Honeybadger account + project + API key → `staging.yml.enc` | Master | |
| 5 | 2 | 2 | Temp boom route, repoint Render to branch, verify AC #1/#2 | Master | |
| 6 | 2 | 2 | Uptime check on `/up` with verified email alerting (AC #3) | Master | |
| 7 | 3 | 3 | Repoint Render to main, delete boom route, final gates | Master | |

All tasks are Master. This ticket is config + ops: every code task touches shared
infra (`config/jumpstart.rb`, `Gemfile.lock`, `config/routes.rb`) or requires
browser-driven judgment with the user in the loop. Nothing here is large enough
or isolated enough to be worth a clone.

## Prerequisites

- Design: `docs/designs/cov-33-honeybadger-monitoring.md`
- Prototype: None
- Feature branch exists: `feature/cov-33-add-honeybadger-error-tracking`
- `RAILS_MASTER_KEY` already set on `cove-staging` (from COV-32)
- **Every `bin/rails` / `bin/rubocop` command in this plan must be preceded by**
  `export PATH="$HOME/.local/share/mise/shims:$PATH"` — confirm `ruby -v` reports
  4.0.5 before trusting any output.

## Tasks

---

### Task 1 [Master]: Write the Honeybadger config test (red)

**Skills:** write-tests
**Reference:** Read `test/config/staging_inline_adapter_test.rb` and
`test/config/render_blueprint_test.rb` — plain `Minitest::Test`, no Rails boot,
`File.expand_path("../../<path>", __dir__)`, assert on file contents.

**In scope:**

- Create `test/config/honeybadger_config_test.rb` with exactly the three tests
  from the design doc:
  1. `test_error_reports_never_include_session_data` — `YAML.load_file` on
     `config/honeybadger.yml`, assert
     `config.fetch("request").fetch("disable_session") == true`
  2. `test_api_key_is_read_from_credentials_and_never_committed` — assert
     `config.fetch("api_key")` matches `/credentials\.dig\(:honeybadger, :api_key\)/`
  3. `test_honeybadger_integration_is_enabled` — read `config/jumpstart.rb` as
     text, assert it matches `/"integrations"\s*=>\s*\[[^\]]*"honeybadger"/`
- Requires `minitest/autorun` and `yaml` only.

**NOT in scope:**

- Any assertion that `report_data` is false in test, or that `env == Rails.env` —
  those are gem defaults; asserting them tests Honeybadger, not us.
- Creating `config/honeybadger.yml` or touching `config/jumpstart.rb` (Task 2).
- Any test that boots Rails or instantiates the Honeybadger gem.

**Build order:**

1. **Test:** write `test/config/honeybadger_config_test.rb` as above.
2. **Implement:** nothing — this task is test-only, intentionally red.
3. **Verify:** `bin/rails test test/config/honeybadger_config_test.rb` — expect
   all three to fail/error. Tests 1 and 2 will raise `Errno::ENOENT` (no
   `config/honeybadger.yml` yet); test 3 will fail on the empty integrations
   array. **Confirm the failure reasons are exactly those** — any other error
   means the test file itself is wrong.

---

### Task 2 [Master]: Install Honeybadger — config file, integration flag, bundle

**Skills:** none
**Reference:** `lib/templates/config/honeybadger.yml` (the Jumpstart template —
two lines, no `request:` block). `config/jumpstart.rb:12`.

**In scope:**

- Copy `lib/templates/config/honeybadger.yml` → `config/honeybadger.yml` **by
  hand**, then append the session block so the final file is exactly:

  ```yaml
  ---
  api_key: <%= Rails.application.credentials.dig(:honeybadger, :api_key) %>

  request:
    disable_session: true
  ```

- Edit `config/jumpstart.rb:12`: `"integrations" => [],` →
  `"integrations" => ["honeybadger"],`
- Run `bundle install` — this is the entire gem install (`Gemfile.jumpstart:55`
  already reads `gem "honeybadger" if Jumpstart.config.honeybadger?`). Only
  `Gemfile.lock` should change.

**NOT in scope:**

- **Do NOT run `Jumpstart.config.save`, and do NOT click Save in the
  `/jumpstart` UI.** It bundles `write_config` (reformats/reorders all of
  `config/jumpstart.rb` through `pretty_inspect`) and `update_procfiles`
  (**creates a root `Procfile`**, which this repo deliberately does not have —
  start commands live in `render.yaml`'s `startCommand`).
- Adding a `Gemfile` entry — there is none to add.
- Any `staging:` / `development:` environment key inside `honeybadger.yml`.
  COV-31 made the credentials *file* the environment scope, so `dig` resolves
  per-env automatically. No env-namespacing.
- Touching credentials (Task 4).

**Build order:**

1. **Test:** already written in Task 1.
2. **Implement:** create `config/honeybadger.yml`; edit `config/jumpstart.rb`;
   `bundle install`.
3. **Verify:**
   - `bin/rails test test/config/honeybadger_config_test.rb` → all 3 green.
   - `bin/rails runner 'puts Jumpstart.config.honeybadger?'` → `true`.
   - `git status --short` → shows **only** `config/honeybadger.yml`,
     `config/jumpstart.rb`, `Gemfile.lock`. **If a `Procfile` appears, delete
     it** — something ran the generator.
   - `git diff config/jumpstart.rb` → a one-line change, not a whole-file
     reformat.

---

### Task 3 [Master]: Record the filter_parameters ↔ Honeybadger coupling

**Skills:** none
**Reference:** `config/initializers/filter_parameter_logging.rb`

**In scope:**

- Add an `AIDEV-NOTE:` comment above the
  `Rails.application.config.filter_parameters +=` list recording that
  Honeybadger's `request.filter_keys` automatically inherits this list, so
  adding a field here filters it from both logs and error reports — and that
  future homeschool-domain fields (`birthdate`, `grade`, `notes`, `transcript`)
  belong here when those models land.

**NOT in scope:**

- Adding any actual new filter keys. Those fields don't exist yet; adding them
  now is building for a hypothetical.
- Any change to the existing list's contents or ordering.
- Configuring `filter_keys` in `honeybadger.yml` — inheritance is automatic.

**Build order:**

1. **Test:** none — comment-only change, no behavior to assert.
2. **Implement:** edit `config/initializers/filter_parameter_logging.rb`.
3. **Verify:** `bin/rails runner 'puts Rails.application.config.filter_parameters.size'`
   boots clean; `bin/rubocop`.

> **Checkpoint 1 review:** after this task's work is finished, run
> **review-changes-mini** covering Tasks 1–3 (the code install: test,
> `honeybadger.yml`, integration flag, bundle, AIDEV-NOTE). If Tasks 1–3 were
> executed as a parallel batch, the master runs this once the whole batch
> returns rather than this task running it itself. Either way it runs exactly
> once, after all three are done.

---

### Task 4 [Master]: Honeybadger account, project, and API key into staging credentials

**Skills:** claude-in-chrome
**Reference:** `docs/designs/cov-33-honeybadger-monitoring.md` runbook steps 1–2.
Division of labor follows COV-32: Claude drives the browser; the user handles
signup, 2FA, and anything secret.

**In scope:**

- Create the Honeybadger account (user does signup/2FA) and one project named
  `cove`, free plan.
- **Resolve Open Question 1 before proceeding: does the free plan include uptime
  checks?** This could not be verified from the docs and must not be assumed. If
  free excludes uptime, **STOP and raise it** — AC #3 is blocked and needs a
  product decision. Tasks 1–5 and 7 still ship the error-tracking half.
- **Resolve Open Question 2 while in the dashboard:** does the free plan support
  per-environment alert rules? Record the answer in the PR; not a blocker.
- Navigate to the project's API key page and **stop there without screenshotting
  or reading the key** — it stays on the user's screen and out of the transcript.
- User runs `bin/rails credentials:edit --environment staging` and adds:
  ```yaml
  honeybadger:
    api_key: <paste>
  ```
- Commit `config/credentials/staging.yml.enc` on the feature branch.

**NOT in scope:**

- Setting `HONEYBADGER_API_KEY` as a Render env var. Environment variables
  **override** `config/honeybadger.yml`, so a stray one would silently win over
  credentials — and it reintroduces the two-places-for-secrets split COV-31
  removed.
- Touching `production.yml.enc`. Deferred to cutover.
- Creating the uptime check (Task 6).
- Any paid-plan feature, APM, or deploy tracking.

**Build order:**

1. **Test:** none — no code changes.
2. **Implement:** as above.
3. **Verify:**
   - `bin/rails credentials:show --environment staging | grep -c honeybadger` →
     non-zero. **Use `grep -c`, never bare `credentials:show`** — the latter
     prints the key in plaintext into the transcript.
   - `git show --stat HEAD` → `staging.yml.enc` changed;
     `git diff HEAD~1 -- config/credentials/staging.yml.enc` shows an opaque
     blob, no readable key.

---

### Task 5 [Master]: Temporary boom route, deploy the branch, verify AC #1 and #2

**Skills:** claude-in-chrome
**Reference:** `config/routes.rb` — the boom route goes at top level, **not**
inside the `Rails.env.local?` block at line 22 (that block is dev/test only,
which is exactly why staging has no raiseable URL today).
`config/environments/staging.rb` sets `force_ssl = true`.

**In scope:**

- Add one throwaway line to `config/routes.rb`:
  ```ruby
  # TEMPORARY — remove before opening the PR. Verifies COV-33 wiring.
  get "dev/boom", to: proc { raise "COV-33 Honeybadger smoke test" } if Rails.env.staging?
  ```
- Push the feature branch.
- In Render: repoint `cove-staging` (Settings → Build & Deploy → Branch) from
  `main` to `feature/cov-33-add-honeybadger-error-tracking`. Deploy; watch logs
  for a clean boot.
- Hit `https://staging.covehomeschool.com/dev/boom` — **explicitly https**, since
  `force_ssl` makes plain http return a 301 first. Expect a 500.
- Confirm in Honeybadger within a minute: the error appears (**AC #1**) and is
  tagged `env: staging`, not production (**AC #2**).

**NOT in scope:**

- Merging the boom route to `main`. It lives and dies on the feature branch.
- Changing `render.yaml` — the branch repoint is a dashboard-only, temporary
  change.
- Removing the boom route or repointing back to `main` (Task 7).
- Chasing a missing error report as a bug before confirming the key: a
  missing/wrong key means the app boots normally and errors silently never
  arrive. This step is the *only* thing that proves the key is right.

**Build order:**

1. **Test:** none — the deployed 500 *is* the test.
2. **Implement:** edit `config/routes.rb`, commit, push; repoint and deploy in
   Render.
3. **Verify:** `bin/rails test test/config/` still green locally; Render deploy
   log shows clean boot; `/dev/boom` returns 500; Honeybadger shows the error
   tagged `staging`. Screenshot the Honeybadger error detail page (env tag
   visible) as evidence for AC #1/#2.

---

### Task 6 [Master]: Uptime check on `/up` with verified email alerting (AC #3)

**Skills:** claude-in-chrome
**Reference:** design runbook step 6. Frequency accepts only 1, 5, or 15 minutes.

**In scope:**

- Create an uptime check against `https://staging.covehomeschool.com/up` with:
  - **Frequency: 5 minutes** — Render free spins down after ~15 min idle, so 5
    keeps it warm with margin; 15 races the timeout, 1 burns quota for no gain.
  - Match type: success (any 2xx)
  - Validate SSL: on
  - Email alerts: on
- Confirm the check is green.
- **Then prove alerting actually fires:** temporarily repoint the check at a
  guaranteed-404 path, confirm the alert email arrives, then set it back to `/up`
  and confirm green again. A green check alone does not satisfy AC #3.

**NOT in scope:**

- A production uptime check, or per-environment alert rules — deferred.
- Treating "staging stops spinning down" as a fault. That's the intended side
  effect of a 5-minute ping.

**Build order:**

1. **Test:** none.
2. **Implement:** as above, via the Honeybadger dashboard.
3. **Verify:** screenshot the green check; confirm receipt of the alert email
   from the deliberate-404 step; screenshot the check restored to `/up` and
   green.

> **Checkpoint 2 review:** after this task's work is finished, run
> **review-changes-mini** covering Tasks 4–6 (credentials, boom route + branch
> deploy, uptime check). If Tasks 4–6 were executed as a parallel batch, the
> master runs this once the whole batch returns rather than this task running it
> itself. Either way it runs exactly once, after all three are done.

---

### Task 7 [Master]: Repoint Render to main, remove the boom route, final gates

**Skills:** claude-in-chrome
**Reference:** design runbook steps 7–8.

**In scope:**

- Switch `cove-staging`'s branch back to `main` and **reload the settings page to
  verify it stuck** — the design flags this as the step most likely to be
  silently forgotten.
- Delete the boom route (and its comment) from `config/routes.rb`; commit.
- Confirm staging redeploys from `main` and boots clean.
- **AC #4:** full `bin/rails test` run — adding a gem with a Rails railtie can
  perturb unrelated tests. Honeybadger won't fight WebMock (`report_data` is off
  in test, so no HTTP calls).
- **AC #5 audit:** `git diff origin/main...` — confirm the boom route is gone, no
  `Procfile` exists, no plaintext API key anywhere, and the only credentials
  change is an opaque encrypted blob.

**NOT in scope:**

- Opening the PR or merging — the user reviews and merges ticket work
  themselves. `/close-out` handles the PR.
- Adding the production key or a production uptime check.
- Re-verifying that staging still reports errors after the route is deleted.
  Nothing proves it once the route is gone — that's accepted, and it's precisely
  why the Task 1 config test matters more than it looks.

**Build order:**

1. **Test:** `bin/rails test` (full suite).
2. **Implement:** Render branch repoint + verify; remove boom route from
   `config/routes.rb`; commit.
3. **Verify:**
   - `bin/rails test` — full suite green, output shown. **Do not claim AC #4
     without pasting the run output.**
   - `bin/rubocop`
   - `git diff origin/main... -- config/routes.rb` → empty.
   - `git diff origin/main... --stat` → only `config/honeybadger.yml`,
     `config/jumpstart.rb`, `Gemfile.lock`,
     `config/initializers/filter_parameter_logging.rb`,
     `config/credentials/staging.yml.enc`,
     `test/config/honeybadger_config_test.rb`, plus docs.
   - `git diff origin/main... | grep -iE 'hbp_|api_key: [A-Za-z0-9]'` → no hits.

> **Checkpoint 3 review:** this is a single-task checkpoint. Run
> **review-changes-mini** covering Task 7 once its work is finished.

---

## Task Dependencies

- Task 2 depends on Task 1 (tests written first, must be red before they can go
  green).
- Task 3 is independent of Tasks 1–2 and could run alongside them, but is
  grouped into Checkpoint 1 so the whole code install reviews as one unit.
- Task 4 depends on Checkpoint 1 being complete (no point pasting a key before
  the gem is installed).
- Task 5 depends on Task 4 (the key must be in `staging.yml.enc` before the
  deploy, or the boom raises into the void).
- Task 6 depends on Task 4 (needs the project) and on Task 4's free-plan answer.
  It does **not** depend on Task 5 — but keep it after, so the branch-deploy
  verification isn't left half-finished.
- Task 7 depends on Tasks 5 and 6 (it undoes Task 5's Render repoint and route).
- **No tasks run in parallel.** This is a strictly sequential chain: install →
  key → deploy-and-prove → monitor → clean up.

## Known blockers

1. **Free plan may not include uptime checks** (Open Question 1). Resolved at
   Task 4. If excluded, Task 6 is blocked and AC #3 needs a product decision —
   stop and raise it. Tasks 1–5 and 7 still deliver error tracking.
2. Task 5 requires the staging site to be reachable; confirm
   `https://staging.covehomeschool.com/up` returns 200 before repointing the
   branch.
