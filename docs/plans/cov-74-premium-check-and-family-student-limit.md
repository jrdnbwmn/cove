> Ticket: COV-74
> Branch: feature/cov-74-premium-check-and-family-student-limit

# Plan: Premium Check and Family Student Limit

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add the persisted Premium student limit | Master | |
| 2 | 1 | 1 | Add valid family fixtures for subscription states | subagent | |
| 3 | 1 | 1 | Add isolated Pay subscription-state fixtures | subagent | |
| 4 | 2 | 2 | Implement the Account Premium and student-limit rules | Master | |
| 5 | 3 | 3 | Add the reusable Premium controller gate | Master | |
| 6 | 3 | 3 | Expose student limits in Madmin | subagent | |
| 7 | 3 | 3 | Run final review and verification gates | Master | |

## Prerequisites

- Design: `docs/designs/cov-74-premium-check-and-family-student-limit.md`
- Prototype: None
- Feature branch exists: `feature/cov-74-premium-check-and-family-student-limit`
- Before Rails commands, prepend `/Users/jordan/.local/share/mise/shims` to `PATH` and confirm `ruby -v` reports Ruby 4.0.5.

## Tasks

### Task 1 [Master]: Add the persisted Premium student limit

**Skills:** safe-migration, write-tests
**Reference:** Read `db/migrate/20260916210158_enforce_family_account_constraints.rb`, `test/migrations/add_signup_completion_required_to_users_test.rb`, and the `accounts` table in `db/schema.rb` for patterns to follow.

**In scope:**

- Add `accounts.student_limit` as an integer with database default `10` and `null: false`.
- Verify a new and existing family receives the default.
- Preserve only the genuine `student_limit` schema change after migration checks.

**NOT in scope:**

- A database check constraint, data backfill, Account validation, or Premium methods.
- Unrelated schema-dump reordering or Rails schema-version changes.

**Build order:**

1. **Test:** Add `test/migrations/add_student_limit_to_accounts_test.rb`; assert the column is integer, non-null, defaults to `10`, and `accounts(:one)` reads `10`.
2. **Implement:** Run `bin/rails generate migration AddStudentLimitToAccounts student_limit:integer`, then configure the generated `db/migrate/*_add_student_limit_to_accounts.rb` with `default: 10, null: false`.
3. **Verify:** Run `bin/rails db:migrate`, `bin/rails db:rollback:primary STEP=1`, and `bin/rails db:migrate`; then run `bin/rails test test/migrations/add_student_limit_to_accounts_test.rb`. Inspect all four schema dumps and restore `db/cable_schema.rb`, `db/cache_schema.rb`, and `db/queue_schema.rb` if their only changes are known generator noise.

### Task 2 [subagent]: Add valid family fixtures for subscription states

**Skills:** write-tests
**Reference:** Read `test/fixtures/users.yml`, `test/fixtures/accounts.yml`, and `test/fixtures/account_users.yml`.

**In scope:**

- Add matching `past_due`, `unpaid`, `paused`, `canceled_in_period`, `canceled_ended`, and `old_price` fixture families.
- Give each family its own hand-written user and one admin membership.
- Keep every account non-personal with `account_users_count: 1`.

**NOT in scope:**

- Pay customers, subscriptions, Premium behavior, or explicit `student_limit` values.
- Reusing an existing user across families, which would violate the one-family membership constraint.

**Build order:**

1. **Test:** Treat the new records as test support; first add them to `test/fixtures/users.yml`, `test/fixtures/accounts.yml`, and `test/fixtures/account_users.yml` with consistent labels and associations.
2. **Implement:** Ensure every state family's owner is also its sole admin parent and let the database default provide `student_limit: 10`.
3. **Verify:** Run `bin/rails test test/models/account_test.rb` to force fixture loading and constraint validation.

### Task 3 [subagent]: Add isolated Pay subscription-state fixtures

**Skills:** write-tests
**Reference:** Read `test/fixtures/pay/customers.yml`, `test/fixtures/pay/subscriptions.yml`, and the existing `premium_monthly`, `premium_yearly`, and `hidden` records in `test/fixtures/plans.yml`.

**In scope:**

- Add one fake-processor customer and subscription for every Task 2 state family.
- Represent `canceled_in_period` as `status: active` with a future `ends_at`.
- Represent `canceled_ended` with a past `ends_at`; keep `past_due`, `unpaid`, and `paused` as distinct statuses.
- Point `old_price.processor_plan` at the existing hidden plan's identifier.

**NOT in scope:**

- Adding or repricing Plan records.
- Using `status: canceled` for the future-period fixture; Pay's `active` scope would incorrectly make that family Free.

**Build order:**

1. **Test:** Add the isolated fixture graph in `test/fixtures/pay/customers.yml` and `test/fixtures/pay/subscriptions.yml`; behavior assertions follow in Task 4.
2. **Implement:** Use unique processor IDs, `quantity: 1`, and the existing fixture labels. Use `status: active` plus future `ends_at` for cancellation during the paid period.
3. **Verify:** Run `bin/rails test test/models/account_test.rb`. After Tasks 1–3 are complete, run `/prompts:review-changes-mini` exactly once for checkpoint 1.

### Task 4 [Master]: Implement the Account Premium and student-limit rules

**Skills:** write-tests
**Reference:** Read `app/models/account.rb`, especially the private `billable_subscriptions`, and `test/models/account_test.rb`.

**In scope:**

- Add `FREE_STUDENT_LIMIT = 1`.
- Validate `student_limit` as an integer greater than or equal to one.
- Add public `premium?`, `free?`, and `students_allowed`.
- Reuse `billable_subscriptions.exists?` so Premium includes active and `past_due` subscriptions.
- Add the two design-required `# AIDEV-NOTE:` explanations.

**NOT in scope:**

- Checking price, plan name, interval, amount, or Stripe ID to determine Premium.
- Complimentary Premium, student enforcement, caching, Loops synchronization, or changes to Pay's `subscribed?`.

**Build order:**

1. **Test:** Extend `test/models/account_test.rb` first for Free defaults; monthly and yearly Premium; raised limit retained through downgrade; future and ended cancellations; `past_due`, `unpaid`, and `paused`; hidden old-price Premium; and rejection of blank, zero, negative, and decimal limits. Explicitly prove the old-price subscription references a hidden Plan.
2. **Implement:** Update `app/models/account.rb` with the constant, validation, public methods, and required notes while keeping `billable_subscriptions` private and unchanged.
3. **Verify:** Run `bin/rails test test/models/account_test.rb`. Then run `/prompts:review-changes-mini` exactly once for checkpoint 2, which contains only Task 4.

### Task 5 [Master]: Add the reusable Premium controller gate

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/concerns/accounts/subscription_status.rb`, `app/controllers/application_controller.rb`, `test/integration/layouts_test.rb`, and `test/integration/inline_alert_consistency_test.rb`.

**In scope:**

- Add `app/controllers/concerns/premium_access.rb`.
- Expose `premium?` as a view helper and make signed-out/no-family access safely return false.
- Add `require_premium!`, redirecting Free users to pricing with the specified notice.
- Include `PremiumAccess` in `ApplicationController` and add `premium_access.required` to `config/locales/en.yml`.

**NOT in scope:**

- Gating a production feature, adding production routes, or changing `Accounts::SubscriptionStatus`.
- Pundit policies, a reusable Premium notice component, or custom pricing behavior.

**Build order:**

1. **Test:** Add `test/integration/premium_access_test.rb` with a test-only controller. Use `with_routing` to define both the guarded route and a named `pricing` route. Assert a Free user is redirected with the notice, a Premium user succeeds, and the helper safely reports false when signed out.
2. **Implement:** Add `PremiumAccess`, include it between `Pagination` and `SetCurrentRequestDetails`, and add the exact copy: “That's a Premium feature. Upgrade to unlock it.”
3. **Verify:** Run `bin/rails test test/integration/premium_access_test.rb`.

### Task 6 [subagent]: Expose student limits in Madmin

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/madmin/resources/account_resource.rb` and `test/integration/madmin/plans_test.rb`.

**In scope:**

- Add `attribute :student_limit, index: false` immediately after `billing_email`.
- Verify the standard Madmin number field appears on edit, the value appears on show, and it is absent from the index.
- Verify a superadmin can save `14` and an invalid update returns validation errors without changing the stored value.

**NOT in scope:**

- A custom Madmin controller, view, field type, component, or admin-index badge.
- Duplicating all model validation cases in the integration test.

**Build order:**

1. **Test:** Add `test/integration/madmin/accounts_test.rb`; sign in `users(:admin)` and cover edit/show/index visibility, a successful update to `14`, and one representative rejected update.
2. **Implement:** Update `lib/jumpstart/app/madmin/resources/account_resource.rb`. The component-catalog scan confirms no new component is needed because Madmin supplies the standard form and error UI.
3. **Verify:** Run `bin/rails test test/integration/madmin/accounts_test.rb`.

### Task 7 [Master]: Run final review and verification gates

**Skills:** review-changes-mini
**Reference:** Read the completed checkpoint diff and the testing requirements in `AGENTS.md`.

**In scope:**

- Review the complete COV-74 diff for acceptance-criteria coverage, fixture integrity, migration safety, debug artifacts, secrets, and scope creep.
- Run focused and full Rails verification with Ruby 4.0.5.
- Confirm the final diff contains only COV-74 changes.

**NOT in scope:**

- New features, refactors, commits, PR creation, deployment, or staging verification.
- Changes to architecture documentation not requested by the approved design.

**Build order:**

1. **Test:** Run `bin/rails test test/migrations/add_student_limit_to_accounts_test.rb test/models/account_test.rb test/integration/premium_access_test.rb test/integration/madmin/accounts_test.rb`.
2. **Implement:** Inspect `git diff` and return any issue to its owning task; make no additional product changes unless required to satisfy the approved design or tests.
3. **Verify:** Run `bin/rails db:migrate:status`, `bin/rails test`, `bin/rubocop`, `git diff --check`, `git diff origin/main...`, and `git status --short`. Run `/prompts:review-changes-mini` exactly once for checkpoint 3 after Tasks 5–7 are complete. Because Tasks 5 and 6 may run in parallel, the Master runs this review only after both have returned; if review fixes are required, rerun the affected focused test and all final gates.

## Task Dependencies

- Task 2 depends on Task 1 so fixture inserts receive the database default.
- Task 3 depends on Task 2 because its Pay customers reference the new family fixtures.
- Task 4 depends on Tasks 1 and 3 for the column and complete subscription-state matrix.
- Tasks 5 and 6 both depend on Task 4 and can run in parallel.
- Task 7 depends on Tasks 5 and 6.
- No new design-system component is required.
