> Plan created: docs/plans/cov-77-pricing-and-billing-pages.md

> Ticket: COV-77
> Branch: feature/cov-77-pricing-and-billing-pages-for-free-vs-premium

# Feature: Pricing and billing pages for Free vs Premium

## Problem

The pricing page shows only paid plans with trial wording, and the billing page
says "You are not currently subscribed" to every family that isn't paying —
including complimentary testers. Families can't see which tier they're on, what
Premium covers, or what happens to their money when they cancel.

## Approach

View work only. No migration, no new model, no change to the subscription
machinery. Everything is a read of what COV-73 (plans), COV-74 (`premium?`,
`students_allowed`) and COV-75 (`plan_status`, complimentary) already landed.

Two small seams carry the logic:

1. **`app/helpers/pricing_helper.rb`** (new) — `monthly_equivalent(plan)` for the
   "$7/mo, billed $84 yearly" line, and `premium_student_limit` for card copy.
   **Not** added to `PlanHelper`: that module lives in the engine
   (`lib/jumpstart/app/helpers/plan_helper.rb`), and defining a second
   `PlanHelper` under `app/helpers/` would shadow it and silently drop
   `formatted_plan_interval`.
2. **`app/views/billing/_plan_state.html.erb`** (new) — one partial rendering the
   Free / Premium / Complimentary / Canceled block at the top of `/billing`.
   Jumpstart's existing `_subscription` partial still renders beneath it for
   paid families, so change-plan, update-card and cancel are untouched.

All no-refund copy is written once in `en.yml` and reused.

## Acceptance Criteria

System tests, one per criterion:

- [ ] A Free family sees Free as its current plan and can upgrade
- [ ] A Premium family sees Premium as its current plan and can switch
      monthly↔yearly
- [ ] A comped family sees complimentary Premium
- [ ] The second parent sees the same billing state as the owner
- [ ] A canceled family's billing page shows the date Premium ends
- [ ] No-refund wording appears on pricing, checkout, and cancel confirmation
- [ ] No trial wording appears on pricing, checkout, billing, or cancel

## Prototype

None. Jordan confirmed no prototype will be supplied; the design uses existing
catalog components (`PlanCardComponent`, `CardComponent`, `BadgeComponent`,
`AlertComponent`, `ButtonComponent`). No new components.

## Data Model

**No migration. No new model.**

| What the view needs | Source |
|---|---|
| Which tier | `Account#plan_status` → `"premium"` / `"complimentary"` / `"free"` |
| Free student count | `Account::FREE_STUDENT_LIMIT` |
| Premium student count | signed in: `current_account.students_allowed`; signed out: `Account.column_defaults["student_limit"]` |
| Price and interval | `Plan#amount`, `#interval`, `#monthly?` / `#yearly?`, `Plan.visible.sorted` |
| Renewal date | `Pay::Subscription#current_period_end` (confirmed present in `db/schema.rb`) |
| End-of-Premium date (after cancel) | `Pay::Subscription#ends_at`, gated on `#on_grace_period?` |
| Which Premium card is current | `subscription.plan == plan`, the comparison the swap page already uses |

Two notes that drive the design:

- **`plan_status` cannot express "canceled but still Premium."** Pay's `active`
  scope includes a canceled subscription inside its paid period, so
  `plan_status` correctly returns `"premium"`. The canceled state is read from
  the subscription (`on_grace_period?` + `ends_at`), not from `plan_status`. It
  is a variation of Premium, not a fifth tier.
- **The billing controller already loads everything needed.** `@subscriptions`
  is active-or-past-due-or-unpaid. The new partial reads
  `current_account.plan_status` and `@subscriptions.first`. No controller
  change, no extra query.

## Screens / Flows

### `PlanCardComponent` — three optional arguments

`plan:` becomes optional and three overrides are added, each defaulting to
today's plan-derived value, so all four existing call sites keep working:

- `price_text:` — "$0" for Free; also renders "$7/mo" on the yearly card
- `price_note:` — small line under the price: "billed $84 yearly", "forever"
- `features:` — the locale-sourced list

Rejected alternative: a `FreePlan` null object impersonating a `Plan`. It needs
the same component branches (no interval, no Stripe id) plus a fake record to
maintain. `Plan.free` exists in the engine but **creates a hidden $0 row in the
database**, which is exactly the "no plan row" the ticket rules out.

Requires updating `docs/COMPONENT_CATALOG.md`, the Lookbook preview and
`test/components/plan_card_component_test.rb` — run `/update-catalog` and
`/update-component-previews` at the end.

### Pricing page (`/pricing`)

Existing `pricing` Stimulus controller and monthly/yearly toggle are untouched.
Inside each frequency group the Free card renders first, then Premium. The Free
card is rendered in both groups — it's static, so duplicating it is cheaper than
restructuring the grid around the toggle.

Monthly shows "$9/mo". Yearly shows "$7/mo" with "billed $84 yearly" beneath,
both computed from `Plan#amount` — never typed into the view.

| Who's looking | Free card | Premium card |
|---|---|---|
| Signed out | "Get started free" → sign up | "Get Premium" → checkout |
| Free family | "Current plan", disabled | "Upgrade" → checkout |
| Premium family (paid) | no button | matching interval: "Current plan", disabled. Other interval: "Change plan" → swap page |
| Complimentary family | no button | "Current plan", disabled |
| Canceled, still in paid period | no button | "Current plan", disabled — no end date here; the date lives on the billing page only |

No-refund sentence below the grid, muted.

### Billing page (`/billing`)

New `billing/_plan_state.html.erb` above the subscriptions section:

1. **Free** — `CardComponent`: "You're on Free", the student-limit line, and an
   "Upgrade to Premium" `ButtonComponent` → pricing.
2. **Premium (paid)** — `BadgeComponent` "Premium", plan name, interval,
   "Renews <date>". Jumpstart's `_subscription` partial renders below with its
   existing change-plan / update-card / cancel buttons.
3. **Complimentary** — `BadgeComponent` "Complimentary Premium", a line saying
   there's nothing to pay, and a secondary "Subscribe to Premium" link. Nothing
   else renders: no subscription, no receipts, no payment method — a comped
   family has none of them.
4. **Canceled in grace** — `AlertComponent` (warning): "Premium until <date>,
   then Free". The existing Resume button handles resubscribing.
5. **Past due** — unchanged from today: keeps Premium, red badge, update-card
   prompt.

`_email`, `_info` and `_charges` continue to render for paid families only.

Both parents are admins, so the second parent sees this same page — a test, not
new code.

### No-refund wording — four placements

One sentence in `en.yml` reused by the first two; cancel and delete differ
because they carry a date or a different consequence.

- **Pricing page**, under the cards: cancel anytime; you keep Premium until the
  end of the period you've paid for; no refunds for unused time.
- **Checkout**, the same sentence in muted text **under the Stripe embedded
  form** — text can't go inside Stripe's iframe.
- **Cancel confirmation** — replaces the current `active_until` string with the
  exact date plus "No refund is issued for the remaining time."
- **Family deletion**, two confirm dialogs: the owner's Delete Family button on
  `accounts/edit`, and the owner's Delete Login button on
  `devise/registrations/edit` (which destroys the owned family with it) — the
  subscription ends immediately, no refund.

### Trial removal

Delete the trial branches and their locale keys from the app's own views:
`pricing/show` (the `start_trial` branch), `checkouts/show`,
`billing/subscriptions/_subscription`, `billing/subscriptions/edit`, and the
sample text in `dev/kitchen_sink/show`.

Leave untouched: the `lib/jumpstart/` engine copies (the app's views already
override them) and `Plan#trial_period_days`, which COV-73 set to 0 and which Pay
still reads. The no-trial test asserts against the real pages listed above
rather than crawling the app.

## Decisions taken in this session

- **Complimentary families**: shown "Complimentary Premium" with a quiet
  "Subscribe to Premium" link, not an upsell — they already have everything.
  Subscribing does **not** clear the comp flag. `plan_status` already ranks paid
  above comp, so a later cancellation drops them back to complimentary rather
  than Free, and a superadmin turns the flag off when they want to.
- **Nav badge**: skipped. The ticket made it conditional on a prototype, and
  there isn't one; billing and pricing both state the tier.
- **Card copy lives in `en.yml`** (`pricing.show.free.features`,
  `pricing.show.premium.features`), not in each `Plan` row's
  `details.features`: Free has no Plan row, the monthly and yearly Premium rows
  would otherwise need identical lists kept in sync, and a copy change becomes a
  locale edit instead of a Stripe-adjacent data edit. Seeded with the known
  facts — Free: "1 student", "One parent"; Premium: "Up to 10 students", "Both
  parents" — with numbers interpolated from `Account`. Jordan supplies final
  copy later.
- **Yearly rounding**: round to the nearest cent, hide trailing zeros. $84 →
  "$7/mo"; a hypothetical $90 → "$7.50/mo".
- **Free price line**: "$0" with the note "forever", not "$0/month".
- **Interval switching** stays on the existing swap page, so proration remains
  Stripe's default. (COV-71 lists yearly→monthly proration as an open product
  question; this ticket doesn't change it.)
- **"Both parents"** is a feature line, not a computed number — families have
  one or two parents, and the card describes what Premium covers.

## Edge Cases

| Case | Behavior |
|---|---|
| Family on a grandfathered (now-hidden) price | No visible card matches, so nothing is marked "Current plan". **A Premium family never sees "Upgrade"** — every Premium card shows "Change plan" → swap page. Only Free families see "Upgrade". |
| Cancel page date source | Before cancellation `ends_at` is nil, so the cancel confirmation reads `current_period_end`; the billing page reads `ends_at` after. Using `ends_at` on the cancel page renders a blank date. |
| Missing period date (fake processor in dev, unsynced Stripe row) | Fall back to the undated sentence rather than printing a blank. Fixtures set `current_period_end` explicitly so tests still assert a real date. |
| Comped family that also subscribes | `plan_status` is `"premium"`; they see the ordinary Premium block. The comp flag stays visible only to superadmins in `/admin/accounts`. |
| Past due | Unchanged: keeps Premium, red badge, update-card prompt; pricing shows "Change plan". |
| Canceled and fully ended | Pay's `active` scope excludes it → `plan_status` is `"free"` → Free block with Upgrade. |
| No visible plans at all | `PricingController` keeps redirecting home with its admin alert — a misconfigured environment, not a state to design for. |
| Only one interval configured | Existing Stimulus controller hides the toggle. Unchanged. |
| Non-admin on `/billing` | Both parents are admins, so the "contact your admin" branch is unreachable today. Left as-is rather than deleted. |

## Scope

**In:**

- `app/helpers/pricing_helper.rb` — `monthly_equivalent`, `premium_student_limit`
- `PlanCardComponent` — optional `plan:`, new `price_text:`, `price_note:`,
  `features:`; catalog, preview and component test updated
- `app/views/pricing/show.html.erb` — Free card, yearly line, per-viewer
  buttons, no-refund line, trial branch removed
- `app/views/billing/_plan_state.html.erb` (new) + render from
  `billing/show.html.erb`
- `app/views/billing/subscriptions/cancels/show.html.erb` — dated no-refund copy
- `app/views/checkouts/show.html.erb` — no-refund line under the Stripe embed;
  trial branch removed
- `app/views/accounts/edit.html.erb` and
  `app/views/devise/registrations/edit.html.erb` — no-refund clause in the
  delete confirmations
- `app/views/billing/subscriptions/_subscription.html.erb`,
  `billing/subscriptions/edit.html.erb`, `dev/kitchen_sink/show.html.erb` —
  trial wording removed
- `config/locales/en.yml` — Free/Premium card copy, the shared no-refund
  sentence, the four billing states; trial keys removed
- Fixtures for the states the tests need: canceled-in-grace subscription with
  `ends_at`, paid subscription with `current_period_end`
- System tests, one per acceptance criterion; helper unit test for
  `monthly_equivalent`

**Deferred:**

- Free/Premium badge in the nav (no prototype)
- Final marketing copy for the card feature lists — placeholders ship with the
  known facts
- Yearly→monthly proration behavior (COV-71 open question)
- Live-mode prices and launch checks — COV-78
- Downgrade behavior for students past the limit — Students ticket

## Open Questions

None.

## More Info

- Product rules: `docs/designs/cov-71-monetization-family-audit.md` ("Product
  rules" section) — Premium $9/mo or $84/yr flat per family, no trial, no
  refunds, `past_due` keeps Premium, and **no feature logic may depend on a
  price, amount, plan name, or Stripe ID**.
- Prior tickets: `docs/designs/done/cov-73-premium-plan-catalog.md`,
  `cov-74-premium-check-and-family-student-limit.md`,
  `cov-75-complimentary-premium-for-testers.md`.
- Price changes follow `docs/runbooks/price-change-checklist.md` — Plan rows are
  never deleted or re-priced.
- `premium?` in controllers and views comes from
  `app/controllers/concerns/premium_access.rb` and needs no change.
- System-test gotchas from `AGENTS.md`: run a single test with the positional
  file argument and `-i`, not `-n`; use `find("[aria-label='...']").click`
  rather than `click_button` against `aria-label`.
