> Ticket: COV-106
> Branch: feature/cov-106-students-downgrade-flow
> Plan created: docs/plans/student-downgrade-flow.md

# Feature: Students — downgrade flow

## Problem
When a family drops from Premium to Free with more active students than Free
allows (`Account::FREE_STUDENT_LIMIT` = 2), Cove must not delete anything. The
parent needs a calm way to choose which students stay editable, while the rest
stay saved and read-only.

## Approach
Store one boolean per student (`kept_on_free`) and compute editability on the
fly — never store "read-only":

> A student is editable if the family is Premium, **or** the family is at or
> under the Free limit, **or** the student is `kept_on_free`.

Because editability is computed from plan status, re-subscribing makes every
student editable immediately — no webhook handling or background job. Flags
are left as-is on re-subscribe, so a second downgrade reuses the previous pick.

**Trigger:** the family is `free?` and has more **active** students than
`FREE_STUDENT_LIMIT`. Covers canceled-and-ended and `unpaid`. `past_due`
keeps Premium, so it never triggers.

Builds on COV-105 (`Account#students_allowed`, `#can_add_student?`, the
`Student#within_student_limit` validation, `_limit_prompt`).

## Acceptance Criteria
Tests first. Test names describe user behavior.

- A downgraded family with 5 students sees every student read-only until it picks 2.
- A downgraded family can pick 2 students, and only those 2 are editable.
- A downgraded family can change which 2 stay editable, and the previous ones become read-only.
- A read-only student can't be edited or updated, even by a direct request (redirect + notice, nothing saved).
- A parent can view, archive, or delete a read-only student.
- Archiving a kept student clears its pick; if fewer than 2 are kept, the banner asks to choose again.
- Archiving students down to the Free limit makes every remaining student editable and removes the banner.
- A family that re-subscribes can edit all its students again.
- A family that downgrades a second time keeps its previous pick.
- A `past_due` family is still Premium: no banner, no read-only students, picker route redirects.
- The banner offers an "Upgrade instead" link to `/pricing`.
- While the banner shows, the header's Add button and limit prompt are hidden.
- Picker rejects: wrong count, another family's student, an archived student, duplicate ids.
- Saving the picker after the family is no longer over the limit redirects to `/students` without error.
- Picker Stimulus behavior (system test): after 2 checked, others disable; Save enabled only at exactly 2.

## Prototype
None.

## Data Model

**Migration:** add `students.kept_on_free` — boolean, `default: false`,
`null: false`. Constant default on Postgres, no table rewrite. No index. Use
the safe-migration skill.

**`Account`** (next to `students_allowed` / `can_add_student?`):
- `over_free_student_limit?` — `free? && students.active.count > FREE_STUDENT_LIMIT`.
  The trigger. Memoize per instance and clear in `reload`, same pattern as
  `paid_premium?`, so the index page doesn't re-count once per card.
- `student_pick_needed?` — `over_free_student_limit?` and fewer than
  `FREE_STUDENT_LIMIT` active students are `kept_on_free`. Chooses which
  banner state shows.
- `keep_students_on_free(ids)` — locks the family row (`lock!`, as COV-105's
  validation does); requires exactly `FREE_STUDENT_LIMIT` distinct ids, each an
  active student of this family; in one transaction sets those to `true` and
  every other student in the family to `false`. Returns `false` with an error
  message on failure.

**`Student`:**
- `editable?` — `!account.over_free_student_limit? || kept_on_free?`.
- `archive!` also sets `kept_on_free: false`.
- No change to delete or restore. A restored student comes back not kept
  (archive cleared it); restore stays blocked over the limit by COV-105's check.

**Controllers / routes:**
- `StudentsController#show` — new; the View modal. Routes currently
  `except: :show`, so `show` is added.
- `StudentsController` `before_action` on `edit`/`update`: if `!@student.editable?`,
  redirect to `/students` with the read-only notice. Controller-level, not a
  model validation — archiving is also an update and must keep working.
- `Students::KeptController` (`edit`, `update`), nested as `resource :kept`
  under `students` → `/students/kept/edit`. Both redirect to `/students` when
  the family isn't over the Free limit. Lists/accepts only active students,
  scoped through `Current.account`.

**Fixtures:**
- User `downgraded`, account `downgraded` (Free, no subscription), and the
  account_user joining them — follow the `canceled_ended` pattern.
- 5 active students on `downgraded`: `kept`, `kept_two` (`kept_on_free: true`);
  `read_only`, `read_only_two`, `read_only_three` (`false`). This is the
  "after choosing" state; "never picked" tests clear flags with
  `update_all(kept_on_free: false)`.
- Existing `past_due` account fixture covers the past-due case.

## Screens / Flows

All on `/students`. Everything else in the app is unaffected.

**A. Over the limit, not picked yet**
1. Banner above the grid (before-choosing state) with **Choose students**
   button and quiet **Upgrade instead** text link.
2. Header shows no Add button and no limit prompt.
3. Every active card shows a **Read-only** badge and **View** instead of Edit.

**B. Choosing**
1. **Choose students** opens the picker modal: one checkbox per active
   student (grid order).
2. After 2 are checked the rest disable; **Save** enabled only at exactly 2.
3. Save → one transaction → redirect to `/students` with notice
   "Saved. Maya and Theo stay editable."
4. Kept students get **Edit** back; others keep badge + **View**.

**C. After choosing**
1. Banner becomes a quiet one-line note with **Change** and **Upgrade instead**.
2. **Change** opens the same modal with the current pick pre-checked.
3. Saving a different pick swaps flags; the previously kept student becomes read-only.

**D. Viewing a read-only student**
1. **View** opens a modal: color dot, name, grade as plain text, plus the
   read-only explanation.
2. Actions: **Delete** (to the existing delete confirm), **Close**, **Archive**.
3. The delete confirm's **Cancel** returns to the View modal (`student_path`)
   for a read-only student, to `edit_student_path` otherwise.

**E. Getting back under the limit** — archiving/deleting a kept student
clears that pick (banner returns to "Choose students" if fewer than 2 kept).
At or under 2 active students the banner disappears, everyone is editable,
and the normal at-limit header prompt returns.

**F. Re-subscribing** — everyone editable, no banner. Picks stay stored and
apply again on a later downgrade (shows the after-choosing note).

**G. Direct requests** — `edit`/`update` on a read-only student redirect with
the notice. Archive, restore, delete still work (restore still limit-checked).

### UI components (all existing — no new catalog components)

1. **Banner** — new partial `students/_free_limit_banner`, between header and grid.
   - Before choosing: `CardComponent` body with the heading line, a supporting
     line, a **Choose students** `ButtonComponent` (primary, `sm`) as the
     trigger of a lazy-loaded `UiModalComponent` (`turbo_frame_src:` the
     picker), and **Upgrade instead** as a plain underlined text link to
     `pricing_path`. Not `AlertComponent`: it has no actions slot and its
     colored variants read as urgent.
   - After choosing: a single muted line styled like `_limit_prompt`
     (`text-sm text-muted-foreground`), with **Change** (text link, opens the
     same modal) and **Upgrade instead**.
2. **Student card** (`_student_card`, active + read-only) — `BadgeComponent`
   (`:neutral`, `sm`) "Read-only" next to the name; footer **View**
   `ButtonComponent` (secondary, `sm`) opening a lazy `UiModalComponent` at
   `student_path`. Not dimmed (dimming means archived).
3. **View modal** — `students/show.html.erb` inside the `modal-lazy-content`
   turbo frame (like `edit`). Modal title is the student's name. Action layout
   mirrors `_form`'s actions block: **Delete** (ghost, red, `delete_student_path`)
   left; **Close** (outline) and **Archive** (secondary, its own form to
   `student_archive_path`, no confirmation — same as today) right.
4. **Picker modal** — `students/kept/edit.html.erb` inside `modal-lazy-content`.
   Intro line; one `CheckboxComponent` per active student
   (`name: "student_ids[]"`, `value: student.id`, `checked:` if kept; label =
   name, `description:` = grade when present). Server error as
   `AlertComponent :error` above the list (same pattern as `_form` base
   errors). Actions: **Cancel** (outline), **Save** (primary).
5. **Stimulus** — new `pick_limit_controller.js` (~20 lines): `limit` value;
   disables unchecked boxes once `limit` are checked; enables Save only at
   exactly `limit`. Server validation is the real guarantee (works without JS).

### Copy (all in `en.yml`; follows ux-notes — no urgency, no exclamation points)

| Where | Copy |
|---|---|
| Banner, before choosing | "Premium ended. Choose which %{limit} students stay editable." / "Nothing's been deleted. You can change this anytime." / **Choose students** / Upgrade instead |
| Note, after choosing | "%{limit} students are editable on Free." / Change / Upgrade instead |
| Badge | Read-only |
| View modal | "%{name} can't be edited on Free. You can still archive or delete this student." |
| Picker title | "Choose students to keep editable" |
| Picker intro | "Choose %{limit}. The rest stay saved and read-only until you upgrade or archive some." |
| Picker error | "Choose %{limit} students to keep editable." |
| Saved notice | "Saved. %{names} stay editable." |
| Edit/update redirect | "%{name} can't be edited on Free. You can still archive or delete this student." |

Avoid gendered pronouns for students in copy ("this student", not "her").

### Edge cases

| Case | Behavior |
|---|---|
| Two parents save different picks at once | Family row lock serializes; last save wins (both valid). |
| Picker open while a student is archived elsewhere | Stale id fails validation; modal re-renders with error and a fresh list. |
| Picker open while family re-subscribes or archives down to 2 | `update` redirects to `/students`, no error. |
| Forged ids (other family, duplicate, archived) | Validation fails; nothing written. |
| No JS / wrong number ticked | Server error re-renders the modal. |
| Stale edit modal for a now-read-only student | `update` refused with the notice; nothing saved. |
| Kept student archived while over limit | Flag cleared; 1 kept → "Choose students" banner; other kept student stays editable. |
| Archive brings family to exactly 2 active | No banner; all editable; normal at-limit header prompt. |
| Restore while over limit | Blocked by existing COV-105 check. |
| `past_due` | Premium; no banner; picker route redirects. |
| Complimentary turned off | Same as any downgrade. |
| Old pick partly gone (kept student deleted while Premium) | 1 kept → "Choose students" banner. |
| Free family never Premium | Can't exceed 2 (COV-105), so never triggers. |

## Scope
**In:** `kept_on_free` migration; `Account`/`Student` methods above; archive
clears the flag; `StudentsController#show` + read-only guard on edit/update;
`Students::KeptController`; banner partial; card badge + View; View modal;
picker modal + `pick_limit_controller.js`; delete-confirm Cancel target;
fixtures; locale copy; product-brief updates; tests.

**Deferred / out of scope:** Billing and Stripe changes, any per-student fee,
other Free limits, the calendar/schedule itself, the students page redesign
(COV-107).

## Open Questions
None.

## More Info

**Docs updates (part of this ticket):**
- `docs/product/product-brief.md` Students section: change from "Decided, not
  built" to **Built**. Include COV-105's limits and counting rules (only active
  students count; restoring counts as adding; Free sees an upgrade prompt,
  Premium sees "Contact us"), archive/delete, and the downgrade rules above.
- Add a rule for future features: read-only students can't be assigned to new
  subjects, schedule blocks, or other new records, but keep appearing on
  existing ones.
- Architecture diagrams are updated at close-out, not here.

**Behavior rules (from the ticket):**
- No student is ever deleted by the system.
- Nothing outside `/students` is blocked.
- Adding students stays blocked by the existing limit check while over the limit.
