> Ticket: COV-94
> Branch: fix/cov-94-yearly-to-monthly-renewal
> Plan created: docs/plans/yearly-to-monthly-at-renewal.md

# Feature: Yearly → monthly takes effect at renewal

## Problem
When a yearly Premium subscriber switches to monthly, `Billing::SubscriptionsController#update`
calls Pay's `swap`, which changes the plan immediately with `proration_behavior: "always_invoice"`
(crediting unused yearly time — effectively a refund, against the no-refund policy), warns only
with a generic "Are you sure?", and sets `cancel_at_period_end: false` (silently un-canceling a
canceled subscription). Parents need a switch that happens at the end of the paid year, with clear
copy and no side effects.

## Approach
- **Yearly → monthly** is scheduled for the end of the current paid period using a **Stripe
  subscription schedule** (Pay doesn't wrap schedules — Stripe API directly). No proration, no credit.
- **Monthly → yearly** stays immediate with proration via Pay's `swap` (customer is paying more,
  so it doesn't conflict with no-refunds).
- Schedule logic lives in **one module on `Pay::Subscription`** (three methods: schedule, read
  pending, release), included from the existing `ActiveSupport.on_load :pay_subscription` block
  in `config/initializers/pay.rb`. It's shared by the plan-change controller, the new "Keep
  yearly" action, the cancel flow, and family deletion.
- **No migration.** The pending change is read from Pay's stored copy of the Stripe subscription
  (`pay_subscriptions.object`, which already expands `schedule`).
- Both directions go through a **confirmation page** (modeled on `cancels/show`) instead of a
  `turbo_confirm` dialog.
- Plan changes are **blocked server-side** for subscriptions that aren't plainly active (grace
  period, past due, unpaid), so `swap` can never un-cancel.

### Spike results (Stripe sandbox `acct_1Tw25AAVvDn1V5lJ`, test clock, 2026-10-01)
Verified with the real Cove sandbox prices (monthly `price_1UIYqBAVvDn1V5lJCfF44Njc`, yearly
`price_1UIYqaAVvDn1V5lJYebDXeFF`). The test clock and its objects were deleted afterward.

1. `POST /v1/subscription_schedules` with `from_subscription=<sub>` creates a schedule with one
   phase (current yearly price, `start_date` = period start, `end_date` = `current_period_end`).
   It also sets `subscription.schedule` → fires `customer.subscription.updated`
   (`previous_attributes: {schedule: null}`).
2. `POST /v1/subscription_schedules/<id>` with `end_behavior=release`, `proration_behavior=none`,
   `phases[0]` = yearly price with the same `start_date`/`end_date`, and `phases[1]` = monthly price,
   `duration[interval]=month`, `duration[interval_count]=1`, `proration_behavior=none` worked.
   **This fires only `subscription_schedule.updated`, which Pay doesn't handle** → the app must
   call `sync!` itself after updating the schedule. Also set `phases[0][proration_behavior]=none`
   explicitly (Stripe defaulted it to `create_prorations`).
3. At renewal the subscription switched to the monthly price, and the invoice was **exactly $12.00**
   (`subscription_cycle`, no credit lines). `customer.subscription.updated` fired (items/plan
   changed) → Pay's existing webhook syncs `processor_plan`.
4. **The schedule stays attached during the first monthly phase** (until it releases at that
   phase's end).
5. While a schedule is attached, `cancel_at_period_end=true` on the subscription fails:
   *"The subscription is managed by the subscription schedule …, and updating any cancelation
   behavior directly is not allowed."* → **always release any attached schedule before canceling.**
6. `POST /v1/subscription_schedules/<id>/release` sets `subscription.schedule` to null (fires
   `customer.subscription.updated`), keeps the current price, and cancel then works.

Not verified (so we release first as a precaution): whether immediate cancel (`cancel_now!`) and
`swap` succeed while a schedule is attached.

## Acceptance Criteria
- A yearly subscriber who switches to monthly stays on yearly until `current_period_end`, then is
  billed the monthly price with no proration or credit.
- Billing shows "Switching to monthly on <date>" plus a **Keep yearly** button while a switch is pending.
- Keep yearly removes the pending switch; the subscription renews yearly as normal.
- Monthly → yearly is still immediate and prorated.
- No "Are you sure?" dialog on the change-plan page; a confirmation page explains what happens,
  including the no-refund wording.
- A subscription that's canceled (grace period), past due, or unpaid can't reach plan change
  (edit, confirmation, or update), and no un-cancel request reaches Stripe.
- Canceling (any branch) and family deletion work while a switch is pending or during the first
  monthly month, and remove the pending switch.
- Tests cover all of the above, with Stripe stubbed by WebMock.

## Prototype
None.

## Data Model
**No migrations, no new tables.**

Source of truth: the Stripe subscription schedule. Pay's `Pay::Stripe::Subscription.sync` stores
the full Stripe subscription (with `schedule` expanded) in `pay_subscriptions.object`, so
`object["schedule"]["phases"]` has the upcoming monthly phase's price ID and `start_date`.

New module, e.g. `Pay::Subscription::PlanSchedule` (`app/models/pay/subscription/plan_schedule.rb`,
name not final), included in the `on_load :pay_subscription` block next to the existing
`plan`/`amount` extensions:

| Method | Behavior |
|---|---|
| `schedule_plan_change_at_renewal(plan)` | Create schedule `from_subscription`; update it with phase 0 = current price until `current_period_end`, phase 1 = target monthly price for one month, `proration_behavior: none` (top level + both phases), `end_behavior: release`; then `sync!`. If any step fails, release the schedule and re-raise as `Pay::Error`. |
| `pending_plan_change` | From the stored `object`: if `schedule` is an expanded hash with a phase whose `start_date` is in the future, return `{plan:, starts_at:}` (plan looked up by its Stripe price ID). Otherwise `nil`. No API call. Returns `nil` if `schedule` is a string/absent or no `Plan` matches the price. |
| `release_schedule!` | If a schedule is attached, release it and `sync!`. No-op otherwise. |

Decision rule (controller, using `Plan#yearly?`/`#monthly?`): current plan yearly and target
monthly → `schedule_plan_change_at_renewal`. Anything else → `release_schedule!` then Pay `swap`
(as today).

Callers that must `release_schedule!` before canceling:
- `Billing::Subscriptions::CancelsController#destroy` (`lib/jumpstart/app/controllers/…`) — before
  every branch (period-end `cancel`, `cancel_now!` for past due/unpaid, metered).
- `Account#cancel_billable_subscriptions!` (family deletion) — before `cancel_now!`.

Files under `lib/jumpstart/app/` are edited in place (as earlier tickets did), not overridden in `app/`.

## Screens / Flows
Only existing components: `CardComponent`, `AlertComponent`, `ButtonComponent`, the
`billing/subscriptions/summary` partial.

**Yearly → monthly**
1. Billing → **Change plan** → plan page → the Monthly card's **Change plan** (now a GET link).
2. Confirmation page → **Switch at renewal** → `PATCH subscriptions#update` schedules it.
3. Redirect to Billing, flash *"You'll switch to monthly on %{date}."*; the pending notice and
   **Keep yearly** are shown; Change plan is hidden.
4. **Keep yearly** → `DELETE plan_change` → `release_schedule!` → Billing, flash *"You'll stay on yearly."*
5. At renewal, Stripe switches the price; the webhook syncs; Billing shows Premium at $12/month.

**Monthly → yearly**: same confirmation page with yearly copy → `swap` (immediate, prorated) →
existing success flash.

**A. Billing page**
- `app/views/billing/_plan_state.html.erb`: when `pending_plan_change` is present, replace the
  "Renews on <date>" line with `AlertComponent` (`:info`). Title: *"Switching to monthly on
  %{date}"*. Description: *"You'll stay on yearly until then. After that, it's %{price}/month."*
- `app/views/billing/subscriptions/_subscription.html.erb`: when pending, replace **Change plan**
  with **Keep yearly** (secondary, `DELETE`). Other buttons are unchanged.

**B. Change plan page** (`app/views/billing/subscriptions/edit.html.erb`): each card's Change plan
form with `turbo_confirm: "Are you sure?"` becomes a `ButtonComponent` link to the confirmation
page. Layout unchanged.

**C. Confirmation page**: new `Billing::Subscriptions::PlanChangesController`, route
`resource :plan_change, only: [:show, :destroy]` nested under `resources :subscriptions`
(`/billing/subscriptions/:subscription_id/plan_change?plan=<plan prefix id>`). Sidebar layout,
structured like `cancels/show`: card with the summary partial in the header, copy in the body,
footer with **Back** (left) and the confirm button (right) submitting `PATCH billing_subscription_path`
with the `plan` param.

| | Yearly → monthly | Monthly → yearly |
|---|---|---|
| Title | Switch to monthly | Switch to yearly |
| Body | You'll keep your yearly plan until %{date}. After that, you'll pay %{price}/month. No refund or credit is issued for the rest of your year. You can change your mind any time before then. | Your yearly plan starts today. You'll be charged %{price}, minus a credit for the unused part of this month. |
| Button | Switch at renewal | Switch to yearly |

Prices are displayed from the `Plan` rows. No logic depends on an amount. Copy lives in
`config/locales/en.yml`, alongside the existing `no_refunds` / cancel wording.

**D. Cancel page** (`app/views/billing/subscriptions/cancels/show.html.erb`): while pending, add
*"Your switch to monthly on %{date} will also be removed."*

**E. Blocked state**: if the subscription isn't plainly active (`on_grace_period?`, `past_due?`,
`unpaid?`, or otherwise not `active?`), `edit`, the confirmation page, and `update` redirect to
Billing with *"Resume your plan to change it."* (grace period) or *"Plan changes aren't available
right now."* (otherwise). If a switch is already pending, they redirect with *"You're already
switching to monthly on %{date}."*

## Scope
**In:**
- Pay::Subscription schedule module (schedule / pending / release)
- `SubscriptionsController` edit/update: direction rule, guards, release-before-swap
- New `PlanChangesController` (confirmation `show`, Keep yearly `destroy`) + route
- Billing page pending notice + Keep yearly; change-plan page links; cancel page line
- Release-before-cancel in `CancelsController#destroy` and `Account#cancel_billable_subscriptions!`
- en.yml copy
- One line in `docs/runbooks/price-change-checklist.md` step 5: pending yearly→monthly switches
  keep the old monthly price
- Tests (WebMock-stubbed Stripe):
  - yearly subscriber switching to monthly schedules it for renewal with no proration (assert
    request bodies: `proration_behavior=none`, phase 1 starts at period end)
  - billing page shows "Switching to monthly on <date>" and Keep yearly
  - Keep yearly releases the pending switch
  - monthly subscriber switching to yearly is charged now (swap path)
  - canceled subscription in grace period can't change plans; no un-cancel request is sent to Stripe
  - canceling with a switch pending releases the schedule first; the cancel page mentions it
  - a failed second schedule call releases the half-made schedule
  - confirmation page shows no-refund copy; no "Are you sure?" on the plan page

**Deferred / out of scope:**
- The cancel page's own generic "Are you sure?" confirm on its button
- Stock Jumpstart subtitle on the change-plan page ("…get your online business up and running")
- Previewing the exact prorated amount for monthly → yearly (Stripe upcoming-invoice preview)
- Handling `subscription_schedule.*` webhooks (not needed: we `sync!` after our own calls, and
  Stripe fires `customer.subscription.updated` for the changes that matter)

## Open Questions
None.

## More Info
- Pay 11.6.2 `swap` (`Pay::Stripe::Subscription#swap`) hard-codes `cancel_at_period_end: false`
  and defaults `proration_behavior: "always_invoice"` — the source of the original bugs.
- Pay's `cancel` uses `cancel_at_period_end: true`, which Stripe rejects while a schedule is attached.
- Account ID caution (runbook step 1): the Stripe CLI profile `cove-staging` is the Cove sandbox
  (`acct_1Tw25AAVvDn1V5lJ`). The CLI's `default` profile is a different project's sandbox — don't
  use it. Development credentials in this checkout have no Stripe keys.
- Test clocks with a monthly price can only advance two months per step.
- Finish before the COV-78 live-mode cutover.
