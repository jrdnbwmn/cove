> Ticket: COV-30
> Branch: jrdnbwmn/cov-30-rewrite-render-yaml

# Plan: Rewrite render.yaml as a real staging blueprint

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Rewrite `render.yaml` (staging active + prod commented) | Master | ✅   |
| 2    | 1     | 1          | Strip migrations/flag from `bin/render-build.sh`        | Master | ✅   |

## Prerequisites

- Design: `docs/designs/render-staging-blueprint.md`
- Prototype: None
- Feature branch exists: `jrdnbwmn/cov-30-rewrite-render-yaml` (current branch)

## Tasks

### Task 1 [Master]: Rewrite render.yaml

**Skills:** none (infra config)
**Reference:** Current `render.yaml` (stock Jumpstart example) and `config/database.yml` `staging:` block for the connection names.

**In scope:**

- Replace the entire file with one active staging **web service** `cove-staging`:
  - `type: web`, `plan: free`, `runtime: ruby`, `region: oregon`, `branch: main`, `autoDeploy: true`, `healthCheckPath: "/up"`
  - `buildCommand: "./bin/render-build.sh"`
  - `preDeployCommand: bundle exec rails db:prepare`
  - `startCommand: bundle exec rails server`
  - envVars: `RAILS_MASTER_KEY` (`sync: false`), `RAILS_ENV=staging`, `RACK_ENV=staging`, `SOLID_QUEUE_IN_PUMA=true`, and `DATABASE_URL` / `CABLE_DATABASE_URL` / `CACHE_DATABASE_URL` / `QUEUE_DATABASE_URL` — **all four** `fromDatabase: { name: cove-staging-db, property: connectionString }`.
- One active **database** `cove-staging-db`: `plan: free`, `region: oregon`, `ipAllowList: []`.
- A fully-commented-out **production block** mirroring staging: web `cove-production` (`RAILS_ENV=production`, `RACK_ENV=production`, same solid-URL wiring pointed at `cove-production-db`) + database `cove-production-db` (`plan: basic-256mb`). Leave `autoDeploy` off with a comment noting prod auto-deploy is a cutover-ticket decision.
- Preserve the `region must be consistent...` rationale comment.

**NOT in scope:**

- Redis / Sidekiq worker blocks — drop them entirely (see design "Deferred").
- Any provisioning or dashboard action.
- Uncommenting production.

**Build order:**

1. **Implement:** Overwrite `render.yaml` with the structure above.
2. **Verify:** `ruby -ryaml -e "YAML.load_file('render.yaml'); puts 'valid'"` — confirms the (uncommented) YAML parses. Then eyeball: exactly one active `services:` entry and one active `databases:` entry; all four solid URLs reference `cove-staging-db`.

### Task 2 [Master]: Strip migrations and dead flag from bin/render-build.sh

**Skills:** none
**Reference:** Current `bin/render-build.sh`.

**In scope:**

- Reduce the script to exactly:
  ```bash
  #!/usr/bin/env bash
  set -o errexit

  bundle install
  bundle exec rails assets:precompile
  bundle exec rails assets:clean
  ```
- Remove the arg-parsing `while` loop, the `-s | --skip-migrations` case, and the trailing `db:prepare` line (migrations now run in `preDeployCommand`).

**NOT in scope:**

- Any other build steps or changes to file permissions.

**Build order:**

1. **Implement:** Rewrite `bin/render-build.sh` as above.
2. **Verify:** `bash -n bin/render-build.sh` (syntax check) and confirm the file no longer contains `db:prepare` or `skip-migrations` (`grep -nE 'db:prepare|skip-migrations' bin/render-build.sh` returns nothing).
3. **Review checkpoint:** This is the final task of Checkpoint 1 — run **review-changes-mini** over Tasks 1–2 (both files) before reporting complete.

## Task Dependencies

- Tasks 1 and 2 are independent and can run in parallel. Both are Master-assigned (shared infra config, and the whole change is only two files, so no clone hand-off is warranted).
