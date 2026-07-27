> Ticket: COV-33
> Branch: feature/cov-33-add-honeybadger-error-tracking

# Feature: Honeybadger error tracking and uptime monitoring

## Problem
Nothing reports errors from deployed environments. Staging is live and is the
only environment being pushed to, but when a request 500s there the only way to
find out is to go read Render logs and think to look. Cove needs errors to
arrive without being asked for, and needs to know when staging is down.

## Approach
Enable Honeybadger through the existing Jumpstart integration, wired to the
per-environment encrypted credentials established by COV-31. Free plan, one
project.

**Decided: build on staging now rather than waiting for the production
cutover.** Staging is a deployed environment and is currently unmonitored, and
every acceptance criterion below is verifiable today. Deferring would mean the
first-ever Honeybadger integration goes live *during* the production cutover —
the worst moment to debug it. Doing it now makes production a one-line change
at cutover: paste the same API key into `production.yml.enc`.

Because the free plan is one project, staging and production will eventually
share it, separated by Honeybadger's `env` tag. That costs nothing today
(production doesn't exist). If staging noise becomes a problem later, the
escape hatch is three lines in `config/honeybadger.yml`:

```yaml
staging:
  report_data: false
```

Note also that *installing* Honeybadger and *being alerted by* it are separate
knobs — noise is tuned with per-environment alert rules in the dashboard, not
by declining to install.

### Do NOT run the Jumpstart config generator
The ticket says to run it. Don't. Hand-edit instead.

- `honeybadger?` is auto-defined from the `INTEGRATIONS` hash
  (`lib/jumpstart/lib/jumpstart/configuration.rb:44`) and driven purely by the
  `integrations` array — flipping one value in `config/jumpstart.rb` is all the
  gem needs.
- `Gemfile.jumpstart:55` **already** contains
  `gem "honeybadger" if Jumpstart.config.honeybadger?`. There is no Gemfile
  entry to produce; it has always been there, just switched off.
- `Jumpstart.config.save` would also run `write_config` (rewrites
  `config/jumpstart.rb` through `pretty_inspect`, may reformat/reorder) and
  `update_procfiles`, which **creates a root `Procfile`**. This repo
  deliberately has none — Render uses `startCommand` in `render.yaml`. A stray
  `Procfile` saying `web: bundle exec rails s` would contradict the blueprint.

Only `copy_configs` is wanted, and that is a two-line file copy from
`lib/templates/config/honeybadger.yml`.

### Key storage: credentials, not a Render env var
The ticket says to set the key as a Render env var. Use credentials instead —
it matches the Jumpstart template as shipped and the COV-31 convention where
every third-party secret lives in the encrypted per-env file and Render holds
only `RAILS_MASTER_KEY`. An env var would reintroduce the "secrets in two
places" split COV-31 deliberately removed. Both satisfy "no API key committed."

## Acceptance Criteria
1. A deliberately raised exception on staging appears in Honeybadger within a
   minute.
2. The error is tagged as the staging environment, not production.
3. Uptime check against `/up` is green **and** email alerting is verified by
   observing an actual alert, not just a green check.
4. `bin/rails test` still passes.
5. No API key committed.

## Prototype
None.

## Data Model
No changes.

## Change Set

| # | File | Change |
|---|------|--------|
| 1 | `config/jumpstart.rb:12` | `"integrations" => []` → `["honeybadger"]` |
| 2 | `config/honeybadger.yml` | **New**, committed — contents below |
| 3 | `Gemfile.lock` | From `bundle install`; adds `honeybadger` |
| 4 | `config/initializers/filter_parameter_logging.rb` | `AIDEV-NOTE` only |
| 5 | `config/credentials/staging.yml.enc` | User pastes key (manual) |
| 6 | `test/config/honeybadger_config_test.rb` | **New** — see Test below |

`config/honeybadger.yml` in full — the Jumpstart template plus the PII line:

```yaml
---
api_key: <%= Rails.application.credentials.dig(:honeybadger, :api_key) %>

request:
  disable_session: true
```

Committing this is correct: it holds a credentials *reference*, never a key.
Nothing in `.gitignore` covers it, and nothing should.

### Two acceptance criteria come free
Because COV-31 made the credentials *file* the environment scope,
`dig(:honeybadger, :api_key)` reads `staging.yml.enc` under `RAILS_ENV=staging`
and `production.yml.enc` under production — no env-namespacing inside the YAML.
Honeybadger's `env` defaults to `Rails.env`, so staging errors self-tag as
`staging`. AC #2 and AC #5 need no code.

### PII handling
Honeybadger's `request.filter_keys` **automatically includes Rails'
`filter_parameters`** in a Rails app, so the existing list in
`config/initializers/filter_parameter_logging.rb` (`:email`, `:name`,
`:first_name`, `:last_name`, `:ssn`, `:otp`, tokens, card fields) applies with
zero config.

Add only `request.disable_session: true`. Devise stores `warden.user.user.key`
in the session, containing the user id and a fragment of the encrypted password
digest — near-zero diagnostic value, the one genuinely secret-adjacent thing
captured. Params stay **on**: they are the most useful field in an error report
and are already filtered.

Gap to know about: `filter_parameters` covers identity fields but not
homeschool-domain fields that don't exist yet (`birthdate`, `grade`, `notes`,
`transcript`). When those models land, add them to
`filter_parameter_logging.rb` — one edit fixes both logs and Honeybadger. An
`AIDEV-NOTE` in that initializer records the coupling.

## Screens / Flows — the runbook

`render.yaml` pins `cove-staging` to `branch: main` with `autoDeploy: true`, so
staging only runs what is on main. Left alone, AC #1 could not be verified until
after merge — inverting the review process. **Resolution: temporarily repoint
the Render service at the feature branch**, verify everything, then repoint to
`main`. The boom route lives and dies on the feature branch and never touches
main, and the PR under review is already proven.

Division of labor follows COV-32: Claude drives the browser for Render and
Honeybadger; the user handles signup, 2FA, and anything secret.

### 0. Preconditions
- `RAILS_MASTER_KEY` is already set on `cove-staging` from COV-32, so the
  staging credentials file decrypts on deploy without further work.
- `https://staging.covehomeschool.com/up` currently returns 200.

### 1. Honeybadger account + project
Claude drives; user does signup/2FA. Create one project named `cove`.

**Confirm here whether the free plan includes uptime checks.** This could not
be verified from the docs and must not be assumed. If free excludes uptime,
AC #3 is blocked — stop and raise it. The error-tracking half still ships.

### 2. API key → credentials
Claude navigates to the project's API key page **and stops without
screenshotting it**, so the key stays on the user's screen and out of the
transcript. User copies from screen, then:

```bash
bin/rails credentials:edit --environment staging
```

```yaml
honeybadger:
  api_key: <paste>
```

Commits `staging.yml.enc` as an encrypted blob on the feature branch.

### 3. Code changes + temporary boom route
The change set above, plus one throwaway line in `config/routes.rb`:

```ruby
# TEMPORARY — remove before opening the PR. Verifies COV-33 wiring.
get "dev/boom", to: proc { raise "COV-33 Honeybadger smoke test" } if Rails.env.staging?
```

`Rails.env.staging?` keeps it out of dev, test, and production even while it
exists. It deliberately does **not** go inside the `Rails.env.local?` block at
`config/routes.rb:22` — that block is dev/test only, which is precisely why
staging has no raiseable URL today.

### 4. Deploy the branch
Repoint `cove-staging` (Settings → Build & Deploy → Branch) to
`feature/cov-33-add-honeybadger-error-tracking`. Deploy, watch logs for a clean
boot.

### 5. Verify AC #1 and #2
Hit `https://staging.covehomeschool.com/dev/boom` → 500. Error should appear in
Honeybadger within a minute, tagged `env: staging`.

Use **https** explicitly: `staging.rb` sets `force_ssl = true` with the `/up`
exclusion commented out, so plain http returns a 301 first.

### 6. Uptime check — AC #3
Add a check against `https://staging.covehomeschool.com/up`:

- **Frequency: 5 minutes.** Options are 1, 5, or 15. Render free spins down
  after ~15 min idle, so 5 keeps it warm with margin — 15 races the timeout,
  1 burns quota for no gain.
- **Match type:** success (any 2xx)
- **Validate SSL:** on
- **Email alerts:** on

Confirm green. Then **verify alerting actually fires**: temporarily point the
check at a guaranteed-404 path, confirm the email arrives, set it back. A green
check alone does not prove alerting works.

### 7. Repoint to main and clean up
Switch `cove-staging`'s branch back to `main` and **verify it stuck** — this is
the step most likely to be silently forgotten. Delete the boom route.

### 8. Final gates
`bin/rails test` (AC #4). Then `git diff origin/main...` to confirm the boom
route is gone and the only credentials change is an opaque encrypted blob
(AC #5).

## Test

`test/config/honeybadger_config_test.rb`, following the existing `test/config/`
pattern — plain `Minitest::Test`, no Rails boot, assert on the config file
(`render_blueprint_test.rb` parses YAML; `staging_inline_adapter_test.rb` reads
text).

```ruby
require "minitest/autorun"
require "yaml"

class HoneybadgerConfigTest < Minitest::Test
  def test_error_reports_never_include_session_data
    config = YAML.load_file(File.expand_path("../../config/honeybadger.yml", __dir__))

    assert_equal true, config.fetch("request").fetch("disable_session")
  end

  def test_api_key_is_read_from_credentials_and_never_committed
    config = YAML.load_file(File.expand_path("../../config/honeybadger.yml", __dir__))

    assert_match(/credentials\.dig\(:honeybadger, :api_key\)/, config.fetch("api_key"))
  end

  def test_honeybadger_integration_is_enabled
    jumpstart_config = File.read(File.expand_path("../../config/jumpstart.rb", __dir__))

    assert_match(/"integrations"\s*=>\s*\[[^\]]*"honeybadger"/, jumpstart_config)
  end
end
```

Why each earns its place:

1. Guards the PII decision. The Jumpstart template has **no `request:` block at
   all** — `disable_session` is purely our addition, and anyone regenerating
   that file loses it with no visible signal.
2. AC #5 made enforceable. The realistic failure is someone debugging staging,
   pasting the literal key "just to check," and committing it.
3. The other two **pass on a completely broken install** — if
   `config/jumpstart.rb` reverts to `"integrations" => []` the gem never loads
   and an inert yml still satisfies them. Something must assert the feature is
   switched on.

Deliberately not tested: that `report_data` is false in test, or that `env`
equals `Rails.env`. Both are gem defaults — asserting them tests Honeybadger's
library, not our code.

AC #4 is covered by the full suite run, not these three: adding a gem with a
Rails railtie can perturb unrelated tests. Honeybadger won't fight WebMock —
`report_data` is off in test, so it makes no HTTP calls.

## Edge cases and expected behavior (not bugs — do not chase)
- **Key missing or wrong in staging** → app boots normally, errors silently
  never arrive. Runbook step 5 is the only thing that proves the key is right.
- **Empty `api_key` in dev/test** → expected; `dig` returns nil and
  `report_data` is off. May log a startup notice in dev. Harmless.
- **Staging stops spinning down** once the uptime check pings every 5 minutes.
  That is the bonus side effect, not a fault.
- **After step 7 removes the boom route**, nothing further proves staging still
  reports. Acceptable — removing a route does not change the config — but it is
  why the test above matters more than it looks.

## Scope
**In:** Jumpstart integration flag, `config/honeybadger.yml` with session
disabled, bundle, API key into `staging.yml.enc`, `AIDEV-NOTE` in the filter
initializer, config test, temporary boom route for verification (added and
removed within the branch), uptime check on `/up` with verified email alerting.

**Deferred:** Production key in `production.yml.enc` (one line at cutover),
production uptime check, per-environment alert rules, `staging: report_data:
false` noise suppression, any paid-plan features, APM/performance monitoring,
Honeybadger deploy tracking.

## Open Questions
1. **Does the Honeybadger free plan include uptime checks?** Could not be
   confirmed from the docs. Resolve at runbook step 1. If not, AC #3 is blocked
   and needs a product decision; error tracking still ships.
2. **Does the free plan support per-environment alert rules?** Not required for
   this ticket, but it determines how staging noise gets tuned once production
   shares the project. Check while in the dashboard.

## More Info
- Predecessors in `docs/designs/done/`: `cov-31-split-credentials-per-env.md`,
  `cov-32-provision-render-staging.md`, `render-staging-blueprint.md`.
- Honeybadger config precedence: environment variables override
  `config/honeybadger.yml`. Relevant if a `HONEYBADGER_API_KEY` is ever set on
  Render by accident — it would silently win over credentials.
- `report_data` defaults to true and is disabled automatically for
  development/test/cucumber, which is what keeps AC #4 free.
- Uptime check frequency accepts only 1, 5, or 15 minutes.
- The gem adds one dependency. Already approved by the user; flagged only
  because the project rule is to ask first.
