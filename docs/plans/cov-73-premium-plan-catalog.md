> Ticket: COV-73
> Branch: feature/cov-73-premium-plan-catalog

# Plan: Premium plan catalog (dev, test, staging)

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | `Plan` delete guard + model tests | Master |      |
| 2    | 1     | 1          | Admin delete refusal message + request test | Clone |      |
| 3    | 1     | 2          | Premium test fixtures + no-trial checkout test | Master |      |
| 4    | 1     | 2          | Dev seeds: Premium monthly/yearly + seeds test | Clone |      |
| 5    | 1     | 2          | Price-change runbook + `AGENTS.md` rule | Clone |      |
| 6    | 2     | 3          | Staging: create Stripe product/prices, archive old price | Master |      |
| 7    | 2     | 3          | Staging: enter Plan rows at `/admin/plans`, hide Cove Dev Plan | Master |      |
| 8    | 2     | 3          | Staging: live checkouts (both intervals) + COV-78 handoff | Master |      |

## Prerequisites

- Design: `docs/designs/cov-73-premium-plan-catalog.md`
- Prototype: None (backend/data work plus one admin flash message; no new screens or components, so no catalog components needed)
- Feature branch exists: `feature/cov-73-premium-plan-catalog`
- **Phase 2 runs only after Jordan merges the Phase 1 PR.** `/execute-plan` stops after Checkpoint 2.
- Every `bin/rails` / `bin/rubocop` command needs `export PATH="$HOME/.local/share/mise/shims:$PATH"` first (`ruby -v` should say 4.0.5).

## Tasks

### Task 1 [Master]: `Plan` refuses deletion while any subscription references it

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/models/plan.rb`, `test/models/plan_test.rb`, `test/fixtures/pay/subscriptions.yml` (existing `subscribed` fixture uses `processor_plan: fake`, which matches no plan)

**In scope:**

- A `before_destroy` callback in `Plan`. It collects the non-blank values of `stripe_id`, `fake_processor_id`, `braintree_id`, `paddle_billing_id`, `paddle_classic_id` and `lemon_squeezy_id`. If `Pay::Subscription.where(processor_plan: ids).exists?`, it runs `errors.add(:base, :has_subscriptions)` and then `throw :abort`. Every subscription status counts, and the check doesn't look at which processor the subscription uses.
- Add a `# AIDEV-NOTE:` explaining why: subscriptions look up their plan by processor ID in `config/initializers/pay.rb`, and canceled ones still show in billing history.
- Locale string `activerecord.errors.models.plan.attributes.base.has_subscriptions: "This plan has subscribers, so it can't be deleted. Hide it instead."` in `config/locales/en.yml`. This is the only copy of the message; Task 2 reuses it.

**NOT in scope:**

- The admin controller, blocking edits to `amount`/`stripe_id`, and scoping the check by processor.

**Build order:**

1. **Test** (`test/models/plan_test.rb`). Use `Pay::Subscription.create!` on a fixture customer (e.g. `pay_customers(:subscribed)`) with `processor_plan` set to the plan's ID, then assert:
   - "a plan with an active subscriber can't be deleted": `destroy` returns false, the plan still exists, and the error message matches the locale text
   - "a plan referenced only by a canceled subscription can't be deleted"
   - "a subscriber on any of the plan's processor IDs blocks deletion" (use `fake_processor_id`, not `stripe_id`)
   - "a plan with no subscribers can be deleted"
   - "a plan with every processor ID blank can be deleted"
   - "`destroy!` raises for a plan with subscribers": `ActiveRecord::RecordNotDestroyed`
2. **Implement:** `lib/jumpstart/app/models/plan.rb`, `config/locales/en.yml`
3. **Verify:** `bin/rails test test/models/plan_test.rb`

### Task 2 [Clone]: Admin sees a message when deleting a subscribed plan

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/madmin/plans_controller.rb`. Madmin's base `destroy` is `@record.destroy; redirect_to resource.index_path`, and `resource.show_path(record)` exists. `test/integration/admin_test.rb` shows signing in as `users(:admin)` for `/admin`. Madmin's layout already renders `alert` flash.

**In scope:**

- Override `destroy` in `Madmin::PlansController`:
  - On success: `redirect_to resource.index_path` (same as today).
  - On refusal: `redirect_to resource.show_path(@record), alert: @record.errors.full_messages.to_sentence`.
- New `test/integration/madmin/plans_test.rb`. Sign in as `users(:admin)`, then:
  - "admin can't delete a plan that has subscribers": `delete` the plan's admin path; the plan still exists; redirect goes to its show page; following the redirect shows the locale message
  - "admin can delete a plan with no subscribers": plan is gone; redirect goes to the plans index

**NOT in scope:**

- New locale strings (use Task 1's), view changes, and any other Madmin resource.

**Build order:**

1. **Test:** `test/integration/madmin/plans_test.rb`. Get the admin URL from `bin/rails routes | grep madmin.*plan`.
2. **Implement:** `lib/jumpstart/app/controllers/madmin/plans_controller.rb`
3. **Verify:** `bin/rails test test/integration/madmin/plans_test.rb test/models/plan_test.rb`
4. **Checkpoint 1 review:** when this task is done, run review-changes-mini on Checkpoint 1 (Tasks 1–2). If Tasks 1–2 ran as a parallel batch, the master runs this review once after the whole batch returns. It runs exactly once for this checkpoint.

### Task 3 [Master]: Premium fixtures + checkout starts with no trial

**Skills:** write-tests
**Reference:** `test/fixtures/plans.yml`, `test/integration/checkouts_test.rb` (the `capture_checkout_args` helper), `lib/jumpstart/app/controllers/checkouts_controller.rb:63` (trial is omitted when `trial_period_days` ≤ 1)

**In scope:**

- Add `premium_monthly` and `premium_yearly` to `test/fixtures/plans.yml`:
  - name `Premium`
  - amount 900 / 8400
  - interval `month` / `year`
  - `trial_period_days: 0`
  - `stripe_id` `premium-monthly` / `premium-yearly`
  - `fake_processor_id` the same values
  - a placeholder `details.features` list
- Keep every existing fixture.
- Two tests in `checkouts_test.rb`: "Premium monthly checkout starts with no trial" and "Premium yearly checkout starts with no trial". For each, assert `checkout_args[:subscription_data]` has no `:trial_period_days` key and that `line_items` is the plan's `stripe_id`. Parameterize `capture_checkout_args` with a `plan:` keyword so it can take the plan.
- Run the **full** suite, because these fixtures add two visible plans. Fix any test that breaks because of them. Watch `test/integration/plans_test.rb`, `test/components/plan_card_component_test.rb` and `test/integration/subscriptions_test.rb`. Fix the test's assumptions, not app code, and ask Jordan if a fix looks like it needs app code.

**NOT in scope:**

- Seeds, pricing page display changes, and trial logic changes.

**Build order:**

1. **Test:** add the fixtures and the two checkout tests.
2. **Implement:** no app code is expected. If a no-trial test fails, stop and ask.
3. **Verify:** `bin/rails test test/integration/checkouts_test.rb`, then `bin/rails test`

### Task 4 [Clone]: Dev seeds create the Premium catalog

**Skills:** write-tests
**Reference:** `db/seeds.rb` (the "Cove Dev Plan" block), `test/config/seeds_test.rb`

**In scope:**

- Replace the `cove_dev` block with two `Plan.find_or_create_by!(fake_processor_id: ...)` calls:
  - `premium_monthly`: Premium, 900, month, `trial_period_days: 0`
  - `premium_yearly`: Premium, 8400, year, `trial_period_days: 0`
  - both get a placeholder `features` list
  - no `stripe_id`
- Subscribe the `subscribed@cove.test` family with `plan: "premium_monthly"`.
- Extend `seeds_test.rb` with "development seeds Premium monthly and yearly with no trial":
  - one visible monthly and one visible yearly plan, both named Premium, with amounts 900 / 8400 and `trial_period_days` 0
  - no plan with `fake_processor_id: "cove_dev"`
  - the subscribed family's subscription `processor_plan` is `premium_monthly`
  - running the seeds twice doesn't duplicate plans
- The existing staging/production "no seed data" tests must still pass.

**NOT in scope:**

- Cleanup code for old local `cove_dev` rows, Stripe IDs, and final features copy (COV-77).

**Build order:**

1. **Test:** `test/config/seeds_test.rb`
2. **Implement:** `db/seeds.rb`
3. **Verify:** `bin/rails test test/config/seeds_test.rb`

### Task 5 [Clone]: Price-change runbook + `AGENTS.md` rule

**Reference:** design doc flows C and E, plus the "Staging (Render) and Stripe credential workflow" gotchas in `AGENTS.md`

**In scope:**

- New `docs/runbooks/price-change-checklist.md`, a numbered checklist covering:
  1. Confirm you're in the right Stripe account by checking the account ID in the publishable key.
  2. Create a new Price on the existing "Premium" product.
  3. Create a new Plan row at `/admin/plans` with the **same name**, the new amount and the new Stripe ID, and `trial_period_days` 0.
  4. Hide the old row in the same sitting. Never delete it and never edit its `amount`/`stripe_id`. The delete guard enforces this.
  5. Decide whether to move existing subscribers.
  6. Verify `/pricing` shows one card per interval.
  - Also include a "Local checkout" section: paste a sandbox price ID into your local plan at `/admin/plans`.
- `AGENTS.md`, under Current Project Decisions, add the design's exact one-line rule: "Plan rows are never deleted or re-priced — a price change is a new Stripe Price + new Plan row, old row hidden. Follow `docs/runbooks/price-change-checklist.md`."

**NOT in scope:**

- Live-mode steps beyond a pointer (COV-78) and pricing display copy.

**Build order:**

1. **Test:** none (docs only).
2. **Implement:** the two files above.
3. **Verify:** `bin/rails test` (the full suite is green after Tasks 3–5) and `bin/rubocop`.
4. **Checkpoint 2 review:** when this task is done, run review-changes-mini on Checkpoint 2 (Tasks 3–5). If Tasks 3–5 ran as a parallel batch, the master runs this review once after the whole batch returns. It runs exactly once for this checkpoint. **Phase 1 ends here:** stop and let Jordan open, review and merge the PR before Phase 2.

### Task 6 [Master]: Staging Stripe product and prices (after merge)

**Reference:** design flow E, steps 1–2 and 4

**In scope:**

- Confirm the staging publishable key's account ID matches Cove sandbox `acct_1Tw25AAVvDn1V5lJ`. Use `stripe … --project-name cove`, and confirm which account the CLI is on before creating anything, because it was previously logged into Thistle Books.
- **Ask Jordan before running the create/archive commands**, since they change Stripe itself. Then:
  - create product "Premium" with a $9/month price and an $84/year price
  - archive the old $19 price (`price_1TxIO4…`)
- Report both new price IDs to Jordan to save in their records.

**NOT in scope:**

- Live mode (COV-78) and any credential changes.

**Build order:**

1. **Test:** none. This is manual ops.
2. **Implement:** Stripe CLI commands.
3. **Verify:** `stripe prices list --product <id> --project-name cove` shows both active prices with the correct amounts and intervals, and the $19 price shows as inactive.

### Task 7 [Master]: Staging Plan rows at `/admin/plans` (after merge)

**Skills:** claude-in-chrome
**Reference:** design flow E, steps 3–4

**In scope:**

- Confirm the deployed staging SHA includes the merged COV-73 commit.
- Sign in as superadmin and create two plans:
  - name "Premium"; amounts 900 / 8400; intervals month / year; `trial_period_days` 0
  - the Task 6 Stripe IDs
  - placeholder features
- Hide (don't delete) "Cove Dev Plan".

**NOT in scope:**

- Editing any other plan rows.

**Build order:**

1. **Test:** none.
2. **Implement:** enter the rows through the browser.
3. **Verify:** staging `/pricing` shows one Premium card at $9/month, the Yearly toggle shows $84/year, and Cove Dev Plan appears under `/admin/plans` Hidden.

### Task 8 [Master]: Staging live checkouts + COV-78 handoff (after merge)

**Skills:** claude-in-chrome
**Reference:** design flow E, step 5, and the webhook-secret gotcha in `AGENTS.md`

**In scope:**

- With **two separate test families**, check out monthly with a Stripe test card in one and yearly in the other. For each, confirm:
  - there is no trial on the Stripe subscription
  - the subscription syncs via webhook and appears in `/billing` and `/admin`
- If sync fails, check the webhook signing secret first.
- Give Jordan the COV-78 pointer line to paste: "Recreate Premium prices in live mode — follow `docs/runbooks/price-change-checklist.md`."

**NOT in scope:**

- Refunds, cancellation testing, and live mode.

**Build order:**

1. **Test:** none. This is live verification.
2. **Implement:** run the two checkouts.
3. **Verify:** each Stripe subscription has `trial_end: null` and status active, and each has a matching `Pay::Subscription` shown in staging `/admin`.
4. **Checkpoint 3 review:** when this task is done, run review-changes-mini on Checkpoint 3 (Tasks 6–8). This confirms the verification evidence and that no repo files changed. If Tasks 6–8 ran as a batch, the master runs this review once after all of them finish. It runs exactly once for this checkpoint.

## Task Dependencies

- Task 2 depends on Task 1 (the guard and locale string).
- Task 3 depends on Task 1 (it's the first fixture change; run the full suite afterwards).
- Tasks 4 and 5 can run in parallel with each other and with Task 3. They touch separate files.
- Phase 2 depends on Jordan merging Phase 1 and staging deploying it.
- Task 7 depends on Task 6 (needs the price IDs). Task 8 depends on Task 7.
