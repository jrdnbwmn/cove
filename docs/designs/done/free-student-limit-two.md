> Ticket: COV-90
> Branch: feature/cov-90-free-tier-restrictions
> Plan created: docs/plans/free-student-limit-two.md

# Feature: Raise Free student limit to 2

## Problem
The Free plan is advertised and configured as 1 student; the decision is 2. Premium is advertised as "Up to 10 students" but should read as unlimited. The product brief still lists several now-settled decisions as "planned" or open, and the cancel page tells `past_due`/`unpaid` families their plan ends at period end when it actually ends immediately.

## Approach
Copy, constant, and documentation change — no migration, no new models, no enforcement. There is no `Student` model yet (`/students` is "Coming soon"; the Students ticket, COV-93, builds it), so `Account::FREE_STUDENT_LIMIT` only feeds `Account#students_allowed` and pricing/billing copy.

1. `FREE_STUDENT_LIMIT` 1 → 2; Free copy pluralized with i18n `one`/`other`.
2. Premium advertised as "Unlimited students"; a contact line on `/pricing` covers families above the real cap.
3. `student_limit` validation minimum raised from 1 to `FREE_STUDENT_LIMIT`, so Premium can never allow fewer students than Free.
4. Cancel page copy matches what `CancelsController#destroy` actually does for `past_due`/`unpaid`.
5. Brief updated to state all decisions as settled.

Tests first, named as user behavior.

## Acceptance Criteria
- `bin/rails test` passes (and the touched system tests).
- `/pricing` shows Free "2 students", Premium "Unlimited students" (monthly and yearly), and the "More than N students? Contact us." line — on staging.
- `/billing` tells a Free family "Your Family can have 2 students." — on staging.
- A `past_due` family's cancel page says the plan is canceled immediately and doesn't offer resuming.
- The brief matches the app.

## Prototype
None. Copy is specified below.

## Data Model
No migration. Existing:
- `accounts.student_limit` — integer, default 10, `null: false`, superadmin-editable in Madmin. The DB default remains the single source for the advertised Premium cap (`Account.default_student_limit`).

Changes in `app/models/account.rb`:
- `FREE_STUDENT_LIMIT = 2`.
- `validates :student_limit, numericality: {only_integer: true, greater_than_or_equal_to: FREE_STUDENT_LIMIT}` (was `1`). Only fixture value is 10; no DB check constraint exists, so nothing to migrate. Madmin's existing "rejects 0" test still holds.
- Replace the `students_allowed` AIDEV-NOTE (which speculates a per-student fee "may replace manual admin raises") with the settled decision, roughly: Premium is advertised as unlimited, but `student_limit` (default 10, raised per family by a superadmin) is the real cap that keeps co-ops and micro-schools off a family plan; families above it contact support. No per-student fee — pricing stays flat per family and Stripe quantity never changes.

`students_allowed` logic is unchanged (`premium? ? student_limit : FREE_STUDENT_LIMIT`).

## Screens / Flows

### `/pricing` (signed-out, Free, Premium)
- **Free card**, first feature: "1 student" → **"2 students"** (pluralized from `FREE_STUDENT_LIMIT`).
- **Premium card** (monthly and yearly), first feature: "Up to 10 students" → **"Unlimited students"** (no number).
- **New line** below the existing no-refunds note (`pricing/show.html.erb`), same small muted style: **"More than {N} students? Contact us."**
  - `{N}` = `PlanPricingHelper#premium_student_limit`: the DB default (10) for signed-out and Free families; the family's own `student_limit` for Premium (paid, `past_due`, or complimentary) — a raised family sees e.g. 14.
  - "Contact us" is a `mail_to` the support email with a subject, matching the checkout page pattern (`checkouts/show.html.erb`). Not `support_path` — the Support page requires sign-in and `/pricing` is public.

### `/billing` (Free family)
- `billing.show.free_description`: "Your Family can have 1 student." → **"Your Family can have 2 students."** (pluralized).

### Cancel confirmation (`billing/subscriptions/cancels/show`)
- `AccountDeletionHelper#cancellation_end_notice`: the immediate branch becomes `metered? || past_due? || unpaid?` — mirroring the three cases where `Billing::Subscriptions::CancelsController#destroy` calls `cancel_now!`.
- Add `cancels_immediately?(subscription)` in the same helper (used by `cancellation_end_notice` and the view), with an AIDEV-NOTE pointing at the controller so the two stay in sync.
- Immediate wording (`billing.subscriptions.cancels.show.cancel_immediately`): **"Your plan will be canceled immediately. No refund is issued."** (also fixes "cancelled" → "canceled").
- Hide the `.resume` line ("If you change your mind, you can resume your subscription.") when `cancels_immediately?`.
- Active subscriptions: unchanged (dated / undated end-of-period wording, resume line shown).

### `/dev/typography` (internal)
- Sample sentence: "Free forever for **2 students**. Upgrade to Premium for **unlimited students** and both parents, $12/month or $120/year." Free half via `t(..., count: Account::FREE_STUDENT_LIMIT)`. No test.

### No visible change
Premium billing summary, checkout, `/students`.

### i18n structure (`config/locales/en.yml`)
- Rails can't pluralize items inside a YAML array, so `pricing.show.free.features` and `pricing.show.premium.features` arrays are replaced by explicit keys the card partials assemble into the `features:` array — e.g. `pricing.show.free.students` (`one`/`other`), `pricing.show.premium.students` ("Unlimited students"), and a shared/both "Both parents" key.
- `billing.show.free_description` → `one`/`other`.
- New `pricing.show.more_students_html` (interpolates `student_limit` and the link).
- New key for the typography sample sentence (`one`/`other`).
- `cancel_immediately` reworded as above.

### Tests (write first)
Model — `test/models/account_test.rb`:
- Update the eight `assert_equal 1, account.students_allowed` to 2.
- Rename "a new family is free and allowed one student" → "a new Free family can have 2 students".
- Add "a superadmin-raised Premium family can have its raised number" (existing raised-limit test is framed around dropping to Free).
- Existing drop-to-Free tests (revoked complimentary, unpaid, canceled_ended, paused, raised-then-unpaid) cover "a family that drops to Free is allowed 2 students".
- Validation test: add `1` to the invalid `student_limit` values; assert `FREE_STUDENT_LIMIT` (2) is valid.

Pricing (integration, `test/integration/public_test.rb` or similar):
- Free pricing card says "2 students".
- Premium card shows "Unlimited students" and never "Up to".
- Contact line shows "More than 10 students?" with a `mailto:` support link (signed out).
- A raised Premium family sees its own number in the contact line.
- Update the existing `I18n.t("pricing.show.free.features").last` assertion to the new key.

Billing:
- The billing page tells a Free family it can have 2 students.

Cancel page:
- A `past_due` family's cancel page says the plan is canceled immediately and has no resume line.
- An active family still sees the dated end-of-period wording (existing system test at `pricing_and_billing_system_test.rb:117` covers this — keep passing).
- Helper unit tests for `cancellation_end_notice` / `cancels_immediately?` across active, past_due, unpaid.

### Brief — `docs/product/product-brief.md`
Keep the uncommitted "Students will eventually have their own logins" line.
- **Free vs Premium table:** Students → `2` | `Unlimited (advertised); 10-student cap, raisable per family`.
- **Students:**
  - Free limit **2**, settled (remove "planned" / "the app still enforces 1").
  - Premium advertised as **unlimited**; real cap is `student_limit` (default 10, raisable by a superadmin). Families above it contact support. The cap exists to stop co-ops and micro-schools using a family plan.
  - **No per-student fee**, no change to Stripe quantity or pricing structure; flat price per family.
  - Keep "Past the limit: Free sees an upgrade prompt, Premium sees 'Contact us'."
  - **Downgrade** (built in the Students ticket), when a family drops from Premium to Free with more than the Free limit:
    - No student is ever deleted.
    - A calm banner on `/students` says something like "Premium ended. Choose which 2 students stay editable." Until the parent chooses, all students are read-only. Nothing else is blocked.
    - The parent can change the pick at any time; swapping makes the previously editable student read-only.
    - Re-subscribing makes every student editable again.
    - Read-only students still appear on calendar events they're already assigned to.
- **Billing behavior:**
  - Canceling stops the next renewal and Premium lasts until the paid period ends — **except** canceling while `past_due` (or `unpaid`) ends Premium immediately, because `CancelsController` calls `cancel_now!`. Intended; the cancel page says so.
  - **Yearly → monthly** switches take effect at renewal, with no proration or credit. Built in the "Yearly → monthly takes effect at renewal" ticket.
- **Open questions:** only Terms of Service and refund policy pages (required before Stripe live activation). Remove the yearly→monthly and downgraded-families entries.

## Scope
**In:** constant + validation minimum, pricing/billing/typography copy, contact line, cancel-page immediate wording for past_due/unpaid, AIDEV-NOTE, brief, tests above.

**Deferred:** enforcing student limits, the upgrade prompt, the downgrade flow (Students ticket, COV-93), yearly→monthly at renewal (its own ticket), other Free feature limits (future tickets).

## Open Questions
None.

## More Info
- `pricing.show.no_refunds` ("You keep Premium until the end of the period you have paid for…") stays unchanged — for a `past_due` family the paid period has already ended, so it remains accurate.
- Jumpstart's `CancelsController#destroy` and Pay 11.6's `Pay::Stripe::Subscription#cancel` (`past_due_cancel_now: true` default) both end `past_due` subscriptions immediately.
- **Manual check for Jordan (outside the repo):** search the Loops-hosted email templates and any marketing copy for "1 student" and "Up to 10 students".
- Done also requires verifying `/pricing` and `/billing` on staging after deploy.
