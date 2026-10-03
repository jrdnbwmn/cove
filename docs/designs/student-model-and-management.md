> Ticket: COV-93
> Branch: feature/cov-93-student-model-and-management
> Plan created: docs/plans/student-model-and-management.md

# Feature: Students — model and management

## Problem
`/students` is a "Coming soon" placeholder and there is no `Student` model. Parents need to add, edit, archive, restore, and delete the students in their family, and later features (subjects, schedule blocks, the log, grades) need a base `Student` record to reference.

This is ticket 1 of 3: (1) model and management, (2) plan limits, (3) downgrade flow. **Student limits are not enforced in this ticket** — a Free family can temporarily add more than 2.

## Approach
Standard RESTful Rails resource, server-rendered, with forms lazy-loaded into a modal.

- `StudentsController` — `index`, `new`, `create`, `edit`, `update`, `destroy`, plus a `delete` (confirmation) GET action. Every lookup is `Current.account.students.find(...)`, so another family's student is a 404. No Pundit policy (the app has none for account-scoped resources); both parents are admins and can do everything.
- `Students::ArchivesController` — `create` (archive) and `destroy` (restore), routed as a singular nested resource: `POST /students/:student_id/archive`, `DELETE /students/:student_id/archive`. Models archived state as a resource instead of custom verbs.
- Add/Edit/Delete-confirm open a `UiModalComponent` with `lazy_load` + `turbo_frame_src`, which loads the form into a turbo-frame (`id="modal-lazy-content"` — the component's fixed id; responses must render a frame with that id).
  - **Success** (create/update/archive/destroy/restore) redirects to `students_path` with `flash[:notice]`, and the page does a full Turbo visit so the modal closes and the global toast shows. A frame response without the matching frame fires `turbo:frame-missing`; handle it with the standard pattern (`event.preventDefault(); event.detail.visit(event.detail.response)`) — plan decides where that lives (small Stimulus controller or `data-turbo-frame="_top"` on the success path).
  - **Validation error** re-renders the form in the frame with status 422; typed values are kept.
- **Extend `UiModalComponent`** with a `trigger` slot so callers can pass any `ButtonComponent` as the opener (the built-in trigger is a fixed white outline button). When the slot is absent, behavior is unchanged. Update its catalog entry/preview accordingly.
- Color swatch picker and color dot are **partials**, not catalog components (`students/_color_picker`, `students/_color_dot`). The dot will be reused by Subjects/Schedule later.

## Acceptance Criteria
Tests first (TDD). Each is a behavior from the parent's perspective:

- A parent can add a student with only a name, and it gets a palette color automatically.
- A second student gets a different color than the first.
- With all 8 colors used by active students, the next student gets the least-used color (earliest in palette on ties).
- A family can't have two students with the same name, ignoring case and surrounding spaces; the error differs when the existing student is archived.
- Name and grade level are each capped at 50 characters; grade level is optional free text.
- A color outside the palette is rejected.
- The other parent in the family can also add and edit students.
- A parent can't see, edit, archive, restore, or delete another family's students (404).
- A parent can archive a student; it disappears from the main list and shows under "Show archived".
- A parent can restore an archived student.
- Archived students can't be edited (edit/update redirect to `/students`), but can be deleted.
- A parent can permanently delete a student after confirming.
- Deleting a family deletes its students.
- A user whose family has students (including only archived ones) can't accept another family's invite, and sees the students message, not the other-parent message.
- `Account#students_empty?` fails loudly if the association is renamed (no `respond_to?` guard).
- `grade_level` is filtered from logs (present in `filter_parameters`).
- Empty state shows when the family has no active students.

## Prototype
None.

## Data Model

**New table `students`**

| Column | Type | Rules |
|---|---|---|
| `account_id` | references | `null: false`, FK to `accounts`, indexed |
| `name` | string | `null: false`; required; max 50; stripped before save |
| `grade_level` | string | nullable; optional free text; max 50; stripped, blank → `nil` |
| `color` | string | `null: false`; must be in `Student::COLORS` |
| `archived_at` | datetime | nullable; nil = active |
| timestamps | | `created_at` is the sort order |

- Unique index on `account_id` + `lower(name)` (expression index). Use the safe-migration skill.
- Model validates uniqueness case-insensitively scoped to `account_id` for a friendly message; controller also rescues `ActiveRecord::RecordNotUnique` (two-parent race) and shows the same duplicate error.
- Error messages:
  - blank name: "Enter a name to continue."
  - duplicate active: "You already have a student named %{name}."
  - duplicate archived: "You already have an archived student named %{name}. Restore them from archived students, or use a different name."

**Associations / scopes / methods**
- `Account has_many :students, dependent: :destroy` (family deletion is a real `destroy`).
- `Student belongs_to :account`.
- Scopes: `active` (`archived_at: nil`), `archived` (`archived_at` not nil). Order by `created_at`.
- `archive!` / `restore!` (idempotent), mirroring `Account#archive!`.
- `Student::COLORS = %w[sage sea sky lavender rose clay ochre slate]` — the DB stores the key only.
- `Student.next_color_for(account)` — least-used color among the family's **active** students, earliest in `COLORS` on ties. Assigned on create when no color is given; the `new` form pre-selects it.
- No birthdate, avatar, notes, or position column.

**Color tokens**
- One CSS token per key in `application.css` (e.g. `--student-sage`); views reference tokens, never hex. Muted tones that sit with teal/cream/coral and the warm stone neutrals, distinct from the exact brand teal/coral. Each must reach ≥3:1 contrast against both white cards and the cream background (non-text contrast).

**`Account` changes**
- `unjoinable_reason`: keep the other-parent check first (`:other_members`), then return new `:has_students` unless `students_empty?`, then `:billable_subscription`.
- `students_empty?` → `students.none?` (any student, **archived included**, blocks joining — archived records are still family data; note this decision in the PR).
- `FamilyInvitationAcceptance` handles `:has_students` with new i18n key `family_invitation_acceptance.has_students`: "Your family has students in it. Contact support to join a new family."

**Privacy**
- Add `:grade_level` to `config/initializers/filter_parameter_logging.rb` (Honeybadger inherits this list). `name` is already filtered.

**Fixtures / seeds**
- `test/fixtures/students.yml`: `one` (sage) and `two` (sea) on `company` (the two-parent family, so second-parent tests work); `archived` on `company` with `archived_at` set. Reference accounts by label.
- `db/seeds.rb`: give the "Cove Family" demo family 2 students (idempotent `find_or_create_by!`).

## Screens / Flows

**`/students` (index)**
- Header: `<h1>Students</h1>` left; **Add student** right — `UiModalComponent` (`lazy_load`, `turbo_frame_src: new_student_path`, title "Add student") with a primary `ButtonComponent` in the new `trigger` slot.
- **Empty state** (no active students): `EmptyStateComponent`, icon `users`, title "Add your first student", description "Each student gets a color so you can spot them across Cove.", action = the Add trigger.
- **Card grid** `grid gap-4 sm:grid-cols-2 lg:grid-cols-3`, one `CardComponent` per active student, in `created_at` order:
  - color dot + name (wraps, never truncated)
  - grade level in `text-muted-foreground` if set
  - footer: **Edit** — `UiModalComponent` (`turbo_frame_src: edit_student_path(student)`, title "Edit %{name}")
- "Show archived (%{count})" / "Hide archived" plain link toggling `?archived=1`; shown only when the family has archived students.
- With `?archived=1`: an "Archived" `<h2 class="font-sans ...">` section below, same grid, muted cards (reduced opacity on dot/text; buttons stay full contrast). Footer: **Restore** (`ButtonComponent :secondary`, `button_to` → `DELETE student_archive_path`) and **Delete** (modal trigger → `delete_student_path`). If no archived students remain, the section/link don't render.

**Add / edit form (`students/_form`, in the modal frame)**
- Name — `FormFieldComponent`, required, `maxlength: 50`, autofocus.
- Grade level — `FormFieldComponent`, placeholder "e.g. 3rd, Pre-K", `maxlength: 50`.
- Color — `<fieldset>` with legend "Color", 8 radios rendered as round swatches; each has an accessible label of its color name ("Sage"); selected swatch shows a ring **and** a check mark (not color alone); arrow-key navigable as a native radio group.
- Add mode: **Add student** (`:primary`, full width on phones). Enter submits. Modal closes on save.
- Edit mode: **Save** (`:primary`); below a divider, **Archive %{name}** (`:secondary`, `button_to` → `POST student_archive_path`) and **Delete %{name}** (quiet destructive link that loads `delete_student_path` into the same frame).
- Errors inline via `FormFieldComponent` `error:`.

**Delete confirmation (`students/delete`, in the frame)**
- "Delete %{name}? This permanently removes %{name} and can't be undone. To keep their records, archive instead."
- **Delete %{name}** (`:destructive`, `button_to` method delete) and **Cancel** (returns to the edit form for active students; closes the modal for archived ones).

**Toasts** (`flash[:notice]`, rendered by the global `UiToastComponent`):
- "%{name} added." · "Saved." · "%{name} archived." · "%{name} restored." · "%{name} deleted."

All copy goes in `config/locales/en.yml`. Copy follows `ux-notes.md`: no exclamation points, no emoji, plain confirmations.

## Edge Cases
- Other family's student id → 404 on every action (scoped `find`).
- Signed-out → sign in (`authenticate_user!`). Both parents have full access; nothing is owner-only.
- Whitespace-only name → blank error. Case/whitespace variants count as duplicates.
- Off-palette color → validation error; missing color → auto-assigned.
- Archive an already-archived student / restore an active one → no-op, normal redirect + toast.
- Restore can't clash on name (uniqueness covers archived).
- Edit/update on an archived student → redirect to `/students`.
- Archived student frees its color for auto-assign; restoring keeps its old color even if now shared (duplicates allowed).
- Concurrent delete while the other parent edits → their save gets 404; acceptable.
- Network failure on save → Turbo leaves the form intact; no custom retry.
- Escape/backdrop discards unsaved input (standard modal behavior).
- Family with another parent **and** students → other-parent message wins (that check runs first).
- Student names in flash are fine (encrypted session cookie, not logged).

## Scope
**In:** `Student` model + migration + palette tokens; `StudentsController` and `Students::ArchivesController`; index (card grid, empty state, archived view), add/edit modal, delete confirmation; `UiModalComponent` `trigger` slot; color picker + dot partials; `Account#unjoinable_reason` `:has_students` + `students_empty?` guard removal; `FamilyInvitationAcceptance` message; `grade_level` log filtering; fixtures; seeds.

**Deferred:** student limits (ticket 2), downgrade flow (ticket 3), reusable student picker (built with Subjects), student detail page, JSON API, birthdate, avatars, notes, manual reordering, student logins, undo-in-toast, "save and add another".

## Open Questions
None. Exact hex values for the 8 palette tokens are chosen during implementation against the ≥3:1 contrast rule.

## More Info
- Product rules: `docs/product/product-brief.md` (Students, Families, Student data). Deleting a student must remove their data — this fulfills the privacy policy's promise that parents can delete students' information at any time.
- `docs/architecture/data-model.mermaid` and `routes-map.mermaid` get updated by close-out, not by this work.
- Known gotchas to respect: bare `<h2>` inherits the serif — add `font-sans`; Capybara can't `click_button` by `aria-label`; system tests for lazy-loaded frames must not race Stimulus controller load.
