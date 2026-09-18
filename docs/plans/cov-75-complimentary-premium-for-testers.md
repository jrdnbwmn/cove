> Ticket: COV-75
> Branch: feature/cov-75-complimentary-premium-for-testers

# Plan: Complimentary Premium for Testers

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add complimentary Premium columns and document the data model | Master | |
| 2 | 1 | 1 | Add a representative complimentary family fixture | subagent | |
| 3 | 1 | 1 | Implement and test complimentary Premium entitlement behavior | Master | |
| 4 | 2 | 2 | Expose and secure complimentary Premium administration | subagent | |
| 5 | 2 | 2 | Prove complimentary families can enter checkout | subagent | |
| 6 | 2 | 2 | Seed an idempotent complimentary tester family | subagent | |

## Prerequisites

- Design: [`docs/designs/cov-75-complimentary-premium-for-testers.md`](../designs/cov-75-complimentary-premium-for-testers.md)
- Prototype: None
- Feature branch exists: `feature/cov-75-complimentary-premium-for-testers`
- Use Ruby 4.0.5 by prepending `/Users/jordan/.local/share/mise/shims` to `PATH` for Rails commands.
- The component catalog was checked. This feature uses Madmin's built-in boolean and string fields and needs no new ViewComponent.

## Tasks

### Task 1 [Master]: Add the complimentary Premium data contract

**Skills:** safe-migration, write-tests
**Reference:** Read [`db/migrate/20260918215009_add_student_limit_to_accounts.rb`](../../db/migrate/20260918215009_add_student_limit_to_accounts.rb), [`test/migrations/add_student_limit_to_accounts_test.rb`](../../test/migrations/add_student_limit_to_accounts_test.rb), and [`docs/architecture/data-model.mermaid`](../../docs/architecture/data-model.mermaid) for migration, schema-test, and diagram conventions.

**In scope:**

- Generate `AddComplimentaryPremiumToAccounts` with Rails.
- Add `accounts.complimentary_premium`, boolean, default `false`, `null: false`.
- Add nullable string `accounts.complimentary_premium_note`.
- Add a migration test that verifies both column types, the boolean default/null constraint, and the note's nullability.
- Update `db/schema.rb` with only the two intended account-column additions.
- Add both fields to the `ACCOUNT` entity in `docs/architecture/data-model.mermaid`.

**NOT in scope:**

- Backfilling existing accounts.
- Adding indexes or database constraints for the conditional note requirement.
- Changing account behavior, admin resources, or seeds.
- Committing schema-dump reordering or Rails schema-version noise.

**Build order:**

1. **Test:** Create `test/migrations/add_complimentary_premium_to_accounts_test.rb`; assert the boolean and string column contracts before generating the migration.
2. **Implement:** Run `bin/rails generate migration AddComplimentaryPremiumToAccounts complimentary_premium:boolean complimentary_premium_note:string`, then edit the generated migration to set `default: false, null: false` on the boolean. Run `db:migrate`, `db:rollback`, and `db:migrate`; retain only the intended changes in `db/schema.rb`. Update `docs/architecture/data-model.mermaid`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/migrations/add_complimentary_premium_to_accounts_test.rb`

### Task 2 [subagent]: Add a complimentary family fixture

**Skills:** write-tests
**Reference:** Read [`test/fixtures/users.yml`](../../test/fixtures/users.yml), [`test/fixtures/accounts.yml`](../../test/fixtures/accounts.yml), and [`test/fixtures/account_users.yml`](../../test/fixtures/account_users.yml) for literal fixture and association conventions.

**In scope:**

- Add a dedicated `complimentary` user fixture so existing users do not gain a family unexpectedly.
- Add a `complimentary` account fixture with the comp enabled, a nonblank note, no Pay customer, and the standard student limit.
- Add an admin `account_users` membership connecting the dedicated user and family.
- Use fixture labels for every association.

**NOT in scope:**

- Adding Pay customer or subscription fixtures.
- Adding `personal: true` data.
- Reusing a user whose account membership is significant to an existing test.
- Adding application behavior or assertions owned by Task 3.

**Build order:**

1. **Test:** Treat fixture loading as the setup check; no new behavior assertion belongs in this data-only task.
2. **Implement:** Update `test/fixtures/users.yml`, `test/fixtures/accounts.yml`, and `test/fixtures/account_users.yml` with the three matching `complimentary` records.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/models/account_test.rb`

### Task 3 [Master]: Implement complimentary Premium entitlement behavior

**Skills:** write-tests
**Reference:** Read [`app/models/account.rb`](../../app/models/account.rb), [`test/models/account_test.rb`](../../test/models/account_test.rb), and the state table in the approved design.

**In scope:**

- Require a nonblank, non-whitespace `complimentary_premium_note` whenever the comp flag is on.
- Make `premium?` return true for a comp before querying billable subscriptions.
- Add `plan_status`, with paid subscription precedence: `premium`, then `complimentary`, then `free`.
- Preserve existing `free?`, `students_allowed`, and billable-subscription definitions.
- Add the two required `# AIDEV-NOTE:` explanations from the design.
- Test comp-only, free, comp-plus-paid, revoke, retained-note, validation, student-limit, plan-status, and absence of Pay records.

**NOT in scope:**

- Creating fake Pay subscriptions for comped families.
- Expiry dates, downgrade enforcement, family-merge restrictions, or Loops synchronization.
- Changing subscription status rules established by COV-74.
- Parent-facing billing or pricing display changes.

**Build order:**

1. **Test:** Extend `test/models/account_test.rb` with user-facing tests proving:
   - the complimentary fixture is Premium, gets its full student limit, reports `complimentary`, and has no Pay customers or subscriptions;
   - disabling its comp preserves the note and returns it to Free with one allowed student;
   - blank and whitespace notes prevent enabling the comp;
   - a normal unsubscribed family reports `free`;
   - enabling the comp on the subscribed fixture still reports `premium`, and disabling the comp leaves paid Premium access intact.
2. **Implement:** Update `app/models/account.rb` with the conditional validation, comp-aware `premium?`, paid-first `plan_status`, and required explanatory comments.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/models/account_test.rb`
4. **Checkpoint review:** After Tasks 1–3 are complete, run `review-changes-mini` exactly once for checkpoint 1. If any tasks were executed as a parallel batch, the master runs the review only after the full batch returns.

## Phase 2: Operator Controls and Regression Coverage

### Task 4 [subagent]: Expose and secure complimentary Premium administration

**Skills:** write-tests
**Reference:** Read [`lib/jumpstart/app/madmin/resources/account_resource.rb`](../../lib/jumpstart/app/madmin/resources/account_resource.rb), [`test/integration/madmin/accounts_test.rb`](../../test/integration/madmin/accounts_test.rb), [`app/controllers/accounts_controller.rb`](../../app/controllers/accounts_controller.rb), and [`test/integration/accounts_test.rb`](../../test/integration/accounts_test.rb).

**In scope:**

- Add `complimentary_premium` immediately after `student_limit` in `AccountResource`.
- Add `complimentary_premium_note, index: false` immediately after the flag.
- Test the flag on index/show/edit and the note on show/edit but not index.
- Test successful grant with a note.
- Test invalid blank/whitespace-note updates render Madmin's validation error and persist neither field.
- Test revocation using `"0"` so unticking the checkbox saves false while retaining the note.
- Test that a non-superadmin is redirected away from Madmin.
- Test that a parent's `PATCH /accounts/:id` cannot change either comp field.

**NOT in scope:**

- Custom Madmin fields, filters, sorting, layouts, or labels.
- Changing `AccountsController#account_params`.
- Building parent-facing comp controls.
- Replacing Madmin's built-in checkbox or validation-error rendering.

**Build order:**

1. **Test:** Extend `test/integration/madmin/accounts_test.rb` with visibility, grant, validation, revoke, and authorization coverage. Extend `test/integration/accounts_test.rb` with a parent strong-parameter regression test.
2. **Implement:** Update `lib/jumpstart/app/madmin/resources/account_resource.rb` with the two attributes. Existing Madmin authorization and parent strong parameters should remain unchanged; modify them only if the new tests reveal behavior inconsistent with the approved design.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/integration/madmin/accounts_test.rb test/integration/accounts_test.rb`

### Task 5 [subagent]: Prove complimentary families can enter checkout

**Skills:** write-tests
**Reference:** Read [`test/integration/checkouts_test.rb`](../../test/integration/checkouts_test.rb) and [`lib/jumpstart/app/controllers/checkouts_controller.rb`](../../lib/jumpstart/app/controllers/checkouts_controller.rb), especially `redirect_if_already_subscribed`.

**In scope:**

- Add an integration regression test showing a comped, unpaid family can open Stripe checkout.
- Assert a successful checkout response and captured Stripe checkout arguments.
- Prove the comp flag alone does not trigger the existing "already subscribed" redirect.

**NOT in scope:**

- Changing the checkout UI or Stripe arguments.
- Allowing families with active paid subscriptions to start another checkout.
- Replacing the existing Pay-based subscribed check.
- Creating a Pay subscription for the comp.

**Build order:**

1. **Test:** Extend `test/integration/checkouts_test.rb` with a test that enables the comp with a note on the signed-in family and opens checkout through the existing Stripe stub.
2. **Implement:** No production change is expected because the controller already checks Pay subscription state rather than `premium?`. If the regression test exposes contrary behavior, keep any correction limited to `redirect_if_already_subscribed`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/integration/checkouts_test.rb`

### Task 6 [subagent]: Seed an idempotent complimentary tester family

**Skills:** write-tests
**Reference:** Read [`db/seeds.rb`](../../db/seeds.rb) and [`test/config/seeds_test.rb`](../../test/config/seeds_test.rb) for local-only and repeatable seed patterns.

**In scope:**

- Seed `tester@cove.test` with password `password`, confirmed timestamp, accepted terms, and a stable tester name inside `Rails.env.local?`.
- Create its default family only when it has no family.
- Set the family's comp flag and exact note: `Dev seed: complimentary Premium tester`.
- Test running development seeds twice.
- Assert exactly one tester exists, its family remains comped with the expected note, and it has no Pay customer or subscription.
- Preserve the existing staging/production no-demo-data guarantee.

**NOT in scope:**

- Seeding the tester outside local environments.
- Adding a fake subscription, payment processor, receipt, or billing email.
- Making the tester a system administrator.
- Altering the existing owner, admin, subscriber, plan, or superadmin seeds.

**Build order:**

1. **Test:** Extend `test/config/seeds_test.rb` with the idempotent tester-family expectations before changing the seed implementation.
2. **Implement:** Update `db/seeds.rb` with the tester creation, `create_default_account unless tester.family`, and the explicit family comp update.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/config/seeds_test.rb`
4. **Checkpoint review:** After Tasks 4–6 are complete, run `review-changes-mini` exactly once for checkpoint 2. Because these tasks can run as a parallel batch, the master runs the review after all three subagents return.

## Task Dependencies

- Task 1 must complete first because every other task depends on the new database columns.
- Task 2 depends on Task 1 so its fixtures can load against the migrated schema.
- Task 3 depends on Tasks 1–2 and establishes the shared entitlement behavior.
- Tasks 4–6 depend on Task 3 and can run in parallel.
- Checkpoint 1 covers Tasks 1–3.
- Checkpoint 2 covers Tasks 4–6.
- After checkpoint 2, the master runs the full required verification, including `bin/rails test`, project-wide `bin/rubocop`, and `git diff origin/main...`, before reporting implementation complete.
