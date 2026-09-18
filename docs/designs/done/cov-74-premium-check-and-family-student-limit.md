> Ticket: COV-74
> Branch: feature/cov-74-premium-check-and-family-student-limit
> Plan created: docs/plans/cov-74-premium-check-and-family-student-limit.md

# Feature: Premium check and family student limit

## Problem

Nothing in the app can answer "is this family Premium?" or "how many students
can this family have?" Every future feature needs both answers, and they have to
come from one place.

## Approach

- **Model methods live directly in `app/models/account.rb`:** `premium?`,
  `free?`, `students_allowed`, plus `FREE_STUDENT_LIMIT = 1`. `premium?` reuses
  the existing private `billable_subscriptions` method (added in COV-72), so
  "Premium" and "has a billable subscription" can never disagree.
- **One migration:** `accounts.student_limit` (integer, default 10, not null).
- **Controller concern `app/controllers/concerns/premium_access.rb`**, included
  in `ApplicationController`. It follows the shape of Jumpstart's
  `Accounts::SubscriptionStatus`: `helper_method :premium?` plus
  `require_premium!`. Jumpstart's `subscribed?` and `require_subscription!` are
  left untouched and must **not** be used for Premium, because Pay's
  `subscribed?` excludes `past_due` (audit gap 6).
- **Madmin:** add `student_limit` to `AccountResource`
  (`lib/jumpstart/app/madmin/resources/account_resource.rb`). COV-73 already
  edited Madmin files under `lib/jumpstart/` the same way.

### Product decisions implemented

- Premium = the family has a billable subscription. It is **never** based on
  price, amount, plan name, interval, or Stripe ID. Prices will change, and
  subscribers on an old price must stay Premium.
- `past_due` (Stripe retrying a failed renewal) stays Premium. `unpaid`,
  `paused`, and canceled-and-ended are Free.
- A canceled subscription stays Premium until its paid period ends (`ends_at`
  in the future).
- Student limits: Free = 1 (constant). Premium = the family's `student_limit`:
  10 by default, raisable by a superadmin.

## Acceptance Criteria

Tests are written first. Test names describe user-facing behavior.

- [ ] A new family is Free and allowed 1 student
- [ ] A family with an active monthly or yearly subscription is Premium and
      allowed 10 students
- [ ] A family whose limit a superadmin raised to 14 is allowed 14; if it
      becomes Free, it's allowed 1
- [ ] A family that canceled stays Premium until the period ends, then is Free
- [ ] A `past_due` family is Premium; an `unpaid` family is Free
- [ ] A `paused` family is Free
- [ ] A family on a hidden, old-price plan is still Premium
- [ ] A Free user visiting a Premium-only page is redirected to pricing with a
      notice; a Premium user isn't
- [ ] A superadmin can change a family's student limit from the admin page
- [ ] A student limit below 1 (0, negative, blank, decimal) is rejected

## Prototype

None.

## Data Model

### Migration

```ruby
add_column :accounts, :student_limit, :integer, default: 10, null: false
```

Existing rows and account fixtures get 10 from the column default, so no
backfill is needed. Validation lives in the model only, with no DB check
constraint. The only place the value is edited is Madmin, which runs model
validations, and a wrong value is low-stakes and easy to fix in admin.

### `Account` additions

| Addition | Behavior |
|---|---|
| `FREE_STUDENT_LIMIT = 1` | The single named Free limit, the same for every family, so not a column |
| `validates :student_limit, numericality: { only_integer: true, greater_than_or_equal_to: 1 }` | Rejects 0, negatives, decimals, blank |
| `premium?` | `billable_subscriptions.exists?`, i.e. `pay_subscriptions.active.or(pay_subscriptions.past_due)`. Pay's `active` scope already includes canceled subscriptions within their paid period, and excludes paused, unpaid, and ended ones |
| `free?` | `!premium?` |
| `students_allowed` | `premium? ? student_limit : FREE_STUDENT_LIMIT`. **The one method the Students feature checks.** |

Required `# AIDEV-NOTE:` comments:

- On `premium?`: it's subscription-based, never price, plan, or Stripe ID based,
  because prices change and old-price subscribers must stay Premium. It counts
  `past_due`, unlike Pay's `subscribed?`, so Premium is kept while Stripe
  retries. COV-75 will extend it with complimentary Premium.
- On `students_allowed` / `student_limit`: the Premium cap exists to stop
  co-ops and micro-schools using a family plan. A per-student fee or add-on may
  replace manual superadmin raises later.

`student_limit` is kept when a family drops to Free. If they re-subscribe, a
raised limit applies again automatically.

### State table

| Subscription state | `premium?` | `students_allowed` |
|---|---|---|
| None (new family) | false | 1 |
| Active, monthly or yearly | true | `student_limit` (10 default) |
| Canceled, `ends_at` in future | true | `student_limit` |
| Canceled, ended | false | 1 |
| `past_due` | true | `student_limit` |
| `unpaid` | false | 1 |
| `paused` | false | 1 |
| Active on hidden, old-price plan | true | `student_limit` |

### Test fixtures (hand-written, per `test-data-convention`)

- Reuse the existing `pay/subscriptions.yml` → `subscribed` (active) for the
  active case.
- Add subscriptions, each on its own `pay/customers.yml` and `accounts.yml`
  record: `past_due`, `unpaid`, `paused`, `canceled_in_period` (`ends_at` in the
  future), `canceled_ended` (`status: canceled`, `ends_at` in the past), and
  `old_price` (`processor_plan` pointing at the hidden plan fixture in
  `plans.yml`).
- Monthly vs yearly: `premium?` doesn't read the interval. Cover the criterion
  with one test that points a subscription at the monthly plan and another at
  the yearly plan, not with extra fixtures.
- Set the "raised to 14" case in the test body, not with a fixture.
- No `personal: true` fixtures (DB-constrained, see AGENTS.md).

## Screens / Flows

### Controller concern: `PremiumAccess`

- `premium?`: `user_signed_in? && current_account&.premium?`. It returns false
  rather than raising when nobody is signed in. Exposed to views via
  `helper_method`.
- `require_premium!`: unless `premium?`, `redirect_to pricing_path, notice:
  t("premium_access.required")`.
- Locale string (`config/locales/en.yml`): *"That's a Premium feature. Upgrade
  to unlock it."* Shown as a **notice** (neutral), not an alert.
- No Pundit policy. Premium is a fact about the family, not a permission for one
  parent, and both parents are admins.

### Flows

1. **Free family hits a Premium-only page** (a controller using
   `before_action :require_premium!`) → redirected to `/pricing` with the
   notice in the existing flash area.
2. **Premium family hits the same page** → page loads normally.
3. **Views:** any view can call `premium?`. No view uses it in this ticket.
4. **Superadmin raises a limit:** `/admin/accounts` → family → Edit → "Student
   limit" number field (default 10) → change to 14 → save → the show page reads
   14. Invalid values show Madmin's standard form error and don't save.

### Admin (Madmin)

`attribute :student_limit, index: false`, placed after `billing_email` in
`AccountResource`. It appears on the show and edit pages, not the index. The
Madmin default label ("Student limit") and number field are fine, and no custom
view is needed.

### Testing the redirect

No real feature is gated in this ticket. Test `require_premium!` with a
test-only controller and route defined within the integration test, so nothing
ships to production. write-plan picks the exact mechanism.

## Gating pattern for future Premium features

Recorded here so later tickets follow it:

- **Default:** show a notice over the blocked page or section, and the user
  stays on the page. Use the `premium?` helper plus the existing
  `AlertComponent`:
  ```erb
  <% unless premium? %>
    <%= render AlertComponent.new(title: "...", description: "...") %>
  <% end %>
  ```
- **Exception:** use `before_action :require_premium!` (redirect to pricing)
  only when the whole page makes no sense for a Free family.

## Edge Cases

| Situation | Behavior |
|---|---|
| Not signed in | Authentication runs first. `premium?` returns false as a safety net |
| No visible plans | `/pricing` already redirects home with its own "no plans" alert. This only happens when setup is broken. No change |
| Stripe webhook delay | `premium?` reads Pay's local rows. Brief lag is possible and Pay's checkout return syncs promptly. No change |
| Multiple subscription rows | Premium if **any** row counts |
| Subscription on deleted Pay customer / old processor | Still counts. `pay_subscriptions` spans all the family's Pay customers, same as COV-72's merge/delete checks |
| Limit lowered below the current student count | Nothing to enforce yet. The Students ticket owns over-limit behavior |
| Limit raised on a Free family | Allowed. It takes effect once the family is Premium |
| Family merge (`unjoinable_reason`) | Unchanged. It shares `billable_subscriptions` with `premium?` |

## Scope

**In:**
- Migration for `accounts.student_limit`
- `Account::FREE_STUDENT_LIMIT`, `premium?`, `free?`, `students_allowed`, the
  `student_limit` validation, and both AIDEV-NOTEs
- `PremiumAccess` concern (`premium?` helper, `require_premium!`) included in
  `ApplicationController`, plus the locale string
- `student_limit` on the Madmin `AccountResource` show and edit pages
- Model, integration, and admin tests plus fixtures for the criteria above

**Deferred:**
- Gating any actual feature. There is no Student model.
- A reusable in-page Premium notice (component or partial). Design it with the
  first gated feature, probably Students.
- Over-limit behavior (upgrade prompt for Free, "Contact us" for Premium,
  read-only students on downgrade). This belongs to the Students ticket.
- Complimentary Premium (COV-75). It extends only `Account#premium?`.
- `Account#plan_status` / Loops `planStatus` sync
- Premium/Free badges on `/billing`, in the nav, or on the admin index
- Caching `premium?` if a page calls it many times per request

## Open Questions

None.

## More Info

- Audit reference: `docs/designs/cov-71-monetization-family-audit.md` (product
  rules; gap 3 = no premium check; gap 6 = Pay `subscribed?` excludes
  `past_due`; gap 8 = no `student_limit`).
- Relevant code: `app/models/account.rb` (`billable_subscriptions`),
  `lib/jumpstart/app/controllers/concerns/accounts/subscription_status.rb` (the
  pattern to mirror, not reuse), `app/controllers/pricing_controller.rb`,
  `lib/jumpstart/app/madmin/resources/account_resource.rb`.
- After running the migration locally, revert the schema-dump noise per
  AGENTS.md "Known Gotchas" (keep only the real `student_limit` change in
  `db/schema.rb`).
