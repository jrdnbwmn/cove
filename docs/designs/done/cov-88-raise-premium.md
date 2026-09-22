> Plan created: docs/plans/cov-88-raise-premium.md

> Ticket: COV-88
> Branch: feature/cov-88-raise-premium

# Feature: Raise Premium to $12/mo and $120/yr

## Problem

Premium is priced at $9/mo (`amount: 900`) and $84/yr (`amount: 8400`). At $84/yr
the contribution margin is ~$6.29/family/mo after Stripe, sales tax, AI, and
email; at $120/yr it is ~$9.19, dropping the families needed for $10k/mo profit
from ~1,705 to ~1,167. It also makes planned AI features affordable — at $7/mo
effective they would consume ~10% of margin.

Production is dormant (`render.yaml:41-76` is commented out) and nobody has ever
paid. This is the last moment the change is a data edit rather than a migration
with customer comms.

## Approach

Change the two amounts in seed and fixture data, update the tests that assert the
old numbers, and swap the two staging Plan rows to new Stripe Prices in place.

### Target pricing

|                              | Current        | New                |
| ---------------------------- | -------------- | ------------------ |
| Monthly                      | $9.00 (`900`)  | **$12.00 (`1200`)** |
| Yearly                       | $84.00 (`8400`) | **$120.00 (`12000`)** |
| Effective monthly on annual  | $7.00          | $10.00             |
| Annual discount              | 22%            | 17%                |

Free tier is unchanged.

### Deliberate departure from the price-change runbook

`docs/runbooks/price-change-checklist.md` says plan rows are never re-priced — a
price change means a new Stripe Price, a new Plan row, and a hidden old row. The
ticket proposed following it anyway as a rehearsal for COV-78.

**We are not doing that.** Decision recorded: no one has ever paid either price
and the only live environment is staging, so the old values are not needed
anywhere. The two staging Plan rows are edited in place — new `amount`, new
`stripe_id` — with no new rows and no hidden legacy rows.

Consequences to carry into COV-78:

- The new-Plan-row-plus-hide path will be executed for the first time, unrehearsed,
  during the live-mode cutover.
- The runbook itself is **not** being changed. It still describes the correct
  procedure for any environment with real subscribers.

One half of the runbook is not optional and is still followed: **Stripe `Price`
objects are immutable.** A price's `unit_amount` cannot be edited after creation,
so two new Prices on the existing Premium product are created regardless.

## Acceptance Criteria

- `/pricing` on staging shows Premium at $12/month and $120/year, one card per
  interval, plus the unchanged Free card.
- Both checkout links reach a working Stripe checkout session in the sandbox.
- A fresh `bin/rails db:seed` produces the new amounts, **and** reseeding a
  database that already holds the old rows also produces them.
- `bin/rails test` and `bin/rails test:system` pass.
- The new Stripe price IDs are recorded in the runbook and reported to Jordan for
  his own credential store — COV-78 needs live-mode equivalents.

## Prototype

None. No visual change — prices are data-driven.

## Data Model

No schema change. `Plan` rows only.

Prices are already data-driven: `app/views/pricing/_premium_card.html.erb` renders
from the `Plan` row, `pricing.show.premium.yearly_price_note` interpolates the
amount, and `PlanPricingHelper#monthly_equivalent` derives the effective monthly
figure. The only literal price string in any view is `"$0"` on the Free card
(`app/views/pricing/_free_card.html.erb:5`). There is no "save 22%" copy anywhere,
so the discount change to 17% needs no edit.

`monthly_equivalent` on the new yearly plan: `12000 / 1200` = exactly `$10`, and
the helper strips `.00`, so it renders `"$10/mo"`.

## Screens / Flows

No flow changes. `/pricing` and `/billing/subscriptions/edit` render whatever
`Plan.visible.sorted` returns, partitioned into monthly and yearly
(`app/controllers/public_controller.rb:5`).

## Scope

**In — code, 6 files:**

| File | Change |
| ---- | ------ |
| `db/seeds.rb:61-75` | `900`→`1200`, `8400`→`12000`, plus an explicit `update!` of `amount` (see below) |
| `test/fixtures/plans.yml` | `premium_monthly`→`1200`, `premium_yearly`→`12000` |
| `test/config/seeds_test.rb:37-38` | assert `1200` / `12000` |
| `test/helpers/plan_pricing_helper_test.rb:19` | `"$7/mo"`→`"$10/mo"` |
| `test/system/pricing_and_billing_system_test.rb:33-34` | `"$7/mo"`→`"$10/mo"`, `"billed $84 yearly"`→`"billed $120 yearly"` |
| `test/components/previews/plan_card_component_preview.rb:17-19` | `8400`→`12000`, `"$7/mo"`→`"$10/mo"`, `"Billed $84/year"`→`"Billed $120/year"` |

**Seeds must upsert.** `db/seeds.rb` currently uses
`Plan.find_or_create_by!(fake_processor_id: "premium_monthly")`. On any database
that already holds that row — a developer's local DB — reseeding will silently
leave the amount at `900`. Changing the literal alone does not satisfy the
acceptance criterion. Add an explicit `update!` of `amount` so reseeding is
authoritative. This only touches dev-only `fake_processor` data, so the
never-re-price rule is not in play.

**In — browser work, done by Claude:**

1. Load a staging checkout page and read `Pay::Stripe.public_key` out of the DOM
   (`app/views/checkouts/forms/_stripe.html.erb:4` renders it into a data
   attribute). Extract the account ID from `pk_test_51<account_id>...`.
2. Open the Stripe dashboard and confirm the open account matches that ID —
   "test mode" and "sandbox" can be different accounts.
3. Create two Prices on the **existing** Premium product: $12/month and
   $120/year. Do not create a new product. Confirm with Jordan immediately
   before creating, since Stripe Prices can be archived but never deleted.
4. At staging `/admin/plans` (Madmin, `config/routes/madmin.rb:22`), edit the two
   existing Premium rows in place: new `amount`, new `stripe_id`,
   `trial_period_days: 0`.
5. Verify `/pricing` renders one Free card plus exactly one Premium card per
   interval, at $12 and $120.
6. Click through both checkout links and confirm each reaches a live sandbox
   checkout session.
7. Add a "Current price IDs" section to
   `docs/runbooks/price-change-checklist.md` recording the two new IDs, noting
   that COV-78 needs live-mode equivalents.

**Only Jordan can do:**

- Be signed into the Stripe dashboard and into staging as a system admin in
  Chrome before the browser steps run. Claude drives the existing session; it
  does not need and should not be given passwords.
- Approve the Stripe Price creation at step 3.
- Save the new price IDs into his own credential store.
- Review and merge the PR.

**Deferred:**

- Live-mode Stripe setup — COV-78.
- Any second paid tier. Children aren't modeled yet, so there's no dimension to
  tier on.
- Changing flat-per-family billing. Adding or removing a parent must still not
  change subscription quantity.
- Marketing copy rewrites beyond what breaks from the number changing — nothing
  does.

## Edge Cases

- **Existing seeded subscription.** `subscribed@cove.test` holds a
  `fake_processor` subscription to `premium_monthly` (`db/seeds.rb:78-82`).
  It references the plan by `fake_processor_id`, not by amount, so the price
  change does not touch it. No Stripe-side migration — there is no Stripe-side.
- **Staging has no console.** Render's free tier provides no Shell or One-Off
  Jobs, so `/admin/plans` is the only way to change those rows. If an edit
  doesn't stick there is no `bin/rails console` fallback. Per AGENTS.md, verify
  by observable behavior — `/pricing` rendering $12 — not by the admin form
  looking correct.
- **Stale `processor_plan` references.** A local `Pay::Subscription` row's
  `processor_plan` can point at a Stripe object that doesn't exist for whatever
  account credentials currently resolve to, failing late inside
  `CheckoutsController#set_checkout_session` as `Stripe::InvalidRequestError`.
  If checkout verification fails that way, check the account ID before assuming
  the price IDs are wrong.
- **Local checkout testing.** Seeded plans carry only `fake_processor_id` and no
  `stripe_id`, so local checkout does not hit Stripe. To exercise real checkout
  locally, paste a sandbox price ID into the local plan's Stripe ID field at
  `/admin/plans`, per the runbook.

## Tests Deliberately Left Alone

- `test/helpers/plan_pricing_helper_test.rb` keeps its second assertion,
  `monthly_equivalent(Plan.new(amount: 9000, interval: "year")) == "$7.50/mo"`.
  That synthetic plan exercises the non-round-cents formatting path, which the
  real fixture no longer covers — `12000 / 1200` is exactly `$10`. Worth keeping
  precisely because the fixture stopped testing it.
- `test/components/plan_card_component_test.rb`'s `"Billed $84/year"` assertions.
  That string is passed *into* the component as `price_note` and echoed back, so
  it tests the component, not Cove's pricing. Changing it would be noise.
- The other Jumpstart demo fixtures (`personal`, `business`, `per_seat`,
  `enterprise`, etc.) — unrelated to Cove's pricing.

## Open Questions

None.
