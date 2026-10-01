> Ticket: COV-94
> Branch: fix/cov-94-yearly-to-monthly-renewal

# Plan: Yearly to monthly at renewal

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add Stripe schedule behavior to Pay subscriptions | Master | ✅ |
| 2 | 1 | 1 | Guard plan changes and route each billing direction | Master | ✅ |
| 3 | 1 | 1 | Release schedules before cancellation or family deletion | Master | ✅ |
| 4 | 2 | 2 | Add confirmation and Keep yearly endpoints | Master | ✅ |
| 5 | 2 | 2 | Build the confirmation page and billing copy | Master | ✅ |
| 6 | 2 | 3 | Link plan cards to confirmation | subagent | ✅ |
| 7 | 2 | 3 | Show the pending switch on Billing | subagent | ✅ |
| 8 | 2 | 3 | Explain cancellation and update the price runbook | subagent | ✅ |

## Prerequisites

- Design: `docs/designs/yearly-to-monthly-at-renewal.md`
- Prototype: None. Preserve the existing billing layout and use its catalog components.
- Feature branch exists: `fix/cov-94-yearly-to-monthly-renewal`.
- Run Rails commands with mise's Ruby 4.0.5 shims on `PATH`. Keep Rails test processes sequential.

## Tasks

### Task 1 [Master]: Add subscription schedule behavior

**Skills:** write-tests
**Reference:** Read `config/initializers/pay.rb` and Pay 11.6.2's `app/models/pay/stripe/subscription.rb` for sync and Stripe account options.

**In scope:**

- Add `schedule_plan_change_at_renewal`, `pending_plan_change`, and `release_schedule!` in `app/models/pay/subscription/plan_schedule.rb`; include the module from `config/initializers/pay.rb`.
- Keep the current yearly phase through `current_period_end`, then one monthly phase; set `proration_behavior: none` at every specified level and `end_behavior: release`. Sync after schedule changes. Release a half-created schedule if updating it fails.
- Read pending state from the stored, expanded Stripe schedule. Release an attached schedule even when no future phase remains.

**NOT in scope:** New persistence, migrations, schedule webhooks, or changes to Pay's gem code.

**Build order:**

1. **Test:** Add `test/models/pay/subscription/plan_schedule_test.rb`. Use WebMock to assert schedule request bodies and release order; cover failed update cleanup, expanded/string/absent schedules, unknown price IDs, and the attached first monthly phase.
2. **Implement:** Add the module and initializer inclusion.
3. **Verify:** `bin/rails test test/models/pay/subscription/plan_schedule_test.rb`

### Task 2 [Master]: Protect and route plan changes

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/billing/subscriptions_controller.rb` and `lib/jumpstart/app/models/plan.rb`.

**In scope:**

- Reject edit and update for grace-period, past-due, unpaid, or otherwise inactive subscriptions; reject a new change while a future switch is pending.
- For a Stripe yearly subscription changing to monthly, schedule at renewal. Keep monthly to yearly immediate through Pay's prorated `swap`. Release an attached schedule before an immediate swap.
- Preserve the existing fake-processor lifecycle used by tests; only Stripe subscriptions use Stripe schedule calls.

**NOT in scope:** Confirmation routes or billing-page presentation.

**Build order:**

1. **Test:** Add `test/integration/subscription_plan_changes_test.rb` with WebMock-backed Stripe cases for both directions, blocked states, and no Stripe update that clears cancellation.
2. **Implement:** Update `lib/jumpstart/app/controllers/billing/subscriptions_controller.rb`.
3. **Verify:** `bin/rails test test/integration/subscription_plan_changes_test.rb test/integration/subscriptions_test.rb`

### Task 3 [Master]: Make cancellation and deletion schedule-safe

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb` and `app/models/account.rb`.

**In scope:** Release an attached schedule before every cancellation branch and before family deletion calls `cancel_now!`, including during the first monthly phase.

**NOT in scope:** Changing cancellation timing, refunds, or family-deletion policy.

**Build order:**

1. **Test:** Add `test/integration/subscription_schedule_cancellation_test.rb` for release-before-cancel request order; extend `test/models/account_test.rb` for release-before-family-deletion cancellation.
2. **Implement:** Update the cancel controller and `Account#cancel_billable_subscriptions!`.
3. **Verify:** `bin/rails test test/integration/subscription_schedule_cancellation_test.rb test/models/account_test.rb`
4. **Review:** Run `review-changes-mini` once for checkpoint 1, covering Tasks 1-3.

Phase 1 can ship with the existing direct plan-change page: yearly to monthly is already scheduled safely, and cancellation can release schedules.

### Task 4 [Master]: Add confirmation and Keep yearly endpoints

**Skills:** write-tests
**Reference:** Read `config/routes/billing.rb`, `lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb`, and the guards from Task 2.

**In scope:** Add nested `plan_change` show and destroy routes and `Billing::Subscriptions::PlanChangesController`. Show loads the account's subscription and requested plan, applies the same change guards, and limits the page to an actual plan change. Destroy releases a pending switch and redirects to Billing. Require an account admin.

**NOT in scope:** Page markup or changing the subscription's current price in destroy.

**Build order:**

1. **Test:** Extend `test/integration/subscription_plan_changes_test.rb` for authorization, invalid subscription/plan, blocked and pending states, and Keep yearly release.
2. **Implement:** Update `config/routes/billing.rb`; add `app/controllers/billing/subscriptions/plan_changes_controller.rb`.
3. **Verify:** `bin/rails test test/integration/subscription_plan_changes_test.rb`

### Task 5 [Master]: Build the confirmation page and copy

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/billing/subscriptions/cancels/show.html.erb`, the billing summary partial, and the catalog entries for `CardComponent`, `AlertComponent`, and `ButtonComponent`.

**In scope:** Add the sidebar confirmation page with the existing summary, Back link, and PATCH confirmation button. Explain renewal timing and no credit for yearly to monthly; explain immediate proration for monthly to yearly. Add all copy needed by Tasks 5-8 to `config/locales/en.yml`.

**NOT in scope:** A prorated invoice preview or visual redesign.

**Build order:**

1. **Test:** Extend `test/integration/subscription_plan_changes_test.rb` to assert both confirmation messages, price and date from records, and the submitted plan parameter.
2. **Implement:** Add `app/views/billing/subscriptions/plan_changes/show.html.erb` and update `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/subscription_plan_changes_test.rb`
4. **Review:** Run `review-changes-mini` once for checkpoint 2, covering Tasks 4-5.

### Task 6 [subagent]: Link plan cards to confirmation

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/billing/subscriptions/edit.html.erb` and the catalog's `ButtonComponent` link arguments.

**In scope:** Replace each Change plan PATCH form and "Are you sure?" dialog with a GET link to the confirmation page. Preserve the card layout and current-plan state.

**NOT in scope:** Other change-plan page copy or card styling.

**Build order:**

1. **Test:** Extend `test/system/pricing_and_billing_system_test.rb` to follow a plan card to confirmation and assert the plan page has no change-plan confirm dialog.
2. **Implement:** Update `app/views/billing/subscriptions/edit.html.erb`.
3. **Verify:** `bin/rails test:system test/system/pricing_and_billing_system_test.rb`

### Task 7 [subagent]: Show pending change on Billing

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/billing/_plan_state.html.erb`, `app/views/billing/subscriptions/_subscription.html.erb`, and the catalog's `AlertComponent` and `ButtonComponent` entries.

**In scope:** Replace the renewal line with the pending notice; replace Change plan with Keep yearly while pending. Keep the other subscription actions.

**NOT in scope:** A persisted pending-change flag or changes to price calculation.

**Build order:**

1. **Test:** Extend `test/integration/billing_policy_copy_test.rb` for the dated notice and `test/views/billing/subscriptions/subscription_partial_test.rb` for Keep yearly and the absent Change plan link.
2. **Implement:** Update the two billing partials.
3. **Verify:** `bin/rails test test/integration/billing_policy_copy_test.rb test/views/billing/subscriptions/subscription_partial_test.rb`

### Task 8 [subagent]: Explain cancellation and update the runbook

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/billing/subscriptions/cancels/show.html.erb` and `docs/runbooks/price-change-checklist.md`.

**In scope:** State on the cancel page that a pending monthly switch will be removed. Add the runbook note that pending switches retain their original monthly Stripe Price.

**NOT in scope:** The cancel button's existing confirm dialog or other runbook steps.

**Build order:**

1. **Test:** Extend `test/integration/subscription_schedule_cancellation_test.rb` to assert the pending-switch notice and its absence without a pending switch.
2. **Implement:** Update the cancel view and price-change checklist.
3. **Verify:** `bin/rails test test/integration/subscription_schedule_cancellation_test.rb`
4. **Review:** After Tasks 6-8 return, Master runs `review-changes-mini` once for checkpoint 3.

After checkpoint 3, run the affected Rails tests sequentially, then `bin/rails test`, relevant system tests, `bin/rubocop`, and `git diff --check`. Inspect `git diff` before reporting completion.

## Task Dependencies

- Task 2 depends on Task 1's schedule methods. Task 3 also depends on Task 1.
- Task 4 depends on Task 2's plan-change guards. Task 5 depends on Task 4's route and controller.
- Tasks 6-8 can run in parallel after Task 5. Their test files are separate, and their Rails test commands must still run sequentially in this worktree.
- The Master performs each checkpoint review after all tasks in that checkpoint finish.
