> Ticket: COV-88
> Branch: feature/cov-88-raise-premium

# Plan: Raise Premium to $12/mo and $120/yr

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Make development seed prices authoritative on fresh and existing databases | Master | |
| 2 | 1 | 1 | Update plan fixtures and pricing behavior expectations | subagent | |
| 3 | 1 | 1 | Update the yearly preview and its directly coupled test | subagent | |
| 4 | 2 | 2 | Validate the staging Stripe account and request creation approval | Master | |
| 5 | 2 | 2 | Create sandbox Prices and update staging Plan rows | Master | |
| 6 | 2 | 2 | Verify staging, record Price IDs, and run final gates | Master | |

## Prerequisites

- Design: [`docs/designs/cov-88-raise-premium.md`](../designs/cov-88-raise-premium.md)
- Prototype: None — pricing presentation is data-driven and no layout changes are authorized.
- Feature branch exists: `feature/cov-88-raise-premium`.
- Before Task 4, Jordan is signed into staging as a system admin and into the Stripe dashboard in Chrome.
- Narrow design correction: because `test/components/plan_card_component_test.rb` renders the preview being changed, its two preview assertions must also change. Leaving them unchanged would fail the required test suite.

## Tasks

### Task 1 [Master]: Make development seed prices authoritative

**Skills:** write-tests
**Reference:** Read [`db/seeds.rb`](../../db/seeds.rb) and [`test/config/seeds_test.rb`](../../test/config/seeds_test.rb) for the existing development-only seed behavior.

**In scope:**

- Prove that a fresh seed creates monthly Premium at `1200` and yearly Premium at `12000`.
- Prove that reseeding rows containing the former `900` and `8400` amounts corrects them without creating duplicates.
- Add explicit `update!` calls after each `find_or_create_by!`, while preserving the fake processor identifiers and the seeded subscription’s `processor_plan`.

**NOT in scope:**

- Staging or production seed behavior.
- Schema changes, migrations, subscription migration, or changes to plan names, intervals, features, or trial periods.
- Applying the never-re-price rule to these development-only fake processor rows.

**Build order:**

1. **Test:** Amend `test/config/seeds_test.rb` so the test loads the development seeds, resets the two seeded amounts to their old values, reloads the seeds, and expects `1200`/`12000`, exactly two Cove seed rows, and the existing `premium_monthly` subscription reference. Run `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/config/seeds_test.rb` and confirm it fails against the current seed logic.
2. **Implement:** Update `db/seeds.rb` to initialize new rows with the new amounts and explicitly update both existing rows’ `amount` values after lookup.
3. **Verify:** Run `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/config/seeds_test.rb`.

### Task 2 [subagent]: Update fixtures and pricing behavior expectations

**Skills:** write-tests
**Reference:** Read [`app/helpers/plan_pricing_helper.rb`](../../app/helpers/plan_pricing_helper.rb), [`app/views/pricing/_premium_card.html.erb`](../../app/views/pricing/_premium_card.html.erb), and the existing tests for the data-driven formatting path.

**In scope:**

- Change the Premium fixture amounts to `1200` monthly and `12000` yearly.
- Expect the annual plan to render an effective `"$10/mo"` and `"billed $120 yearly"`.
- Preserve the synthetic `9000` annual-plan assertion that exercises `"$7.50/mo"` formatting.

**NOT in scope:**

- Other Jumpstart demo plan fixtures.
- Translation, helper, view, route, or component implementation changes.
- Marketing copy or annual-discount messaging.

**Build order:**

1. **Test:** Update the pricing helper and system-test assertions in `test/helpers/plan_pricing_helper_test.rb` and `test/system/pricing_and_billing_system_test.rb` to the new prices, leaving fixtures unchanged initially. Run the focused tests and confirm the old fixture values make the new assertions fail.
2. **Implement:** Update only `premium_monthly` and `premium_yearly` in `test/fixtures/plans.yml`.
3. **Verify:** Sequentially run `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/helpers/plan_pricing_helper_test.rb` and `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test:system test/system/pricing_and_billing_system_test.rb`.

### Task 3 [subagent]: Update the yearly pricing preview

**Skills:** write-tests
**Reference:** Read [`test/components/previews/plan_card_component_preview.rb`](../../test/components/previews/plan_card_component_preview.rb) and the preview-backed test in [`test/components/plan_card_component_test.rb`](../../test/components/plan_card_component_test.rb).

**In scope:**

- Change the yearly preview plan to `12000`, `"$10/mo"`, and `"Billed $120/year"`.
- Update only the two assertions that render this preview.

**NOT in scope:**

- Component implementation or styling.
- Other component tests that pass arbitrary pricing strings directly into `PlanCardComponent`.
- Other Lookbook previews.

**Build order:**

1. **Test:** Change the preview-backed component test to expect `"$10/mo"` and `"Billed $120/year"`. Run it and confirm the unchanged preview fails.
2. **Implement:** Update `yearly_equivalent_plan` in `test/components/previews/plan_card_component_preview.rb`.
3. **Verify:** Run `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test test/components/plan_card_component_test.rb`. Once Tasks 1–3 are complete, the master runs `review-changes-mini` exactly once for checkpoint 1; if Tasks 2–3 were implemented in parallel, wait for both to return first.

### Task 4 [Master]: Validate the staging Stripe account

**Skills:** None — read-only browser/operator workflow
**Reference:** Read [`app/views/checkouts/forms/_stripe.html.erb`](../../app/views/checkouts/forms/_stripe.html.erb), [`config/routes/madmin.rb`](../../config/routes/madmin.rb), and [`docs/runbooks/price-change-checklist.md`](../runbooks/price-change-checklist.md).

**In scope:**

- Use Jordan’s existing authenticated Chrome sessions.
- Load a staging checkout page and inspect its Stripe public-key data attribute.
- Extract the account identifier from `pk_test_51<account_id>...` and compare it with the account open in Stripe.
- Identify the existing Premium product and the two existing staging Premium Plan rows without changing anything.
- Save useful, secret-safe screenshots under `.context/`.

**NOT in scope:**

- Requesting, displaying, storing, or copying passwords, private keys, or full credentials.
- Creating Stripe objects or editing staging data.
- Assuming that “test mode” or “sandbox” proves the accounts match.

**Build order:**

1. **Test:** Confirm authenticated access to staging checkout, `/admin/plans`, and Stripe; inspect the rendered public-key attribute without exposing its full value in chat or screenshots.
2. **Implement:** Compare account identifiers and identify the exact existing Premium product and monthly/yearly Plan rows that Task 5 would change.
3. **Verify:** Report the account match, target product, and intended immutable Price creations, then stop for Jordan’s explicit approval immediately before creating either Price.

### Task 5 [Master]: Create Prices and update staging Plan rows

**Skills:** None — confirmation-gated browser/operator workflow
**Reference:** Follow the approved departure recorded in [`docs/designs/cov-88-raise-premium.md`](../designs/cov-88-raise-premium.md), while retaining the Stripe account check from the price-change runbook.

**In scope:**

- After explicit approval, create a recurring `$12/month` Price and a recurring `$120/year` Price on the existing sandbox Premium product.
- Edit the two existing staging Premium Plan rows in place with the corresponding amount, Stripe Price ID, and `trial_period_days: 0`.
- Record both non-secret `price_...` identifiers for Task 6.

**NOT in scope:**

- Creating another Stripe product or additional Plan rows.
- Hiding or deleting the existing Plan rows.
- Editing live-mode Stripe data, moving subscribers, or changing subscription quantities.
- Proceeding if the account identifier no longer matches.

**Build order:**

1. **Test:** Immediately recheck the matched Stripe account and confirm Jordan’s approval is current before the first immutable Price creation.
2. **Implement:** Create both sandbox Prices, then update the existing monthly and yearly staging Plan rows in place.
3. **Verify:** Confirm Stripe shows the correct product, amounts, currencies, recurrence intervals, and IDs; confirm `/admin/plans` shows the corresponding values on exactly the two intended rows.

### Task 6 [Master]: Verify staging and record Price IDs

**Skills:** review-changes-mini
**Reference:** Read [`docs/runbooks/price-change-checklist.md`](../runbooks/price-change-checklist.md) and exercise the existing `/pricing` and checkout flows.

**In scope:**

- Verify staging shows unchanged Free pricing plus one Premium option per interval at `$12/month` and `$120/year`.
- Follow both Premium links through to working Stripe sandbox checkout sessions.
- Add a “Current price IDs” section to the runbook containing both sandbox IDs and a note that COV-78 still needs live-mode equivalents.
- Tell Jordan to save both IDs in his own records.
- Run the complete local verification required by the design.

**NOT in scope:**

- Changing the runbook’s general new-row-plus-hide procedure.
- Completing COV-78 or configuring production URLs or live-mode Prices.
- Entering payment details or completing a charge.

**Build order:**

1. **Test:** In staging, inspect both billing intervals, count the Free and Premium cards, verify all displayed amounts, and open each Premium checkout link. Capture secret-safe evidence under `.context/`.
2. **Implement:** Update `docs/runbooks/price-change-checklist.md` with the two current sandbox Price IDs and the COV-78 live-mode note.
3. **Verify:** Sequentially run `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test`, `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test:system`, `git diff origin/main...`, and `git status --short`. Then run `review-changes-mini` exactly once for checkpoint 2 after Tasks 4–6 are all complete.

## Task Dependencies

- Task 1 establishes the authoritative reseeding behavior.
- Tasks 2 and 3 may be implemented in parallel after Task 1, but their Rails test processes must run sequentially.
- Task 4 begins only after checkpoint 1 passes.
- Task 5 depends on Task 4’s exact account match and Jordan’s explicit approval immediately before Price creation.
- Task 6 depends on both new Prices and both staging Plan-row updates from Task 5.
- Production and live-mode Stripe work remain deferred to COV-78.
