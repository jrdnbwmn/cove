> Ticket: COV-30
> Branch: jrdnbwmn/cov-30-rewrite-render-yaml
> Plan created: docs/plans/render-staging-blueprint.md

# Feature: Rewrite render.yaml as a real staging blueprint

## Problem

`render.yaml` is the unmodified Jumpstart example — one free web service literally
named `rails`, plus four separate `basic-256mb` Postgres databases (primary,
solid_cable, solid_cache, solid_queue). Provisioning it as-is would be both wrong
and ~4x the necessary database cost. We need a correct staging blueprint now, with
production defined but dormant until a later cutover.

## Approach

Rewrite `render.yaml` to define exactly one active service (a free staging web
service) and one active database (a free staging Postgres). Solid Cache, Solid
Queue, and Solid Cable tables all live in that single primary database — their
table names don't collide and `config/database.yml` gives each connection its own
`migrations_paths` — so `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, and
`CABLE_DATABASE_URL` all resolve to the primary connection string. Jobs run in the
web process via `SOLID_QUEUE_IN_PUMA=true` (no paid worker). Migrations move out of
the build script into Render's `preDeployCommand` so they stop firing on builds
that never deploy. A fully-commented production block mirrors staging for the later
uncomment-and-provision cutover.

Staging runs as `RAILS_ENV=staging` (set explicitly), matching the existing
`config/environments/staging.rb` and the `staging:` block in `config/database.yml`.
This is a deliberate decision confirmed with the product owner: only staging is
provisioned on Render for now; production launches later.

This is a config-only change. No models, controllers, or app code. No provisioning.

## Acceptance Criteria

- [ ] `render.yaml` defines exactly one active service and one active database
- [ ] Blueprint validates in Render without provisioning errors
- [ ] `bin/render-build.sh` no longer runs migrations
- [ ] Commented production block is present and complete
- [ ] Solid Queue/Cache/Cable env vars resolve to the primary database

## Prototype

None.

## Data Model

No application data model changes. Infrastructure only.

Render resources defined by the blueprint:

- **Web service** `cove-staging` — free plan, ruby runtime, region `oregon`,
  `branch: main`, `autoDeploy: true`, `healthCheckPath: /up`.
  - `buildCommand: ./bin/render-build.sh`
  - `preDeployCommand: bundle exec rails db:prepare`
  - `startCommand: bundle exec rails server`
  - envVars: `RAILS_MASTER_KEY` (sync: false), `RAILS_ENV=staging`,
    `RACK_ENV=staging`, `SOLID_QUEUE_IN_PUMA=true`, and `DATABASE_URL`,
    `CABLE_DATABASE_URL`, `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL` — all four
    `fromDatabase: { name: cove-staging-db, property: connectionString }`.
- **Database** `cove-staging-db` — `plan: free`, region `oregon`,
  `ipAllowList: []` (internal connections only).
- **Commented production block** — parallel `web` (`cove-production`,
  `RAILS_ENV=production`) + `database` (`cove-production-db`, paid
  `basic-256mb`), same solid-URL wiring, `autoDeploy` left off with a note that
  prod auto-deploy is a decision for the cutover ticket.

`bin/render-build.sh` becomes:

```bash
#!/usr/bin/env bash
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
```

The arg-parsing loop, the `--skip-migrations` (`-s`) flag, and the `db:prepare`
line are all removed — the flag is now dead, and migrations run in
`preDeployCommand`.

## Screens / Flows

None. No UI. Verification is by inspecting `render.yaml` structure and validating
the blueprint in Render.

## Scope

**In:**
- One active staging web service (`cove-staging`, free) with `healthCheckPath: /up`
  and auto-deploy from `main`.
- One active staging Postgres (`cove-staging-db`, free).
- All solid connections (`CACHE_/QUEUE_/CABLE_DATABASE_URL`) pointed at the primary
  connection string.
- `SOLID_QUEUE_IN_PUMA=true` so jobs run in the web process.
- `RAILS_ENV=staging` / `RACK_ENV=staging`.
- Move `db:prepare` from `bin/render-build.sh` into `preDeployCommand`; delete the
  now-dead `--skip-migrations` flag and arg parsing from the build script.
- A complete, commented-out production block (web service + database).

**Deferred:**
- Actually provisioning the Render services / database (separate ticket).
- Uncommenting and cutting over production.
- Redis / Sidekiq worker blueprints (the stock commented examples can be dropped or
  left out; not part of this scope).

## Open Questions

None.

## More Info

Render constraints (confirmed against current docs, July 2026), captured so the
free-tier tradeoffs are documented:

- One free Postgres per workspace; expires 30 days after creation; 1 GB; no backups.
- Free web services spin down after ~15 min idle, with ~1 min cold start.
- Full-stack preview environments require Pro ($25/mo) — out of scope.

Secrets: only `RAILS_MASTER_KEY` is entered in the Render dashboard (`sync: false`);
`secret_key_base` derives from encrypted credentials. No separate `SECRET_KEY_BASE`.

Region must stay `oregon` and be consistent across services, per the blueprint
comment, so internal keys resolve.
