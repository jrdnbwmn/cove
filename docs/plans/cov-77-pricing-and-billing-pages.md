> Ticket: COV-77
> Branch: feature/cov-77-pricing-and-billing-pages-for-free-vs-premium

# Plan: Pricing and Billing Pages for Free vs Premium

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add pricing helpers and the copy contract | Master | |
| 2 | 1 | 1 | Extend `PlanCardComponent` for Free and yearly displays | subagent | |
| 3 | 2 | 2 | Build state-aware Free/Premium pricing | Master | |
| 4 | 2 | 2 | Render Free, paid, complimentary, and canceled billing states | Master | |
| 5 | 2 | 2 | Remove billing trial and duplicate grace-period presentation | subagent | |
| 6 | 3 | 3 | Add refund policy copy and dated cancellation terms | Master | |
| 7 | 3 | 3 | Clarify Family and login deletion consequences | subagent | |
| 8 | 3 | 3 | Update component documentation, previews, and run final verification | Master | |

## Prerequisites

- Design: [`docs/designs/cov-77-pricing-and-billing-pages.md`](../designs/cov-77-pricing-and-billing-pages.md)
- Prototype: None
- Feature branch exists: `feature/cov-77-pricing-and-billing-pages-for-free-vs-premium`
- Use Ruby 4.0.5 by prepending `/Users/jordan/.local/share/mise/shims` to `PATH` for every Rails or RuboCop command.
- The component catalog was scanned. This work reuses `PlanCardComponent`, `CardComponent`, `BadgeComponent`, `AlertComponent`, and `ButtonComponent`; no new component is needed.
- Keep the existing pricing Stimulus controller, routes, controllers, subscription machinery, and Plan rows unchanged.
- Implementation clarification: optional `plan:` is insufficient to render a Free card's name and description. Add generic `name:` and `description:` overrides alongside the design's `price_text:`, `price_note:`, and `features:` overrides.
- Implementation clarification: `premium_student_limit` must read `current_account.student_limit` when signed in, falling back to `Account.column_defaults["student_limit"]`. Calling `students_allowed` for a Free family would incorrectly advertise one Premium student.
- Source-drift clarification: Family deletion now exists on both `accounts/show` and `accounts/edit`. Preserve both owner-only controls and give both accurate policy copy; do not remove or rearrange either control.

## Tasks

## Phase 1: Pricing Presentation Primitives

### Task 1 [Master]: Add pricing helpers and the copy contract

**Skills:** write-tests
**Reference:** Read [`lib/jumpstart/app/helpers/pricing_helper.rb`](../../lib/jumpstart/app/helpers/pricing_helper.rb), [`lib/jumpstart/app/helpers/plan_helper.rb`](../../lib/jumpstart/app/helpers/plan_helper.rb), [`app/models/account.rb`](../../app/models/account.rb), and [`config/locales/en.yml`](../../config/locales/en.yml).

**In scope:**

- Create `app/helpers/pricing_helper.rb` without defining or shadowing `PlanHelper`.
- Add `monthly_equivalent(plan)`, returning complete display strings such as `$7/mo` and `$7.50/mo`, rounded to cents with insignificant zeros removed.
- Add `premium_student_limit`, using the signed-in Family's stored Premium limit or the Account column default when signed out.
- Add locale-backed Free/Premium descriptions, features, state/action labels, shared no-refund wording, cancellation fallbacks, and Family-deletion policy copy.
- Add helper tests for yearly rounding, insignificant-zero removal, signed-in limits, Free-family limits, and signed-out defaults.

**NOT in scope:**

- Changing `Account#students_allowed`, `Account#plan_status`, Plan records, or payment behavior.
- Moving interval formatting into this helper.
- Adding hard-coded prices or student limits to views.

**Build order:**

1. **Test:** Create `test/helpers/pricing_helper_test.rb`; assert `$84/year -> $7/mo`, `$90/year -> $7.50/mo`, and the signed-in/signed-out Premium-limit cases.
2. **Implement:** Create `app/helpers/pricing_helper.rb` and add the required strings to `config/locales/en.yml`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/helpers/pricing_helper_test.rb`

### Task 2 [subagent]: Extend `PlanCardComponent` for Free and yearly displays

**Skills:** write-tests, style-ui
**Reference:** Read [`app/components/plan_card_component.rb`](../../app/components/plan_card_component.rb), [`app/components/plan_card_component.html.erb`](../../app/components/plan_card_component.html.erb), and [`test/components/plan_card_component_test.rb`](../../test/components/plan_card_component_test.rb).

**In scope:**

- Make `plan:` optional.
- Add optional `name:`, `description:`, `price_text:`, `price_note:`, and `features:` arguments, defaulting to Plan-derived values when a Plan exists.
- When `price_text` is supplied, render it verbatim without appending the Plan interval; render `price_note` beneath it.
- Preserve existing contact-price, unit-label, interval, feature, and caller-action behavior.
- Add component tests and preview examples for Free and yearly-equivalent cards; replace preview trial wording.

**NOT in scope:**

- A `FreePlan` object, `Plan.free`, database writes, or pricing-state decisions.
- Hard-coding Free/Premium copy inside the component.
- Changing `CardComponent` or other catalog components.

**Build order:**

1. **Test:** Extend `test/components/plan_card_component_test.rb` with nil-plan Free rendering, custom yearly price/note, feature overrides, and regressions for priced/contact/unit plans.
2. **Implement:** Update the component Ruby/template files and `test/components/previews/plan_card_component_preview.rb`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/components/plan_card_component_test.rb`
4. **Checkpoint review:** After Tasks 1-2 finish, run `review-changes-mini` exactly once for checkpoint 1. If they run in parallel, the master runs it after both return.

## Phase 2: Pricing and Billing States

### Task 3 [Master]: Build state-aware Free/Premium pricing

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/pricing/show.html.erb`](../../app/views/pricing/show.html.erb), [`lib/jumpstart/app/controllers/pricing_controller.rb`](../../lib/jumpstart/app/controllers/pricing_controller.rb), [`test/integration/plans_test.rb`](../../test/integration/plans_test.rb), and the pricing state table in the design.

**In scope:**

- Render a localized Free card first in both monthly and yearly groups.
- Render yearly Premium as the monthly equivalent plus the full yearly billing note.
- Implement signed-out, Free, paid Premium, complimentary, canceled-in-period, past-due, and grandfathered-price actions exactly as designed.
- Remove both pricing trial branches.
- Create the shared seven-test system-test file and initially add the Free/Premium acceptance tests plus signed-out, complimentary-pricing, and grandfathered-price coverage.
- Update the subscribed fixture to resolve to `premium-monthly` and include `current_period_end`; hide unrelated visible fixture plans only inside the system-test setup.

**NOT in scope:**

- Changing the pricing controller, Stimulus toggle, checkout behavior, or subscription swap behavior.
- Clearing complimentary status when someone subscribes.
- Adding the refund sentence yet; Task 6 owns policy placement.

**Build order:**

1. **Test:** Create `test/system/pricing_and_billing_system_test.rb`; add "Free family sees Free as its current plan and can upgrade" and "Premium family sees its current plan and can switch billing intervals," plus the signed-out and edge-state assertions. Update `test/integration/plans_test.rb` for the new action labels.
2. **Implement:** Update `test/fixtures/pay/subscriptions.yml` and `app/views/pricing/show.html.erb`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/integration/plans_test.rb`
4. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test:system test/system/pricing_and_billing_system_test.rb`

### Task 4 [Master]: Render all billing plan states

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/billing/show.html.erb`](../../app/views/billing/show.html.erb), [`lib/jumpstart/app/controllers/billing_controller.rb`](../../lib/jumpstart/app/controllers/billing_controller.rb), and [`app/views/billing/subscriptions/_subscription.html.erb`](../../app/views/billing/subscriptions/_subscription.html.erb).

**In scope:**

- Create `app/views/billing/_plan_state.html.erb`, reading `current_account.plan_status` and `@subscriptions.first`.
- Render Free, paid Premium, complimentary Premium, canceled-in-grace, renewal-date, and nil-date cases using existing catalog components.
- Render the existing subscription controls beneath paid states.
- Show billing email, extra information, and charge history only when a paid subscription exists.
- Extend the system file with the complimentary, second-parent, and canceled-date acceptance tests; also assert the Free and paid billing summaries.

**NOT in scope:**

- Controller queries, authorization, cancellation behavior, payment methods, receipts, or database changes.
- Removing the existing grace-period message inside `_subscription`; Task 5 moves that responsibility.
- Reworking past-due actions or badges.

**Build order:**

1. **Test:** Add the remaining billing-state acceptance tests to `test/system/pricing_and_billing_system_test.rb`, including exact `ends_at` and `current_period_end` dates and absence of paid-only sections for complimentary families.
2. **Implement:** Add the plan-state partial and update `app/views/billing/show.html.erb`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test:system test/system/pricing_and_billing_system_test.rb`

### Task 5 [subagent]: Remove trial and duplicate grace-period presentation

**Skills:** write-tests, style-ui
**Reference:** Read [`test/views/billing/subscriptions/subscription_partial_test.rb`](../../test/views/billing/subscriptions/subscription_partial_test.rb), [`app/views/billing/subscriptions/_subscription.html.erb`](../../app/views/billing/subscriptions/_subscription.html.erb), and [`app/views/billing/subscriptions/edit.html.erb`](../../app/views/billing/subscriptions/edit.html.erb).

**In scope:**

- Remove generic-trial and on-trial branches from the subscription partial.
- Remove the plan-switching trial banner.
- Remove the old `ends_at` grace warning from the subscription partial so `_plan_state` owns it, while retaining Resume and pause behavior.
- Replace the existing positive trial view test with regressions proving stale trial fields do not render trial copy and grace-period actions remain available.
- Remove only the now-unused app locale keys for these branches.

**NOT in scope:**

- Pay trial columns/methods, trial mailers, Loops configuration, engine view copies, or example locale files.
- Removing canceled/resume behavior.
- Changing past-due, unpaid, paused, or incomplete states.

**Build order:**

1. **Test:** Update `test/views/billing/subscriptions/subscription_partial_test.rb` to require no trial presentation, no duplicate end-date warning, and retained Resume/past-due behavior.
2. **Implement:** Update both billing subscription views and remove their unused keys from `config/locales/en.yml`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/views/billing/subscriptions/subscription_partial_test.rb`
4. **Checkpoint review:** After Tasks 3-5 finish, run `review-changes-mini` exactly once for checkpoint 2.

## Phase 3: Policy Copy and Catalog Completion

### Task 6 [Master]: Add refund policy copy and dated cancellation terms

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/checkouts/show.html.erb`](../../app/views/checkouts/show.html.erb), [`app/views/billing/subscriptions/cancels/show.html.erb`](../../app/views/billing/subscriptions/cancels/show.html.erb), and the Stripe stub in [`test/integration/checkouts_test.rb`](../../test/integration/checkouts_test.rb).

**In scope:**

- Show the shared no-refund sentence below pricing cards and below checkout payment content.
- Remove both checkout trial branches while preserving standard authorization copy.
- Show `current_period_end` plus explicit no-refund wording on cancellation confirmation, with the undated fallback when the period end is absent.
- Complete acceptance test 6 across pricing, checkout, and cancellation.
- Complete acceptance test 7 by asserting no trial wording on the real pricing, checkout, billing, and cancellation pages.
- Stub Stripe session creation in-process and assert only Cove-owned text outside the iframe.

**NOT in scope:**

- Stripe iframe content, processor behavior, cancellation timing, refunds, proration, or metered cancellation behavior.
- Removing trial APIs or mailers.
- Live-mode checkout verification.

**Build order:**

1. **Test:** Complete the two policy acceptance tests in `test/system/pricing_and_billing_system_test.rb`, including the missing-date cancellation fallback.
2. **Implement:** Update the pricing, checkout, and cancellation views using Task 1's locale keys.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test:system test/system/pricing_and_billing_system_test.rb`

### Task 7 [subagent]: Clarify Family and login deletion consequences

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/accounts/show.html.erb`](../../app/views/accounts/show.html.erb), [`app/views/accounts/edit.html.erb`](../../app/views/accounts/edit.html.erb), [`app/views/devise/registrations/edit.html.erb`](../../app/views/devise/registrations/edit.html.erb), and [`test/integration/accounts_edit_test.rb`](../../test/integration/accounts_edit_test.rb).

**In scope:**

- Preserve both owner-only Family deletion controls and localize their confirmation descriptions.
- For a paid Family, state that Premium ends immediately and no refund is issued; retain generic deletion copy for a Free Family.
- Give an owner deleting their login the same paid-Family consequence.
- Keep the second parent's login-deletion copy explicit that the Family and subscription remain unchanged.
- Add rendered integration coverage for both Family pages and owner/non-owner login deletion.

**NOT in scope:**

- Removing, moving, or redesigning either Family deletion control.
- Changing who can delete a Family or login.
- Changing account destruction or subscription cancellation callbacks.

**Build order:**

1. **Test:** Create `test/integration/billing_policy_copy_test.rb` covering paid/free Family deletion and owner/second-parent login deletion.
2. **Implement:** Update the three views to select Task 1's locale-backed copy according to actual subscription and ownership state.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/integration/billing_policy_copy_test.rb test/integration/accounts_edit_test.rb`

### Task 8 [Master]: Update component documentation, previews, and run final verification

**Skills:** source-command-update-catalog, source-command-update-component-previews, write-tests, style-ui
**Reference:** Read [`docs/COMPONENT_CATALOG.md`](../../docs/COMPONENT_CATALOG.md), [`docs/architecture/component-map.mermaid`](../../docs/architecture/component-map.mermaid), and [`test/integration/dev/kitchen_sink_test.rb`](../../test/integration/dev/kitchen_sink_test.rb).

**In scope:**

- Update the PlanCard catalog entry for optional Plan data and the five overrides.
- Refresh the component map if required by the catalog workflow.
- Replace the kitchen-sink trial sample with the final Premium/no-trial example.
- Add a kitchen-sink regression assertion for the updated action copy.
- Run the complete Rails, system, lint, whitespace, and branch-diff gates.

**NOT in scope:**

- Unrelated catalog, preview, component-map, or kitchen-sink rewrites.
- New components or visual redesign.
- Browser, staging, Stripe, or deployment verification.

**Build order:**

1. **Test:** Update `test/integration/dev/kitchen_sink_test.rb` to expect the final PlanCard example and no trial action.
2. **Implement:** Apply the catalog/component-preview workflows, retaining only COV-77 changes in `docs/COMPONENT_CATALOG.md`, `docs/architecture/component-map.mermaid`, and `app/views/dev/kitchen_sink/show.html.erb`.
3. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/components/plan_card_component_test.rb test/integration/dev/kitchen_sink_test.rb`
4. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test`
5. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test:system`
6. **Verify:** `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rubocop`
7. **Verify:** `git diff --check && git diff --stat origin/main... && git diff origin/main...`
8. **Checkpoint review:** After Tasks 6-8 finish, run `review-changes-mini` exactly once for checkpoint 3. If Task 7 runs in parallel, the master waits for it before reviewing.

## Task Dependencies

- Tasks 1-2 are independent and may run in parallel; Task 1 remains Master because it establishes copy and calculation contracts.
- Task 3 depends on Tasks 1-2.
- Task 4 depends on Task 3's real paid-plan fixture and shared system-test structure.
- Task 5 follows Task 4 so the new plan-state partial owns canceled-date presentation before the old warning is removed.
- Task 6 depends on Tasks 3-5 because its two acceptance tests traverse every completed page.
- Task 7 depends only on Task 1 and may run in parallel with Tasks 3-6.
- Task 8 depends on Tasks 2, 5, and 6 and is the final repository verification task.
- Checkpoint 1 covers Tasks 1-2; checkpoint 2 covers Tasks 3-5; checkpoint 3 covers Tasks 6-8.
