> Ticket: COV-25
> Branch: jrdnbwmn/cov-25-dev-seeds
> Plan created: docs/plans/baseline-dev-seeds.md

# Feature: Baseline dev/demo seeds (db/seeds.rb)

## Problem
`db/seeds.rb` is empty (stock template comments only), so a freshly set-up
dev database has no accounts to log into. Any feature slice built for design
review is unclickable until someone hand-creates users. We need a known,
idempotent, production-safe baseline so `bin/rails db:seed` yields documented,
loggable personas.

## Approach
Build an idempotent `db/seeds.rb` that fabricates a small set of named dev
personas, wrapped in `unless Rails.env.production?` so nothing runs in prod.
Every record uses `find_or_create_by!` (or an equivalent guard) so re-running
`bin/rails db:seed` is always safe. Credentials are documented in `README.md`.

Personas mirror the shape/names used in the fixtures where it makes sense
(per COV-24), but use descriptive emails so it's obvious who's who during
design review. All users share the dev password `password` and are created
pre-confirmed so they can log in immediately.

Ordering of favored solutions: this leans entirely on JSP built-ins
(`User` auto-creates a personal account via `after_create`, `AccountUser`
roles, `Jumpstart.grant_system_admin!`, Pay's fake processor) and Rails
`find_or_create_by!` — no new models, gems, or custom code.

## Acceptance Criteria
- `bin/rails db:seed` on a fresh dev DB creates the five documented personas.
- Re-running `bin/rails db:seed` makes no duplicate records (idempotent).
- The seed block never runs in `Rails.env.production?`.
- Each persona can sign in with the documented email + `password`.
- The "Cove Team" account exercises all three role states on `AccountUser`
  (owner-admin, non-owner admin, plain member).
- The subscribed persona has an active subscription so billing screens render.
- `superadmin@cove.test` reaches the Jumpstart `/admin` area.
- `bin/rails test` still passes (fixtures, not seeds, drive tests).

## Prototype
None.

## Data Model
No new models. Uses existing `User`, `Account`, `AccountUser`, `Plan`, and
Pay's fake processor (`Pay::FakeProcessor::Customer` / `Subscription`).

### Persona roster (all password: `password`, all pre-confirmed)

| Email | Name | Accounts | Role / state |
|---|---|---|---|
| `owner@cove.test` | Olivia Owner | personal (auto) + owns team "Cove Team" | team **admin** (as owner) |
| `admin@cove.test` | Andy Admin | personal (auto) + member of "Cove Team" | team **admin** (non-owner) |
| `member@cove.test` | Molly Member | personal (auto) + member of "Cove Team" | team **member** (no admin) |
| `subscribed@cove.test` | Sofia Subscriber | personal (auto) | active fake-processor subscription |
| `superadmin@cove.test` | Sydney Super | personal (auto) | system admin via `grant_system_admin!` |

Notes:
- Creating a `User` fires `after_create :create_default_account`, which
  auto-builds a personal account (config `account_types` defaults to `"both"`,
  so `personal_accounts?` is true). So personal accounts are NOT hand-created —
  they come free with each user, satisfying the "personal account + owner"
  requirement for every persona.
- The interesting structure is the **"Cove Team"** team account
  (`personal: false`), owned by `owner@cove.test`, with `AccountUser` join
  rows for all three users covering both role states:
  - `owner` → `roles: { admin: true }` (owner is an admin)
  - `admin` → `roles: { admin: true }` (non-owner admin)
  - `member` → no roles (plain member)
- `AccountUser::ROLES == [:admin]`; a "member" is simply an `AccountUser`
  with no admin role.
- The subscribed persona needs a `Plan` with a `fake_processor_id` seeded,
  then `account.set_payment_processor(:fake_processor, allow_fake: true)` +
  `payment_processor.subscribe(plan: plan.fake_processor_id)` — the same path
  the existing subscription tests use. There is no existing plan-seeding
  mechanism (plans normally sync from Stripe), so one minimal fake plan is
  seeded here purely to back the dev subscription.

### Idempotency plan
- Users: `User.find_or_create_by!(email:) do |u| … end` — the block (name,
  password, `terms_of_service: "1"`, `confirmed_at: Time.current`) only runs on
  first create.
- Team account: `Account.find_or_create_by!(name: "Cove Team", owner: owner)`.
- Memberships: `AccountUser.find_or_create_by!(account:, user:)`, then set
  `roles` — re-runs don't duplicate join rows.
- Plan: `Plan.find_or_create_by!(fake_processor_id: …)`.
- Subscription: guard with `unless account.payment_processor&.subscribed?`.
- System admin: `grant_system_admin!` is a plain UPDATE — naturally idempotent.

## Screens / Flows
No new screens. After `bin/rails db:seed`, a designer visits `/users/sign_in`,
enters any persona email + `password`, and lands in that persona's state:
- `owner@cove.test` — can switch between personal and "Cove Team" accounts,
  manage team members.
- `admin@cove.test` / `member@cove.test` — see "Cove Team" with the respective
  permission level.
- `subscribed@cove.test` — billing/subscription screens render an active plan.
- `superadmin@cove.test` — can reach the Jumpstart `/admin` area.

## Scope
**In:**
- Idempotent, production-guarded `db/seeds.rb` creating the five personas
  above, the "Cove Team" account with all three role states, one fake `Plan`,
  and an active subscription for the subscribed persona.
- A "Dev login credentials" section in `README.md` listing the emails, shared
  password, and the `bin/rails db:seed` pointer.
- Verification: drop/create/migrate/seed a fresh dev DB, confirm login for each
  persona; confirm `bin/rails test` still passes.

**Deferred:**
- Splitting seeds into per-domain files (COV-26 / ticket [3]).
- A fuller plan catalog / realistic billing states beyond the single subscribed
  persona.
- Any genuinely-required (unguarded) production records — none exist for this
  skeleton yet.

## Open Questions
None.

## More Info
- **Edge cases handled:** pre-confirm users (`confirmed_at`) so Devise
  confirmable lets them log in; pass `terms_of_service: "1"` to satisfy the
  `on: :create` acceptance validation (`accepted_terms_at` / `accepted_privacy_at`
  are set by the model's `after_validation` hooks); `password` (8 chars) clears
  Devise's 6-char minimum.
- **Config assumption:** seeds assume `account_types` includes personal
  (current default `"both"`) so the auto-personal-account hook fires. This will
  be flagged with an `AIDEV-NOTE` in `db/seeds.rb` rather than defended against.
- **Fixtures unaffected:** tests are driven by `test/fixtures/*`, not seeds, so
  this change should be independent of the test suite — but `bin/rails test`
  will be run to confirm.
- **Reserved TLD:** `@cove.test` uses the reserved `.test` TLD, guaranteeing
  these are never real/production addresses.
