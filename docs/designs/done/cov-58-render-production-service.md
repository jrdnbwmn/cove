> Ticket: COV-58
> Branch: jrdnbwmn/fix/cov-58-render-service-definition
> Plan created: docs/plans/cov-58-render-production-service.md

# Feature: Fix the dormant production service definition in `render.yaml`

## Problem

The production service in `render.yaml` is commented out and has never been
deployed. It carries four config defects that would only surface during a live
cutover, when they are most expensive to debug. Fix them now, while they're
free to fix, and lock them in with tests.

**Nothing in this ticket provisions or bills anything.** The production block
stays commented out. The only running service touched is free-tier staging.

## Approach

Four config fixes plus two test files. No application code beyond two
one-line environment settings.

### Defect 1 — all four production databases resolve to the same URL

`render.yaml` sets `DATABASE_URL`, `CABLE_DATABASE_URL`, `CACHE_DATABASE_URL`,
and `QUEUE_DATABASE_URL` to the same `cove-production-db` `connectionString`.
Rails lets `<NAME>_DATABASE_URL` override the matching `config/database.yml`
entry, so the distinct names at `database.yml:149/155/161` get overridden back
to the primary database. `db:prepare` then sees an already-initialized database
and silently never loads the cache, queue, or cable schemas. No boot error —
things fail later when Solid Cache/Queue/Cable hit tables that don't exist.

**This cannot be fixed in `render.yaml`.** Render's `fromDatabase` only hands
back the one connection string; the blueprint has no syntax for altering the
database name. The fix has to live in `database.yml`.

Deleting the three env vars alone is also insufficient: production
cache/queue/cable inherit `<<: *primary_production`, whose credentials come
from `username: jumpstart` + `ENV["POSTGRES_PASSWORD"]`, and Render sets
`DATABASE_URL`, not `POSTGRES_PASSWORD`. They'd fail to authenticate.

**Fix:** generalize the existing ERB helper `staging_role_database_url`
(`database.yml:26`) to `role_database_url`, and wire it into the `production:`
block exactly the way `staging:` already uses it — derive a per-role URL from
`DATABASE_URL` with the database name swapped. Then delete the three redundant
`*_DATABASE_URL` entries from `render.yaml`.

The nil guard (`return nil unless ENV["DATABASE_URL"]`) must stay. ERB renders
the whole file for every environment, so this helper is called during
development and test boots too, where `DATABASE_URL` is normally unset.

### Defect 2 — memory plan contradicts the embedded worker, and the worker is inert

The ticket describes `plan: basic-256mb` versus `SOLID_QUEUE_IN_PUMA: true`.
It's worse than that: `config/jumpstart.rb:7` sets
`"background_job_processor" => nil`, and `production.rb:53` only assigns an
adapter *if* that's present. So production would set **no** Active Job adapter
and fall back to Rails' default `:async` — meaning the embedded Solid Queue
supervisor, dispatcher, and worker would burn memory polling a queue that
nothing ever enqueues into.

"Keep the inline adapter for launch" is not available either.
`ActiveJob::QueueAdapters::InlineAdapter#enqueue_at` raises `NotImplementedError`
(activejob 8.1.3), and two live paths enqueue with a delay:

- `lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb:25`
  — `.deliver_later(wait: 1.hour)`. Stripe is enabled, so this is reachable.
- `lib/jumpstart/app/models/inbound_webhook.rb:8` — `.set(wait: 7.days)`.

**This is a live bug on staging today**, which hardcodes `:inline` at
`staging.rb:57` — cancelling a subscription on staging raises.

**Fix, production:** set the adapter explicitly so the embedded worker has
something to do —
`config.active_job.queue_adapter = Jumpstart.config.queue_adapter || :solid_queue`.
The `||` keeps Jumpstart's hook intact if `background_job_processor` is ever
set. `SOLID_QUEUE_IN_PUMA: true` stays.

Deliberately **not** adding `mission_control-jobs`. It only arrives via
`Gemfile.jumpstart:66` if `config/jumpstart.rb` is flipped to
`"background_job_processor" => "solid_queue"` — and that flip also hits
`development.rb:89`, switching local dev from `:async` to `:solid_queue`, where
jobs would silently pile up in `jumpstart_development_queue` with no worker
running under `bin/dev`. A jobs dashboard isn't worth breaking local dev for an
app with zero custom job classes.

**Fix, staging:** `:inline` → `:async`. This fixes the `enqueue_at` crash,
actually runs jobs, and costs zero extra memory — no supervisor, no dispatcher,
no worker. `:solid_queue` on staging would just trade "cancel subscription
raises" for "jobs enqueue and silently never run," which is the trade-off
commit `b85d959` already made. Jobs are lost on restart under `:async`;
acceptable for staging.

### Defect 3 — `WEB_CONCURRENCY` unset in production

Staging pins `WEB_CONCURRENCY: "0"` because Render defaults it to `1`, which
starts Puma in *cluster* mode — a second full copy of the app in memory. The
production block omits it.

**Fix:** add `WEB_CONCURRENCY: "0"` to the production block.

### Defect 4 (found during brainstorm) — `plan: basic-256mb` is not a valid web service plan

`basic-256mb` is a Render **Postgres** instance type, not a web service plan.
Valid web service plans are `free` / `starter` / `standard` / `pro` / …
(https://render.com/docs/blueprint-spec, https://render.com/docs/compute-plans).
The "256MB" premise underlying defects 2 and 3 doesn't correspond to a real
plan at all.

**Fix:** `plan: starter` (512MB, $7/mo). The `cove-production-db` entry keeps
`plan: basic-256mb`, which *is* correct for Postgres.

### Memory rationale to record in the blueprint comments

`starter` is also 512MB — the same ceiling staging OOM'd against. But the
commit order matters: `b85d959` (turn off embedded Solid Queue) landed
**before** `88cd7f3` (pin `WEB_CONCURRENCY=0`). Staging was running cluster-mode
Puma — two full app copies — *plus* supervisor + dispatcher + worker when it
blew up. Single-mode Puma with an embedded worker on 512MB has never been
tested.

So the dormant block records `starter` + `WEB_CONCURRENCY: "0"` +
`SOLID_QUEUE_IN_PUMA: true`, with a comment naming the escape hatch: if it
OOMs at cutover, split the worker into a separate `type: worker` service
running `bundle exec rake solid_queue:start` (~$7/mo more). Cheapest
production-shaped config, loud failure mode, reversible in a few lines.

## Acceptance Criteria

- [ ] Production cache/queue/cable resolve to databases distinct from primary,
      derived from `DATABASE_URL`
- [ ] Production sets an Active Job adapter that matches its embedded worker
- [ ] Staging no longer raises on `deliver_later(wait:)`
- [ ] `WEB_CONCURRENCY` explicitly set for production
- [ ] Production `plan` is a valid web service plan
- [ ] Tests cover the production service and fail if any defect regresses
- [ ] `bin/rails test` passes
- [ ] The production block remains commented out; nothing is provisioned

## Prototype

None.

## Data Model

No schema changes. `config/database.yml` connection config only:

| Env | Role | Before | After |
|---|---|---|---|
| production | primary | `database: jumpstart_production`, `<<: *default` | unchanged (Render's `DATABASE_URL` overrides) |
| production | cache | `<<: *primary_production`, `database: jumpstart_production_cache` | `<<: *default`, `url: role_database_url("jumpstart_production_cache")` |
| production | queue | `<<: *primary_production`, `database: jumpstart_production_queue` | `<<: *default`, `url: role_database_url("jumpstart_production_queue")` |
| production | cable | `<<: *primary_production`, `database: jumpstart_production_cable` | `<<: *default`, `url: role_database_url("jumpstart_production_cable")` |

Database names are unchanged; only how they're resolved changes. The
`staging:` block gets the helper rename and nothing else — its behavior must
stay byte-for-byte identical, since it's the one live deployment.

## Screens / Flows

No UI. The user-visible flow is the deploy:

1. Cutover ticket uncomments the production block and the `cove-production-db`
   entry, then syncs the blueprint.
2. Render provisions `cove-production-db` (`basic-256mb`) and `cove-production`
   (`starter`).
3. `preDeployCommand: bundle exec rails db:prepare` runs. It creates
   `jumpstart_production`, `_cache`, `_queue`, and `_cable` and loads each
   schema. If the Render Postgres role lacks `CREATEDB`, **this fails the
   deploy before any traffic is routed** — that's the verification, and it's
   why `preDeployCommand` (paid-plan only) is better here than staging's
   in-`startCommand` approach.
4. Puma boots single-mode with the Solid Queue supervisor embedded.

Commit `a48860c` already proved a Render Postgres role can create the three
extra databases — staging runs this way today.

## Scope

**In:**
- `config/database.yml` — rename `staging_role_database_url` →
  `role_database_url`; wire it into the production cache/queue/cable entries
- `render.yaml` — production block: `plan: starter`, add `WEB_CONCURRENCY: "0"`,
  delete the three redundant `*_DATABASE_URL` env vars, quote
  `SOLID_QUEUE_IN_PUMA: "true"`, add `# >>> production (dormant)` /
  `# <<<` markers, record the memory rationale in comments
- `config/environments/production.rb` —
  `queue_adapter = Jumpstart.config.queue_adapter || :solid_queue`
- `config/environments/staging.rb` — `:inline` → `:async`, update the
  `AIDEV-NOTE` to explain the `enqueue_at` crash
- `test/config/render_blueprint_test.rb` — extend to the production service
- `test/config/database_configuration_test.rb` — new; asserts the four
  production roles resolve to four distinct databases

**Deferred:**
- Provisioning production, `autoDeploy` for production, DNS, and the cutover
  itself — a later ticket
- Splitting Solid Queue into a separate `type: worker` service — only if
  `starter` OOMs at cutover
- `mission_control-jobs` and a jobs dashboard
- Flipping `config/jumpstart.rb`'s `background_job_processor`
- Sizing up to `standard` (2GB)

## Open Questions

None.

## More Info

### Testing approach

The production block stays commented, so `YAML.load_file` can't see it. The
test locates the `# >>> production (dormant)` / `# <<<` markers, strips the
`# ` prefix from the lines between them, and parses the result. Side benefit:
this proves the commented text is **valid YAML**, catching syntax rot that
would otherwise only appear mid-cutover.

`test/config/render_blueprint_test.rb` is plain `Minitest::Test` with no Rails
dependency — keep it that way. The new `database_configuration_test.rb` should
follow suit: render `config/database.yml` through ERB with `DATABASE_URL`
stubbed, parse the YAML, and assert the four production URLs have four distinct
paths. Restore `ENV` in an `ensure`.

The existing staging assertions stay untouched.

### Render facts confirmed during brainstorm

- Free web services spin down after 15 min idle; `preDeployCommand` is
  paid-only; 750 instance-hours/month is one always-on service
- Only one free Postgres per workspace (`cove-staging-db` holds it), and free
  Postgres is deleted 30 days after creation
- `starter` = 512MB / $7/mo; `standard` = 2GB / $25/mo

These are why production can't be free, and why this ticket deliberately
doesn't provision it yet.

### Gotcha for the implementer

Do not run the Jumpstart config generator. Per `AGENTS.md`, it regenerates
`config/jumpstart.rb` and creates a root `Procfile` this repo deliberately
doesn't have. Nothing in this ticket needs it.
