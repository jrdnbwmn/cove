> Ticket: COV-58
> Branch: jrdnbwmn/fix/cov-58-render-service-definition

# Plan: Fix the dormant production service definition in `render.yaml`

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | `database.yml`: generalize role URL helper, wire production cache/queue/cable | Master | |
| 2 | 1 | 1 | Job adapters: production `:solid_queue` fallback, staging `:inline` → `:async` | Clone | |
| 3 | 1 | 1 | `render.yaml` production block: plan, concurrency, env vars, dormant-block test | Clone | |

## Prerequisites

- Design: `docs/designs/cov-58-render-production-service.md`
- Prototype: None
- Feature branch exists: `jrdnbwmn/fix/cov-58-render-service-definition` ✓
- Shell PATH: every `bin/rails` invocation must be prefixed with
  `export PATH="$HOME/.local/share/mise/shims:$PATH" &&` (see AGENTS.md). Confirm
  `ruby -v` reports 4.0.5 before trusting any test output.
- Do **not** run the Jumpstart config generator or `Jumpstart.config.save`. Nothing
  here needs it, and it creates a root `Procfile` this repo deliberately omits.

## Tasks

### Task 1 [Master]: Derive production cache/queue/cable URLs from `DATABASE_URL`

**Skills:** write-tests
**Reference:** `config/database.yml:16-33` (the ERB helper) and `config/database.yml:99-117`
(the `staging:` block — the exact shape production should copy)

**In scope:**

- `config/database.yml`:
  - Rename `staging_role_database_url` → `role_database_url` (line 26); update
    the three call sites in `staging:` (lines 108/112/116).
  - Keep `return nil unless ENV["DATABASE_URL"]` exactly as-is. ERB renders the
    whole file on every boot, so this runs in development and test where
    `DATABASE_URL` is unset.
  - Generalize the comment block at lines 17-23 — it currently says "for staging";
    it now covers production too.
  - Rewrite production `cache`, `queue`, `cable` (lines 147-163) to match the
    staging shape: `<<: *default` (not `*primary_production`) plus
    `url: <%= role_database_url("jumpstart_production_cache") %>` etc. Keep the
    existing database names and `migrations_paths`. Drop the now-wrong
    `# Or set CACHE_DATABASE_URL to override` comments.
  - Leave `production: primary:` untouched, including its `&primary_production`
    anchor — the anchor goes unused, which is fine and mirrors `&primary_staging`,
    already unused today. Minimal diff.
- `test/config/database_configuration_test.rb` (new).

**NOT in scope:**

- Any change to the `staging:`, `development:`, or `test:` blocks beyond the
  helper rename. Staging is the one live deployment; its rendered output must be
  byte-for-byte identical.
- Schema changes, migrations, or running `db:migrate` (it dirties four schema
  dumps — see AGENTS.md).
- Touching `render.yaml` — Task 3 owns it.

**Build order:**

1. **Test:** `test/config/database_configuration_test.rb`, plain `Minitest::Test`
   (no `test_helper`, no Rails — match `render_blueprint_test.rb`). Requires
   `minitest/autorun`, `erb`, `yaml`, `uri`. Add a private helper that renders
   `config/database.yml` through ERB with a given `ENV["DATABASE_URL"]` and parses
   it with `YAML.load(rendered, aliases: true)` — **`aliases: true` is required**,
   the file uses `<<: *default` merge keys and Psych raises without it. Restore
   the prior `ENV["DATABASE_URL"]` in an `ensure`. Assert:
   - With `DATABASE_URL` = `postgres://u:p@host:5432/cove_production`: the three
     production role `url`s have paths `/jumpstart_production_cache`,
     `/jumpstart_production_queue`, `/jumpstart_production_cable` — three distinct
     values, all distinct from the `DATABASE_URL` path that primary resolves to.
     Four distinct databases total. (Primary has no `url` key by design; Rails
     merges `DATABASE_URL` onto it at boot.)
   - Production cache/queue/cable carry **no** `username` or `password` key —
     that's the `*primary_production` inheritance defect, which would have sent
     `username: jumpstart` + an unset `POSTGRES_PASSWORD` to Render.
   - Staging's three role URLs still resolve to `jumpstart_staging_{cache,queue,cable}`
     (regression guard on the rename).
   - With `DATABASE_URL` **unset**: the file still renders and parses, and the
     production/staging role `url` values are nil — the guard that keeps local
     development and test boots working.
2. **Implement:** the `config/database.yml` edits above.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/config/database_configuration_test.rb`

### Task 2 [Clone]: Give production a real job adapter; stop staging crashing on `deliver_later(wait:)`

**Skills:** write-tests
**Reference:** `config/environments/production.rb:53`, `config/environments/staging.rb:54-58`,
`test/config/staging_inline_adapter_test.rb`

**In scope:**

- `config/environments/production.rb:53` →
  `config.active_job.queue_adapter = Jumpstart.config.queue_adapter || :solid_queue`.
  The `||` preserves Jumpstart's hook if `background_job_processor` is ever set;
  today it's `nil` (`config/jumpstart.rb:7`), so production would otherwise fall
  back to Rails' `:async` while running an embedded Solid Queue worker with
  nothing to consume. Add an `AIDEV-NOTE` saying exactly that.
- `config/environments/staging.rb:57` `:inline` → `:async`, and rewrite the
  `AIDEV-NOTE` above it: `:inline` raises `NotImplementedError` on
  `enqueue_at`, which two live paths hit —
  `lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb:25`
  (`deliver_later(wait: 1.hour)`, reachable because Stripe is enabled) and
  `lib/jumpstart/app/models/inbound_webhook.rb:8` (`set(wait: 7.days)`).
  `:async` fixes it at zero memory cost — no supervisor, dispatcher, or worker.
  Note that jobs are lost on restart, which is acceptable for staging.
- `git mv test/config/staging_inline_adapter_test.rb test/config/job_adapter_test.rb`;
  rename the class to `JobAdapterTest`. **This existing test currently asserts
  `:inline` and will fail otherwise.**

**NOT in scope:**

- Flipping `config/jumpstart.rb`'s `background_job_processor` to `"solid_queue"`.
  It would also hit `development.rb:89`, switching local dev off `:async` onto
  `:solid_queue`, where jobs pile up unrun in `jumpstart_development_queue`
  because nothing under `bin/dev` runs a worker.
- Adding `mission_control-jobs` or any jobs dashboard.
- `config/environments/development.rb` or `test.rb`.
- Any `render.yaml` change (Task 3) — including `SOLID_QUEUE_IN_PUMA`.

**Build order:**

1. **Test:** in `test/config/job_adapter_test.rb`, keep the file-read style of the
   original (these read the config source as text — they do not boot Rails).
   Three tests:
   - staging: `assert_match(/queue_adapter\s*=\s*:async/)`,
     `refute_match(/:inline/)`, plus the existing
     `refute_match(/Jumpstart\.config\.queue_adapter/)` and
     `refute_match(/SOLID_QUEUE_IN_PUMA/)` assertions, carried over unchanged.
   - staging: carry over `test_staging_does_not_attempt_unconfigured_outbound_email_delivery`
     verbatim.
   - production: `assert_match(/queue_adapter\s*=\s*Jumpstart\.config\.queue_adapter\s*\|\|\s*:solid_queue/)`
     against `config/environments/production.rb` — the embedded worker in
     `render.yaml` is only justified if an adapter actually feeds it.
2. **Implement:** the two environment-file edits.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/config/job_adapter_test.rb`

### Task 3 [Clone]: Fix the dormant production block in `render.yaml` and test it while commented

**Skills:** write-tests
**Reference:** `render.yaml:3-33` (the live staging service — the production block
should mirror its env-var style) and `test/config/render_blueprint_test.rb`

**In scope:**

- `render.yaml`, production service block (lines 35-72), **which stays commented out**:
  - `plan: basic-256mb` → `plan: starter`. `basic-256mb` is a Postgres instance
    type, not a valid web service plan; web plans are `free`/`starter`/`standard`/`pro`.
    The `cove-production-db` entry keeps `basic-256mb` — correct there.
  - Add `WEB_CONCURRENCY` = `"0"`. Render defaults it to `1`, which starts Puma in
    cluster mode — a second full copy of the app in memory.
  - Quote `SOLID_QUEUE_IN_PUMA` value as `"true"` (matches staging's `"0"` style).
  - Delete the `CABLE_DATABASE_URL`, `CACHE_DATABASE_URL`, and `QUEUE_DATABASE_URL`
    entries entirely. All three pointed at the same `cove-production-db`
    connection string, overriding the distinct names in `database.yml` back to the
    primary; Task 1 now derives them from `DATABASE_URL`. Keep `DATABASE_URL`.
  - Wrap the block in `# >>> production (dormant)` and `# <<<` marker lines.
  - Record the memory rationale in comments: `starter` is 512MB — the same ceiling
    staging OOM'd against — but commit order matters. `b85d959` (disable embedded
    Solid Queue) landed *before* `88cd7f3` (pin `WEB_CONCURRENCY=0`), so staging
    was running cluster-mode Puma *plus* supervisor + dispatcher + worker when it
    blew up. Single-mode Puma with an embedded worker on 512MB has never been
    tested. Escape hatch if it OOMs at cutover: split the worker into a separate
    `type: worker` service running `bundle exec rake solid_queue:start` (~$7/mo more).
  - **Formatting constraint:** every line between the markers must be
    `<optional whitespace>#` — no bare blank lines. Prose comments inside the block
    must be **double-commented** (`  #   # Render defaults WEB_CONCURRENCY...`) so
    that stripping one `# ` leaves a valid YAML comment rather than garbage.
- `test/config/render_blueprint_test.rb` — extend; leave the existing staging test
  untouched.

**NOT in scope:**

- Uncommenting either the production service or the `cove-production-db` entry.
  Nothing may be provisioned or billed by this ticket.
- Changing the live `cove-staging` service or `cove-staging-db`.
- `autoDeploy` policy, DNS, or the cutover itself — a later ticket. Leave
  `autoDeploy: false`.
- `config/database.yml` (Task 1) or the environment files (Task 2).

**Build order:**

1. **Test:** extend `test/config/render_blueprint_test.rb` (stays plain
   `Minitest::Test`, no Rails). Add a private helper that reads `render.yaml`,
   takes the lines strictly between `# >>> production (dormant)` and `# <<<`,
   un-comments each with `sub(/^(\s*)#\s?/) { $1 }`, and `YAML.load`s the result —
   parsing it at all is itself the check that the commented text hasn't rotted into
   invalid YAML. Assert on the resulting service:
   - `plan` == `"starter"` (guards against a Postgres instance type reappearing)
   - `WEB_CONCURRENCY` == `"0"` and `SOLID_QUEUE_IN_PUMA` == `"true"` — these two
     must agree: single-mode Puma is what makes room for the embedded worker
   - `DATABASE_URL` resolves `fromDatabase` `cove-production-db`
   - none of `CACHE_DATABASE_URL` / `QUEUE_DATABASE_URL` / `CABLE_DATABASE_URL`
     is present
   - `preDeployCommand` == `"bundle exec rails db:prepare"` and `startCommand`
     does **not** contain `db:prepare` — on a paid plan the migration runs before
     traffic is routed, so a missing `CREATEDB` grant fails the deploy loudly
   - `autoDeploy` is `false`
   - Separately: `YAML.load_file` of `render.yaml` finds **no** service named
     `cove-production` and **no** database named `cove-production-db` — proof the
     block is still dormant and nothing got provisioned.
2. **Implement:** the `render.yaml` edits above.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/config/render_blueprint_test.rb`
4. **Checkpoint 1 review:** this is the last task of checkpoint 1 (Tasks 1–3).
   After the work is done, run review-changes-mini over Tasks 1–3. If Tasks 2 and 3
   were dispatched as a parallel batch, the **master** runs this review once the
   whole batch returns, rather than this task running it itself — either way it
   runs exactly once, after all three tasks are complete.

## Task Dependencies

- Task 1 has no dependencies and goes first — it establishes the `role_database_url`
  pattern and is the only task touching `config/database.yml`.
- Tasks 2 and 3 are independent of each other and of Task 1 (disjoint file sets),
  so they can run in parallel once Task 1 lands.
- Tasks 1 and 3 are logically paired — deleting the three `*_DATABASE_URL` env
  vars is only safe because Task 1 derives those URLs — but they touch no common
  files, so ordering is enough; they don't need to be one task.
- Final full-suite check after all three:
  `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test`
