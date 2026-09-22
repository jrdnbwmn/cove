> Plan created: docs/plans/cov-75-complimentary-premium-for-testers.md

> Ticket: COV-75
> Branch: feature/cov-75-complimentary-premium-for-testers

# Feature: Complimentary Premium for testers

## Problem

Testers need Premium now without a card or Stripe. A superadmin needs to switch
Premium on for a family (and off again) from the admin area, including on
staging where there is no console.

## Approach

Add a switch on the account rather than a fake Pay subscription:

- Two columns on `accounts`: `complimentary_premium` (boolean) and
  `complimentary_premium_note` (who and why).
- Extend `Account#premium?` (COV-74) to be true for a comp **or** a billable
  subscription. Add `Account#plan_status` (`premium` / `complimentary` / `free`,
  paid wins).
- Expose both fields in Madmin's `AccountResource`, so superadmins edit them at
  `/admin/accounts`.
- Seed a comped family in development.

Rejected alternative: a fake Pay subscription for testers. It would put testers
in billing records and revenue numbers and give no single clear field in admin.

### Product decisions implemented

- A superadmin switches complimentary Premium on for a family. **No end date**:
  it stays on until a superadmin switches it off.
- No Stripe records, Pay customers/subscriptions, receipts, or billing emails.
- Switched off → the family is Free unless it has a billable subscription. Normal
  downgrade rules apply (owned by the Students ticket).
- A comped family can still subscribe through checkout. A paid subscription
  takes precedence over the comp in `plan_status`.
- A note is **required** whenever the comp is on. The note is **kept** when the
  comp is switched off (history; re-enabling restores context).

## Acceptance Criteria

Tests are written first. Test names describe user-facing behavior.

- [ ] A comped family is Premium, allowed 10 students, and has plan status
      `complimentary`
- [ ] Switching the comp off makes a family with no subscription Free (allowed 1,
      plan status `free`)
- [ ] Granting a comp creates no Pay customer or subscription
- [ ] A comped family that subscribes has plan status `premium`, and stays
      Premium if the comp is later switched off
- [ ] A family with neither comp nor subscription has plan status `free`
- [ ] A comped family can open checkout (not redirected as "already subscribed")
- [ ] A comp can't be switched on without a note (blank or whitespace rejected);
      switching it off keeps the note
- [ ] A superadmin can switch the comp on (with note) and off from
      `/admin/accounts/:id/edit`; unticking the checkbox actually saves `false`
- [ ] The comp column shows on the `/admin/accounts` index; the note shows on
      show/edit but not index
- [ ] Only superadmins can change the comp fields: a non-superadmin is redirected
      away from Madmin, and a parent sending `complimentary_premium` /
      `complimentary_premium_note` to `PATCH /accounts/:id` changes nothing
- [ ] Development seeds create `tester@cove.test` with a comped family

## Prototype

None.

## Data Model

### Migration (one file)

```ruby
add_column :accounts, :complimentary_premium, :boolean, default: false, null: false
add_column :accounts, :complimentary_premium_note, :string
```

The default covers existing rows and fixtures; no backfill.

### `Account` changes (`app/models/account.rb`)

| Change | Behavior |
|---|---|
| `validates :complimentary_premium_note, presence: true, if: :complimentary_premium?` | Can't turn the comp on without a note. Turning it off with a note present is fine. |
| `premium?` | `complimentary_premium? \|\| billable_subscriptions.exists?` (comp first, so comped families skip the query) |
| `plan_status` | `"premium"` if `billable_subscriptions.exists?`, else `"complimentary"` if `complimentary_premium?`, else `"free"` |
| `free?`, `students_allowed` | Unchanged; they follow `premium?` |

Required `# AIDEV-NOTE:` comments:

- On the comp / `premium?`: why this is a switch on the account rather than a
  fake Pay subscription — it keeps testers out of billing records and revenue
  numbers, and gives one clear field in admin. No end date; on until a
  superadmin switches it off. Replace the existing "COV-75 will add
  complimentary Premium" wording in the current `premium?` note.
- On `plan_status`: paid wins over comp so a converted tester reports
  `premium`. Consumed by Loops sync (COV-76) and pricing/billing pages (COV-77).

### State table

| Comp | Billable subscription | `premium?` | `plan_status` | `students_allowed` |
|---|---|---|---|---|
| off | none | false | `free` | 1 |
| on | none | true | `complimentary` | `student_limit` |
| off | yes | true | `premium` | `student_limit` |
| on | yes | true | `premium` | `student_limit` |

"Billable" follows COV-74 unchanged: `active` (including canceled within paid
period) or `past_due`.

### Test fixtures (hand-written, per the test-data convention)

- Add `accounts.yml` → `complimentary`: comp on, a note, no Pay customer. Give it
  an owner (and an `account_users` row if other fixtures require one for a
  family).
- The comp-plus-paid case is set up in the test body by switching the comp on
  for the existing subscribed family's account — no extra fixture.
- No `personal: true` fixtures (DB-constrained).

## Screens / Flows

Admin-only. No parent-facing UI changes in this ticket.

### Madmin (`lib/jumpstart/app/madmin/resources/account_resource.rb`)

Placed right after `student_limit`:

```ruby
attribute :complimentary_premium
attribute :complimentary_premium_note, index: false
```

- **Index** (`/admin/accounts`): new "Complimentary Premium" column (Madmin's
  standard true/false). No filter or sort.
- **Show**: "Complimentary Premium" and "Complimentary Premium Note" rows.
- **Edit**: checkbox + text field, Madmin's built-in boolean and string fields.
  Default labels are fine. Madmin's boolean field uses Rails' `check_box`
  (hidden `"0"`), so unticking saves — verify with a test. Validation errors use
  Madmin's standard error display (same as invalid `student_limit`).

### Flows

1. **Grant:** superadmin → `/admin/accounts` → family → Edit → tick
   "Complimentary Premium", enter note → Save → family is Premium, plan status
   `complimentary`. No Stripe/Pay activity.
2. **Grant without a note:** form re-renders with "Complimentary premium note
   can't be blank"; nothing saved.
3. **Revoke:** untick → Save. Note kept. Family is Free (or `premium` if it has a
   billable subscription).
4. **Tester converts:** `/pricing` → checkout opens normally → subscribes → plan
   status `premium`. Comp may stay on; switching it off later changes nothing.
5. **Parent tries to set it:** `PATCH /accounts/:id` ignores the fields
   (`account_params` permits only `name`/`avatar`). Non-superadmins are
   redirected away from `/admin`.

### Seeds (`db/seeds.rb`, inside the existing `Rails.env.local?` block)

- `tester@cove.test` / `password` (name e.g. "Tina Tester"), same
  `find_or_create_by!` pattern as the other seed users, plus
  `create_default_account unless tester.family`.
- `tester.family.update!(complimentary_premium: true,
  complimentary_premium_note: "Dev seed: complimentary Premium tester")` —
  idempotent on re-run.

## Edge Cases

| Situation | Behavior |
|---|---|
| Comp off while family has >1 student | Nothing to enforce yet (no Student model); `students_allowed` returns 1. Students ticket owns read-only behavior |
| Comp on + `past_due` subscription | Premium; `plan_status` = `premium` |
| Comp on + canceled-and-ended subscription | Premium via comp; `plan_status` = `complimentary` |
| Comped family opens checkout | Allowed — `redirect_if_already_subscribed` only checks Pay |
| Comped family with active paid subscription opens checkout | Redirected to billing as today |
| Whitespace-only note | Rejected by `presence` |
| Long note | `string` is unlimited in Postgres; no extra validation |
| Parent sends comp params to `/accounts/:id` | Ignored by strong params |
| Non-superadmin visits `/admin/accounts` | Redirected by Madmin's existing `admin?` check |
| Empty comped family merges into another family | Allowed; comp goes away with the deleted family. `unjoinable_reason` unchanged |
| Comped family deleted | Nothing to cancel in Stripe; comp goes with the family |
| Staging | Editable at `/admin/accounts` after deploy runs the migration; no console |
| Seeds run twice | Idempotent |

## Scope

**In:**
- Migration for `complimentary_premium` and `complimentary_premium_note`
- `Account`: note validation, extended `premium?`, new `plan_status`, AIDEV-NOTEs
- Madmin `AccountResource` fields (comp on index/show/edit; note on show/edit)
- `complimentary` account fixture
- Model, checkout, Madmin, and account-params tests for the criteria above
- Dev seed: `tester@cove.test` with a comped family
- Update `docs/architecture/data-model.mermaid` with the two new columns

**Deferred:**
- Parent-facing display of comp status (`/billing`, pricing, nav) — COV-77. Until
  then a comped family's `/billing` still reads "You are not currently
  subscribed."
- Syncing `planStatus` to Loops when the comp changes — COV-76
- Downgrade behavior for students (which stay editable) — Students ticket
- End dates / auto-expiry for comps
- Admin filter/sort by comp status
- Blocking family merge for comped families

## Open Questions

None.

## More Info

- Product rules: `docs/product/product-brief.md` (Testers section).
- Audit reference: `docs/designs/done/cov-71-monetization-family-audit.md`
  (Technical principles section; gap 8 = no comp flag/note).
- COV-74 design: `docs/designs/done/cov-74-premium-check-and-family-student-limit.md`
  (`premium?` rules, `billable_subscriptions`, Madmin pattern, admin test style in
  `test/integration/madmin/accounts_test.rb`).
- Relevant code: `app/models/account.rb`,
  `lib/jumpstart/app/controllers/checkouts_controller.rb`
  (`redirect_if_already_subscribed`), `app/controllers/accounts_controller.rb`
  (`account_params`), `lib/jumpstart/app/madmin/resources/account_resource.rb`,
  `lib/jumpstart/app/controllers/madmin/application_controller.rb`,
  `db/seeds.rb`.
- `premium?` in controllers/views comes from `PremiumAccess`
  (`app/controllers/concerns/premium_access.rb`) and needs no change.
- After running the migration locally, revert schema-dump noise per AGENTS.md
  "Known Gotchas" (keep only the two real column additions in `db/schema.rb`).
