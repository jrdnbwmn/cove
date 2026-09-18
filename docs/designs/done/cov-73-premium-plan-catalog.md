> Plan created: docs/plans/cov-73-premium-plan-catalog.md
> Ticket: COV-73
> Branch: feature/cov-73-premium-plan-catalog

# Feature: Premium plan catalog (dev, test, staging)

## Problem

No real plans exist. Premium needs a monthly and a yearly plan in every
environment, set up so prices can change later without breaking existing
subscribers — and a deleted Plan row currently crashes the billing page for
anyone subscribed to it (COV-71 gap 7).

## Approach

- **Catalog data:** Premium monthly ($9) and yearly ($84) as `Plan` rows in dev
  seeds, test fixtures, and (entered by hand at `/admin/plans`) staging. No trial.
- **Delete guard in the model (option 2):** `Plan` refuses to be destroyed while
  any `Pay::Subscription` (any status, including canceled) references one of its
  processor IDs. `Madmin::PlansController#destroy` shows a message when refused.
  Model-level so the rule holds from admin, console, or any future path.
- **Price-change runbook:** `docs/runbooks/price-change-checklist.md` is the
  single durable copy. `AGENTS.md` gets a one-line rule pointing to it; COV-78
  gets a one-line pointer (Jordan pastes it — no Linear tool in session).
- **Staging setup:** Claude creates the Stripe product/prices via API in the
  Cove sandbox and enters the Plan rows at `/admin/plans` via browser, after the
  code merges.

No new screens, components, or migrations.

## Acceptance Criteria

- [ ] Locally, `/pricing` lists Premium monthly and yearly, and the toggle pairs them
- [ ] Checkout for either plan starts with no trial — proven by an automated test
      on the Stripe checkout session args, and by live staging checkouts
- [ ] Test: a Plan referenced by a subscription can't be deleted (model + admin)
- [ ] Test: a Plan with no referencing subscriptions can still be deleted
- [ ] Staging: a test card completes checkout for both intervals, and the
      subscription syncs via webhook
- [ ] Price-change checklist exists at `docs/runbooks/price-change-checklist.md`
- [ ] `AGENTS.md` carries the one-line "never delete/re-price a Plan row" rule
- [ ] COV-78 pointer line handed to Jordan to paste

## Prototype

None.

## Data Model

**No migrations.** `plans` already has `hidden` and one ID column per
processor (`stripe_id`, `fake_processor_id`, `braintree_id`,
`paddle_billing_id`, `paddle_classic_id`, `lemon_squeezy_id`).

Background (from the ticket):
- One `Plan` row = one Stripe Price. `amount` is cents per interval.
- Monthly and yearly versions pair by sharing the same `name`.
- Stripe Prices can't be edited: a price change = new Stripe Price + new Plan
  row. Existing subscribers stay on the old one.
- Subscriptions look up their plan by processor ID
  (`config/initializers/pay.rb` — `Plan.where("#{processor}_id": processor_plan)`,
  no `hidden` filter), so old rows must be **hidden, never deleted**.
- Staging/prod plans are entered by a superadmin at `/admin/plans`. No prices
  in code or credentials.

### `Plan` (`lib/jumpstart/app/models/plan.rb`)

- `before_destroy` guard: collect the plan's non-blank processor IDs; if any
  `Pay::Subscription.where(processor_plan: ids)` exists, add an error to the
  plan and `throw :abort`.
- Any subscription status counts (canceled subscriptions still render in
  billing history and look up their plan).
- Deliberately does **not** scope by the subscription's processor — slightly
  over-broad, which is the safe direction, and keeps the check simple.
- Result: `destroy` returns `false`; `destroy!` raises.

### `Madmin::PlansController` (`lib/jumpstart/app/controllers/madmin/plans_controller.rb`)

- Override `destroy`: on success, redirect to the plans index as today; on
  refusal, redirect to the plan's show page with a flash alert:
  *"This plan has subscribers, so it can't be deleted. Hide it instead."*
  The Madmin layout already renders flash (`madmin/application/_flash`).
- Message text lives in locale files.

### Dev seeds (`db/seeds.rb`)

Replace the "Cove Dev Plan" block with two plans, idempotent via
`find_or_create_by!(fake_processor_id: ...)`:

| | name | amount | interval | fake_processor_id | trial_period_days |
|---|---|---|---|---|---|
| monthly | Premium | 900 | month | `premium_monthly` | 0 |
| yearly | Premium | 8400 | year | `premium_yearly` | 0 |

- Both get a placeholder `features` list (final copy belongs to COV-77).
- No `stripe_id` in seeds (keeps Stripe IDs out of code).
- Seeded subscribed family (`subscribed@cove.test`) subscribes to
  `premium_monthly` via the fake processor.
- `test/config/seeds_test.rb` should cover the new plans / subscription.

### Test fixtures (`test/fixtures/plans.yml`)

- Add `premium_monthly` and `premium_yearly` with the same values, plus stand-in
  `stripe_id`s (`premium-monthly`, `premium-yearly`) and matching
  `fake_processor_id`s.
- Keep every existing Jumpstart fixture — engine tests use them.
- Risk: two more visible plans appear on `/pricing` in existing tests
  (`test/integration/plans_test.rb` etc.). Check during implementation.

## Screens / Flows

No new screens or components.

| Screen | Change |
|---|---|
| `/pricing` | None — existing monthly/yearly toggle + plan cards pick up Premium rows |
| Stripe checkout | None — `CheckoutsController#set_checkout_session` omits trial when `trial_period_days` ≤ 1 |
| `/admin/plans/:id` | Refused delete lands here with the flash message |
| `/admin/plans` | None — existing Visible/Hidden scopes |

### A. Visitor on `/pricing` (local + staging)
1. Sees one **Premium** card at $9/month with placeholder features.
2. Toggles to Yearly → **Premium** at $84/year.
3. Get started → sign in/up → checkout with no trial.
4. On staging: Stripe test card → webhook → subscription appears in `/billing`
   and `/admin`.

**Local checkout caveat:** Stripe is the only configured processor, and seeds
have no `stripe_id`, so clicking Get started locally hits a Stripe error. This
is accepted. A dev who wants a real local checkout pastes the sandbox price ID
into their local plan at `/admin/plans` (documented in the runbook).

### B. Superadmin deletes a plan with subscribers
1. `/admin/plans` → plan → Delete.
2. Plan survives; redirected to its show page with the message.
3. Plans with no subscribers (e.g. a mistaken row) still delete normally.

### C. Price change (runbook)
1. Create a new Stripe Price on the existing "Premium" product.
2. Create a new Plan row at `/admin/plans` — **same `name`**, new amount, new
   Stripe ID.
3. Hide the old row in the same sitting. Never delete it. Never edit its
   `amount` or `stripe_id`.
4. Decide whether to move existing subscribers to the new price.

### D. Developer runs `bin/rails db:seed`
- Gets Premium monthly + yearly; subscribed family on Premium monthly.
- Existing local DBs keep their old `cove_dev` row/subscription — accepted;
  `db:reset` for a clean catalog. No cleanup code.

### E. One-time staging setup (Claude, after merge)
1. Verify the Stripe account: staging publishable key (`pk_test_51Tw25A…`) must
   match Cove sandbox `acct_1Tw25AAVvDn1V5lJ`. Use
   `stripe ... --project-name cove` (the CLI was previously logged into
   "Thistle Books sandbox").
2. Create product "Premium" with a $9/month and an $84/year price.
3. Enter both Plan rows at `/admin/plans` (name "Premium", amounts 900 / 8400,
   intervals, `trial_period_days: 0`, Stripe IDs, placeholder features).
4. Hide staging's "Cove Dev Plan" row (don't delete — the seeded fake
   subscription references `cove_dev`). Archive the old $19 Stripe price
   (`price_1TxIO4…`).
5. Test-card checkout for monthly and yearly using **two separate test
   families** (checkout redirects already-subscribed families). Confirm each
   subscription syncs via webhook.

## Edge Cases

- Plan with all processor IDs blank → deletable.
- Plan referenced only by a canceled subscription → not deletable (intended).
- Hiding a subscribed plan is allowed; subscribers' billing pages keep working.
- Only one interval hidden → toggle still works with whatever is visible.
- Two visible rows in the same interval → two Premium cards; runbook says hide
  the old row in the same sitting.
- Staging checkout doesn't sync → first check the webhook signing secret in
  credentials against the one in Stripe (see `AGENTS.md` gotcha).

## Scope

**In:**
- `Plan` delete guard + Madmin refusal message + locale string
- Dev seeds: Premium monthly/yearly, subscribed family on monthly, remove
  "Cove Dev Plan"
- Fixtures: `premium_monthly`, `premium_yearly`
- Tests: delete guard (model + admin request), checkout session has no trial
  for both Premium plans, seeds
- `docs/runbooks/price-change-checklist.md` (incl. local-checkout tip)
- One-line rule in `AGENTS.md` under Current Project Decisions:
  > Plan rows are never deleted or re-priced — a price change is a new Stripe
  > Price + new Plan row, old row hidden. Follow
  > `docs/runbooks/price-change-checklist.md`.
- Staging Stripe + `/admin/plans` setup and live checkout verification (flow E)
- COV-78 pointer text for Jordan to paste:
  > Recreate Premium prices in live mode — follow
  > `docs/runbooks/price-change-checklist.md`.

**Deferred:**
- Blocking edits to `amount`/`stripe_id` on a plan with subscribers (possible
  follow-up ticket)
- Cleanup of stale plan rows in existing local databases
- Pricing display ("$7/mo billed yearly"), Free card, no-refund copy, final
  features copy — COV-77
- Live-mode prices — COV-78

## Open Questions

None.

## More Info

- Depends on COV-72 (merged). Blocks COV-74, COV-77, COV-78.
- Product rules this builds on are recorded in
  `docs/designs/cov-71-monetization-family-audit.md` ("Product rules" section):
  Premium $9/mo or $84/yr, flat per family, no trial, and **no feature logic may
  depend on a price, amount, plan name, or Stripe ID**.
- `Plan#find_interval_plan` / `annual_version` / `monthly_version` pair by name
  without a `visible` filter, but nothing in the app calls them today — not a
  concern for this ticket.
