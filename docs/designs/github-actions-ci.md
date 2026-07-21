> Ticket: COV-29
> Branch: feature/cov-29-github-actions-ci

# Feature: GitHub Actions CI + branch protection on `main`

## Problem
`.github/` is empty, so nothing runs on pull requests. Every check the project
cares about lives in `config/ci.rb` and only executes when someone remembers to
type `bin/ci` locally. A PR can be merged into `main` with failing tests, a
RuboCop violation, or a Brakeman warning and nothing stops it.

## Approach
Add a single workflow, `.github/workflows/ci.yml`, that mirrors the steps in
`config/ci.rb` but splits them into **five independent parallel jobs** —
`lint`, `security`, `test`, `system`, `seeds` — so a lint failure reports in
about a minute instead of after the full suite. Then protect `main` so merging
requires a PR with all five checks green.

`config/ci.rb` and `bin/ci` are **not touched**. They remain the local path and
the source of truth for what "all checks" means; the workflow mirrors them.

Job granularity was the main design axis. Three options were considered:

1. **One job running `bin/ci`.** Perfect fidelity, ~8 lines — but a typo costs
   the full ~10-minute suite before it reports, and `bin/ci`'s first step is
   `bin/setup`, which is a local dev script (Homebrew, dev DB, `exec bin/dev`).
   Rejected.
2. **Five parallel self-contained jobs.** ~15 lines of near-identical setup per
   job. Shallow duplication, fast feedback, and the shape of every Rails CI
   including Rails' own generated template. **Chosen.**
3. **Five jobs plus a composite setup action and a sharded test matrix.**
   Deduplicates setup and splits the suite across runners. Saves maybe two
   minutes on 86 test files while adding a second file and matrix bookkeeping.
   That's the right answer at 500 test files, not here. Deferred.

Ordering of favored solutions: this is pure infrastructure — no new gems, no app
code, no models. It leans on Rails 8 built-ins (`db:test:prepare`,
`db:seed:replant`, the `test:prepare` hook) and the existing `bin/*` wrappers.

## Acceptance Criteria
- [ ] Opening a PR against `main` triggers all five jobs
- [ ] A deliberate RuboCop violation fails `lint` and blocks merge
- [ ] A deliberate failing test fails `test` and blocks merge
- [ ] A system test failure uploads `tmp/screenshots/` as a downloadable artifact
- [ ] `main` rejects direct pushes; merge requires a green PR
- [ ] `bin/ci` still runs clean locally

## Prototype
None.

## Data Model
No models, migrations, or schema changes. One new file:
`.github/workflows/ci.yml`.

## Screens / Flows
No UI. The developer-facing flow:

1. Developer pushes a branch and opens a PR against `main`.
2. All five jobs start in parallel. `lint` reports in ~1 min, `security` ~2 min,
   `seeds` ~2 min, `test` and `system` ~5 min.
3. Any red job blocks the merge button. RuboCop offenses appear as inline
   annotations on the PR diff (`-f github`). A system-test failure attaches a
   `screenshots` artifact to the run.
4. All green → developer merges. `main` re-runs the same five jobs on push.

## Workflow Design

### Shared header

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
env:
  RAILS_MASTER_KEY: ${{ secrets.RAILS_MASTER_KEY }}
```

Every job is `runs-on: ubuntu-latest` and begins with `actions/checkout@v6`
plus `ruby/setup-ruby@v1` using `ruby-version-file: .ruby-version` (never a
hardcoded version) and `bundler-cache: true`.

**No path filters, deliberately.** Every PR runs all five jobs even for a README
typo, because a required status check that never runs blocks a PR permanently.

### Jobs

| Job | Command(s) | Postgres? |
|---|---|---|
| `lint` | `bin/rubocop -f github` | no |
| `security` | `bin/bundler-audit`, `bin/importmap audit`, `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` | no |
| `test` | `bin/rails db:test:prepare`, `bin/rails test` | yes |
| `system` | `bin/rails db:test:prepare`, `bin/rails test:system` | yes |
| `seeds` | `bin/rails db:test:prepare`, `bin/rails db:seed:replant` | yes |

Job ids are also the required-status-check names — they must match the strings
selected in branch protection exactly.

`security` runs its three steps sequentially, so the first failure hides the
others. Acceptable at this size.

`-f github` on RuboCop is a formatter change only: same rules, same pass/fail
as `bin/ci`, but violations render as inline PR annotations.

### Postgres service (jobs `test`, `system`, `seeds`)

```yaml
services:
  postgres:
    image: postgres:17
    env: { POSTGRES_USER: postgres, POSTGRES_PASSWORD: postgres }
    ports: ["5432:5432"]
    options: >-
      --health-cmd=pg_isready --health-interval=10s
      --health-timeout=5s --health-retries=3
env: { DB_HOST: localhost, RAILS_ENV: test }
```

`DB_HOST=localhost` is what flips `config/database.yml` (the
`<% if ENV["DB_HOST"] %>` block) to host/username/password `postgres`, matching
the container credentials. The image is pinned to a major so a new Postgres
release can't change CI behavior underneath us.

Because `RAILS_ENV: test` is set at job level, the `env RAILS_ENV=test` prefix
used by `config/ci.rb` for the seeds step is not repeated in the workflow.

### System-test screenshots

Final step of the `system` job:

```yaml
- uses: actions/upload-artifact@v4
  if: failure()
  with:
    name: screenshots
    path: tmp/screenshots
    if-no-files-found: ignore
```

Rails' system-test screenshot helper writes `tmp/screenshots/` on failure; this
step collects it. `if-no-files-found: ignore` keeps a non-screenshot failure
(e.g. a boot error) from adding a second confusing red X.

## Findings That Shaped This Design

Verified against the codebase, not assumed:

- **`RAILS_MASTER_KEY` is the correct variable name.** Rails resolves
  `config/credentials/test.yml.enc` with key path `config/credentials/test.key`,
  but the ENV fallback is hardcoded to `RAILS_MASTER_KEY` regardless of
  environment (`railties-8.1.3/lib/rails/application.rb:516`). Combined with
  `config.require_master_key = true` in `config/environments/test.rb`, the key
  is mandatory for every Rails-booting job. It is set at **workflow level** for
  all five jobs rather than per-job, because `bin/importmap` also loads
  `config/application`.
- **Everything in `test.yml.enc` is a dummy value** — empty strings, `test...`
  placeholders for Google OAuth, and a test-only `secret_key_base` and
  ActiveRecord encryption keys. Committing `test.key` was therefore a defensible
  option, but was rejected to preserve the "no keys in git" invariant that
  `.gitignore` (`/config/credentials/*.key`) already enforces. The key goes in
  as a repo secret instead.
- **No Tailwind build step is needed.** `app/assets/builds/*` is gitignored, but
  `bin/rails test` and `bin/rails test:system` both invoke `test:prepare`
  (`railties-8.1.3/lib/rails/commands/test/test_command.rb`, `run_prepare_task`),
  which tailwindcss-rails enhances with `tailwindcss:build`
  (`tailwindcss-rails-4.6.0/lib/tasks/build.rake:39`). The workflow carries an
  `AIDEV-NOTE` recording this, because the absent step otherwise looks like a bug.
- **No apt packages are needed.** Both `pg (1.6.3-x86_64-linux)` and
  `tailwindcss-ruby (4.3.1-x86_64-linux-gnu)` are precompiled in `Gemfile.lock`,
  and `PLATFORMS` already includes `x86_64-linux`. No `libpq-dev` step, no
  lockfile change.
- **No `setup-chrome` action is needed.** `ubuntu-latest` ships Chrome and
  chromedriver, and Selenium Manager in selenium-webdriver 4.45 resolves them.
  `ApplicationSystemTestCase` falls through to the local `headless_chrome`
  branch because `CAPYBARA_SERVER_PORT` is unset in CI.
- **CI eager-loads the app; local `bin/ci` does not.** `config/environments/test.rb`
  sets `config.eager_load = ENV["CI"].present?`, and GitHub Actions sets
  `CI=true`. This is desirable — it catches load errors before deploy — but the
  first CI run may surface latent failures that have never appeared locally.
  Expect to fix these on the feature PR itself.
- **`bin/brakeman` prepends `--ensure-latest`**, which queries rubygems and
  fails when the locked Brakeman is behind the newest release. A Brakeman
  release unrelated to this codebase can therefore turn `security` red and block
  merges until `bundle update brakeman`. Kept as-is for fidelity: local `bin/ci`
  fails identically today, and diverging would make CI and local disagree.
- **Parallel tests fan out automatically.** `test_helper.rb` sets
  `parallelize(workers: :number_of_processors)`, so the runner's 4 cores produce
  4 worker databases. Rails handles their creation; no extra CI configuration.
- **Local baseline is green**: 360 runs, 1023 assertions, 0 failures, 0 errors,
  0 skips on this branch before any changes.

## Branch Protection

The ordering constraint: GitHub cannot offer a status check as "required" until
it has seen that check report at least once. Protection is therefore enabled
**after** the workflow merges to `main`, not alongside it.

Settings → Branches → *Add classic branch protection rule* (GitHub's UI now
leads with Rulesets; classic is one click deeper and has fewer knobs):

- Branch name pattern: `main`
- ✅ Require a pull request before merging — "Require approvals" **unchecked**
  (0 approvals) so the solo maintainer can merge their own PRs
- ✅ Require status checks to pass before merging → add all five:
  `lint`, `security`, `test`, `system`, `seeds`
- ❌ Require branches to be up to date before merging. On a solo repo this
  forces a rebase and full re-run every time `main` moves. Accepted tradeoff:
  two individually-green PRs can merge into a broken `main` via semantic
  conflict; the `push: [main]` trigger catches that within minutes.
- ❌ Require conversation resolution / signed commits / linear history — none
  serve this ticket
- ✅ **Do not allow bypassing the above settings** — no admin bypass. This is
  what makes "main rejects direct pushes" literally true for the repo owner.
- Force pushes and deletions remain disallowed (defaults)

## Rollout Order

1. **Owner adds the secret** (manual, before the first push): Settings →
   Secrets and variables → Actions → New repository secret, name
   `RAILS_MASTER_KEY`, value = the 32 characters in
   `config/credentials/test.key`. Without this, `test`/`system`/`seeds` die at
   boot on `require_master_key`.
2. Branch `feature/cov-29-github-actions-ci` (identifier embedded so Linear
   auto-links the branch and PR).
3. Add `.github/workflows/ci.yml`, push, open the PR. All five jobs run.
   Iterate here until green — this is where the Chrome and eager-load
   assumptions get tested for real.
4. Owner reviews and merges. Direct merge works; `main` is still unprotected.
5. **Owner enables branch protection** in the GitHub UI. The five check names
   are now selectable.
6. Proof PR (below), then cleanup.

## Verification

| Acceptance criterion | How it is proven |
|---|---|
| PR triggers all five jobs | Observed on the feature PR at step 3 |
| RuboCop violation blocks merge | Proof PR |
| Failing test blocks merge | Proof PR |
| System failure uploads screenshots | Proof PR |
| `main` rejects direct pushes | Attempt a real `git push origin main` after step 5 and confirm it is refused server-side (nothing lands) |
| `bin/ci` still runs clean | Run locally on merged `main`; `config/ci.rb` and `bin/ci` are untouched |

**The proof PR** is one throwaway branch carrying three deliberate breaks: a
RuboCop offense, a failing assertion in an existing model test, and a failing
assertion in an existing system test placed *after* page load so a screenshot is
actually captured. Confirm `lint`/`test`/`system` go red, the merge button is
blocked, and the `screenshots` artifact is downloadable from the run — then
close the PR unmerged and delete the branch. Nothing from it reaches `main`.

## Scope
**In:** One new file, `.github/workflows/ci.yml`, with five parallel jobs.
Branch protection on `main` (applied by the owner in the GitHub UI). A
throwaway proof PR to verify the failure-path criteria.

**Deferred:**
- Composite setup action to deduplicate checkout/setup-ruby
- Sharded test matrix across multiple runners
- RuboCop result cache (`actions/cache` on `RUBOCOP_CACHE_ROOT`) — RuboCop
  finishes in seconds here; the cache would be the slower half of the job
- Dependabot configuration
- Deploy / CD workflows
- `gh signoff` (the commented-out block at the end of `config/ci.rb`)
- Auto-delete merged branches
- Path filters on workflow triggers

## Open Questions
None.
