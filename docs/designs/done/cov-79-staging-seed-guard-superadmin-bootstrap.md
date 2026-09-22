> Ticket: COV-79
> Branch: feature/cov-79-staging-seed-guard-superadmin-bootstrap
> Plan created: docs/plans/cov-79-staging-seed-guard-superadmin-bootstrap.md

# Feature: Staging seed guard and superadmin bootstrap

## Problem

`db/seeds.rb` guards only `production`, and `render.yaml` runs `db:prepare`
with `RAILS_ENV=staging`, so staging was seeded with demo data on 2026-09-09 —
including `superadmin@cove.test`, whose password (`password`) is published in
this repo, on a public host. That seeded account is currently the only way into
staging `/admin`. Render's free tier has no Shell or One-Off Jobs, so
`Jumpstart.grant_system_admin!` can't be run by hand, and resetting staging
without first solving this would lock us out of `/admin/plans` — where real
Plan rows get entered (COV-72, COV-78).

Found during COV-71; full detail in
`docs/designs/done/cov-71-monetization-family-audit.md` (gaps 9, 12, 15).

## Approach

Three code changes plus a manual ops runbook.

**1. Narrow the seed guard.** `db/seeds.rb:5` — `unless Rails.env.production?`
becomes `if Rails.env.local?`, so demo users are development/test only and
never reach staging or production again. Closes gaps 9 and 15.

**2. Idempotent bootstrap service + thin rake task.** Logic lives in a PORO at
`app/services/admin_bootstrap.rb`, following the existing
`LoopsContactSynchronizer` pattern (`app/services/` with a matching
`test/services/` test). `lib/tasks/admin.rake` is a thin wrapper that reads the
env vars and delegates:

```ruby
namespace :admin do
  desc "Creates the system admin named by BOOTSTRAP_ADMIN_EMAIL. Idempotent; no-ops when unset."
  task bootstrap: :environment do
    AdminBootstrap.call(email: ENV["BOOTSTRAP_ADMIN_EMAIL"], name: ENV["BOOTSTRAP_ADMIN_NAME"])
  end
end
```

The service takes parameters rather than reading `ENV` itself so it is
trivially testable with no `ENV` mutation, and so the rake task's one job — env
wiring — gets its own small test. That test matters more than usual here: a
typo in the task name cannot be caught by consoling into staging.

`AdminBootstrap.call(email:, name:)` does, in order:

1. Email blank → log `skipped: BOOTSTRAP_ADMIN_EMAIL unset` and return. This is
   the default in development and test, so nothing changes locally.
2. `User.find_by(email:)` (emails are normalized to stripped-downcase by
   `User::Authenticatable`). If found: do **not** touch the password, name, or
   marketing-consent fields.
3. Not found → create with `password: Devise.friendly_token(32)`,
   `terms_of_service: "1"` (required on create by `User::Agreements`),
   `confirmed_at: Time.current`, and `first_name`/`last_name` split from
   `BOOTSTRAP_ADMIN_NAME`, defaulting to `"Cove Admin"`. `User` validates
   `name` presence, so a name is mandatory. The generated password is never
   logged, returned, or persisted anywhere but the encrypted column.
4. `Jumpstart.grant_system_admin!(user) unless user.admin?` — raw SQL under the
   hood, because `admin` is `attr_readonly` on `User`.
5. The whole body is wrapped in `rescue StandardError` → log at error level and
   return normally, so the process exits 0 and `rails server` still starts.

**Why rescue instead of failing the deploy:** the task runs inside
`startCommand`, chained with `&&`. A raise means the web service never boots,
and the free tier has no console to recover from. A broken bootstrap should
degrade to "no admin yet" rather than "staging is down."

Log lines go to both `puts` and `Rails.logger` so they appear in Render's
deploy log. That output is the verification gate between runbook steps 2 and 3.

**3. Wire into `render.yaml`.** Staging `startCommand` becomes:

```
bundle exec rails db:prepare admin:bootstrap && bundle exec rails server
```

One `rails` invocation rather than two chained ones — one fewer full app boot,
which matters on a 512MB free instance. The commented-out production block gets
the same task appended to its `preDeployCommand`, so COV-78 only has to set one
variable.

## Acceptance Criteria

- `db/seeds.rb` no longer runs outside development and test
- Bootstrap task is idempotent across repeated boots — covered by a test
- Task no-ops when `BOOTSTRAP_ADMIN_EMAIL` is unset
- Staging database reset with no demo users or demo accounts present
- Exactly one system admin exists on staging, on a real address
- That admin can reach `/admin/plans` after a password reset
- No credentials committed to the repo

## Prototype

None.

## Data Model

No migrations, no new tables. Touches existing `User` rows only:
`email`, `first_name`, `last_name`, `encrypted_password`, `confirmed_at`, and
the `admin` boolean (via `Jumpstart.grant_system_admin!`).

Creating the user fires two existing `User` callbacks, both accepted:

- `create_default_account` → a personal account for the admin. Harmless; the
  app layout expects one.
- `after_create_commit :send_account_created_email` → the Loops
  `account_created` transactional email. Deliberately left to fire: it
  doubles as a live proof that staging → Loops delivery works, which the
  password-reset step depends on anyway. Staging uses the `:async` queue
  adapter, so it really sends.

Marketing consent is left untouched — `marketing_opt_in` is never set, so no
Loops contact opt-in job is enqueued.

## Screens / Flows

No UI. The only human-facing flow is the operator runbook below, ending at the
app's existing "Forgot password" flow and `/admin/plans`.

## Scope

**In:**

- `db/seeds.rb` guard narrowed to `if Rails.env.local?`
- `app/services/admin_bootstrap.rb` + `test/services/admin_bootstrap_test.rb`
- `lib/tasks/admin.rake` + `test/tasks/admin_test.rb`
- `render.yaml`: staging `startCommand`, and the dormant production
  `preDeployCommand`
- Operator runbook (below) for the Render env vars, the staging reset, and
  claiming the account

**Deferred:**

- Configuring or deploying production — COV-78. The task is written
  env-var-driven so COV-78 reuses it by setting one variable.
- Entering real Plan rows — COV-72 / COV-78.
- A boot-time guard asserting the expected Stripe account id in staging
  (COV-71 deferred list).

## Tests

Fixtures-only Minitest, per AGENTS.md. No new gems.

`test/services/admin_bootstrap_test.rb`:

- no-ops when no email is given
- creates a system admin for the given email
- running twice creates no duplicate user and leaves the password untouched
  (the idempotency acceptance criterion)
- grants admin to an existing non-admin user without touching their password
  or name
- leaves an already-admin user alone
- logs and does not raise when the email is invalid

`test/tasks/admin_test.rb` (pattern: `test/tasks/loops_contacts_test.rb`):

- the task passes `BOOTSTRAP_ADMIN_EMAIL` through to the service
- the task no-ops when the env var is unset

## Operator runbook (steps 4–6, run by Jordan)

Sequence matters: steps 1–3 of Scope ship as one deploy and the task is
verified to have run **before** the reset, so a broken bootstrap surfaces while
the old seeded admin still exists.

1. Merge and deploy steps 1–3 to `main`. In Render staging env vars, add
   `BOOTSTRAP_ADMIN_EMAIL` (and optionally `BOOTSTRAP_ADMIN_NAME`). Confirm
   that address is in `STAGING_EMAIL_RECIPIENT_ALLOWLIST` **before** this
   deploy, or the account-created email is dropped and the free deliverability
   check is lost.
2. Verify in Render's deploy log that `[admin:bootstrap]` logged a
   create-and-grant. `superadmin@cove.test` still exists at this point — that
   is deliberate. If the log line is missing or errored, **stop** and fix
   before step 3.
3. Reset the database, redeploy, and confirm the `[admin:bootstrap]` log line
   again on a virgin database.
4. Claim the account via "Forgot password", sign in, confirm `/admin/plans`
   loads and that no `*@cove.test` users appear under `/admin/users`.

Note that Render's masked env-var editor doesn't reliably confirm a saved
value — verify via observable app behavior (the deploy log line), not the
editor UI. After the reset, staging has no Plan rows, so the pricing page will
be empty until COV-72/COV-78 enter real ones. That is expected, not a
regression.

## Open Questions

- **How to reset the Render free-tier database.** Recreating
  `cove-staging-db` in the dashboard reissues its connection string; the
  service's `DATABASE_URL` is `fromDatabase:`, which should relink on blueprint
  sync, but this has not been verified against Render's actual behavior. The
  alternative — a throwaway commit putting `db:drop db:create` in
  `startCommand` — is worse, because `autoDeploy: true` means any later deploy
  landing on that commit wipes staging again. Recommendation: recreate the
  database in the dashboard and watch the relink. Decide at execution time.

## More Info

From COV-71 (`docs/designs/done/cov-71-monetization-family-audit.md`):

- Staging data is disposable — entirely seed data plus two duplicate Jordan
  logins, no real Stripe activity, and the only Plan row has no Stripe ID.
  Reset, don't convert.
- Do **not** store an admin password in Render env vars. Random password plus
  password reset is the intended path.
- Render free tier: no Shell, no One-Off Jobs, no `preDeployCommand`.
  `startCommand` is the only available hook.
- `User` does not include Devise `:confirmable` despite the `confirmed_at`
  column; `user.confirmed?` is not a valid method. `confirmed_at` is set on the
  bootstrapped user for parity with seeds only.
