> Ticket: COV-105
> Branch: feature/cov-105-student-plan-limits
> Plan created: docs/plans/student-plan-limits.md

# Feature: Students — plan limits

## Problem
A family can currently add or restore any number of students. Free families
should be capped at 2 active students and Premium families at their
`student_limit` (default 10, superadmin-raisable), with a calm explanation
and a next step when they reach it.

## Approach
Enforce the limit in the `Student` model so no code path (controller, stale
tab, direct request, console, future feature) can bypass it.

- `Account#can_add_student?` is the single rule:
  `students.active.count < students_allowed`. Reused by COV-106 (downgrade)
  and future features.
- `Student` gets one validation that runs whenever a student would become
  active — on create (unless created already archived) and on restore
  (`archived_at` changing from present to nil). It calls `account.lock!`
  first, then checks `account.can_add_student?`; if false it adds a `:base`
  error. Rails runs validations inside the save's transaction, so the row lock
  holds until commit — this serializes two parents saving at the same moment.
  Add an `# AIDEV-NOTE:` explaining the lock.
- The UI hides Add/Restore at the limit and shows plan-specific prompts; the
  controllers turn model refusals into friendly responses.

## Acceptance Criteria
Tests first. Test names describe user behavior.

- A Free family can add a 2nd student but not a 3rd, and sees the upgrade prompt.
- A Free family with 2 active + 1 archived student can't restore the archived
  one; after archiving another, it can.
- Archived students don't count toward the limit.
- A Premium family can add students up to its `student_limit`.
- A Premium family at its limit sees "Contact us".
- A Premium family whose `student_limit` a superadmin raised can add more.
- A Complimentary Premium family gets the Premium limit.
- A request that bypasses the UI (direct POST create / DELETE archive) can't
  create or restore a student past the limit: create re-renders the form
  (422) with the error; restore redirects to `/students` with an alert and
  the student stays archived.
- Editing and archiving still work when a family is over its limit.
- `Account#can_add_student?` unit-tested directly (active-only count, Free vs
  Premium vs raised limit).

## Prototype
None.

## Data Model
No migration. Existing: `accounts.student_limit` (default 10, validated
`>= FREE_STUDENT_LIMIT`), `Account::FREE_STUDENT_LIMIT = 2`,
`Account#students_allowed` (`premium? ? student_limit : FREE_STUDENT_LIMIT`),
`students.archived_at`, `Student.active` / `.archived` scopes,
`Student#archive!` / `#restore!` (both via `update!`).

**`Account`** (`app/models/account.rb`)
```ruby
def can_add_student?
  students.active.count < students_allowed
end
```
Use `count` (fresh SQL), not `size`, so a loaded association can't answer stale.

**`Student`** (`app/models/student.rb`)
- New validation, e.g. `validate :within_student_limit, if: :becoming_active?`
  - `becoming_active?`: (`new_record? && archived_at.nil?`) or
    (`archived_at_changed? && archived_at.nil?` on a persisted record).
  - Body: `account.lock!`, then
    `errors.add(:base, :student_limit_reached, ...)` unless
    `account.can_add_student?`. The restoring student is still archived in the
    DB during validation, so it isn't counted.
  - Message differs by plan (see copy below), with `%{limit}` =
    `account.students_allowed`.
- `restore!` keeps using `update!`; a refusal raises
  `ActiveRecord::RecordInvalid`. `archive!` is unaffected (validation doesn't
  run on archive or normal edits).

**Controllers**
- `StudentsController#create`: existing failure path already re-renders
  `:new` with 422 — the `:base` error shows in the form. Confirm `_form`
  renders base errors; add that if it doesn't. No separate guard on `new`.
- `Students::ArchivesController#destroy`: rescue `ActiveRecord::RecordInvalid`
  → `redirect_to students_path, status: :see_other, alert:` the model's error
  message (don't duplicate the copy).

**Fixtures** — extend `test/fixtures/students.yml` / `accounts.yml` with
named records as needed (e.g. a Free family with 2 active + 1 archived; a
Premium family with a low `student_limit`). Reuse existing records where
possible. Labels, not IDs; literals, not random data.

## Screens / Flows

**Under the limit:** unchanged.

**`/students` header** (`students/index.html.erb`)
- Where `_add_trigger` renders today, render it if
  `Current.account.can_add_student?`, otherwise a new
  `students/_limit_prompt` partial.
- The empty state keeps "Add student" (the limit is always ≥ 2 and archived
  students don't count, so an empty family is never at the limit).
- Header row gets `flex-wrap` so the prompt wraps below the title on phones.

**`_limit_prompt`**
- **Free:** `text-sm text-muted-foreground` sentence + `ButtonComponent`
  "Upgrade to Premium", `href: pricing_path` (same destination as the billing
  page's upgrade button).
- **Premium / Complimentary:** quiet sentence with inline link. "Contact us" is
  `mail_to(Jumpstart.config.support_email, …, subject: …)` with classes
  `underline text-foreground hover:text-primary`, matching
  `pricing/show.html.erb`.

**Archived section** (inside the existing `<section>`, under the heading)
- At the limit: one `text-sm text-muted-foreground` note (copy below).
- `_student_card` gets a `can_restore:` local (default `true`); when false,
  the Restore form isn't rendered. Delete stays.

**Key copy** (`config/locales/en.yml`, `students.*` and
`activerecord.errors.models.student…`). No exclamation points, no "limit
reached", no over-limit counts, one next action each.

| Where | Free | Premium |
|---|---|---|
| Header prompt | "Free includes %{limit} students." + button "Upgrade to Premium" | "Premium includes %{limit} students. Need more? %{link}." link: "Contact us" |
| Archived note | "To restore a student, archive one first or %{link}." link: "upgrade to Premium" → pricing | "To restore a student, archive one first or %{link}." link: "contact us" → support |
| Model error (form / restore alert) | "Free includes %{limit} students. Upgrade to Premium to add more." | "Premium includes %{limit} students. Contact us to add more." |
| Mail subject | — | "More students on %{product}" (new `students.*` key; same wording as pricing's) |

Pluralize with `one`/`other` where `%{limit}` appears.

## Edge Cases
1. Two parents add at once at 1 of 2 → lock serializes; the second save is refused with the form error.
2. Stale Add modal (other parent filled the last slot) → save refused, entered name preserved.
3. Stale Restore button → redirect with alert; student stays archived.
4. Over the limit (e.g. lapsed Premium with 5 active) → no add/restore; edit and archive still work; prompt shows Free copy with no count. Read-only behavior is COV-106.
5. Premium ends mid-session → next page load shows the Free prompt; nothing deleted.
6. Superadmin raises `student_limit` → effective immediately (no caching).
7. Complimentary Premium → Premium limit and copy (via `premium?`).
8. Student created already archived → not counted, not checked.
9. Edit/archive never trigger the limit validation.
10. Deleting an active student frees a slot; deleting an archived one doesn't change the count.

**Assumptions (confirmed):** the limit counts only this family's students
(`account.students`); no "1 of 2 left" warning before the limit.

## Scope
**In:** `Account#can_add_student?`; `Student` limit validation with row lock;
controller handling of refusals; header limit prompt (Free/Premium); hidden
Restore + archived-section note at the limit; locale copy; fixtures; model,
controller/integration, and system tests.

**Deferred / out of scope:** downgrade flow and read-only students (COV-106);
billing/Stripe changes; any per-student fee; other Free limits; a "slots
left" indicator; a guard on `GET /students/new` (the model covers it).

## Open Questions
None.

## More Info
- Product rules: `docs/product/product-brief.md` (Free vs Premium; Students —
  "Past the limit: Free sees an upgrade prompt, Premium sees 'Contact us'").
- Feature logic must gate on `Account#premium?` / `students_allowed`, never
  on a price, plan name, or Stripe ID.
- The `taken_archived` name-uniqueness message ("Restore them from archived
  students…") is left unchanged — the Add form is hidden at the limit.
- Unblocks COV-106, which reuses `Account#can_add_student?`.
