> Ticket: COV-93
> Branch: feature/cov-93-student-model-and-management

# Plan: Students — model and management

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 — Data foundation | 1 | Create the students table and database constraints | Master | ✅ |
| 2 | 1 — Data foundation | 1 | Implement student behavior and fixtures | Master | ✅ |
| 3 | 1 — Data foundation | 2 | Protect families with students during invitation acceptance | Master | |
| 4 | 1 — Data foundation | 2 | Add copy, privacy filtering, and demo students | Master | |
| 5 | 2 — Modal foundation | 3 | Add a custom trigger slot to `UiModalComponent` | Master | |
| 6 | 2 — Modal foundation | 3 | Document the modal trigger slot | Master | |
| 7 | 3 — Add and edit | 4 | Add student routes and create/update actions | Master | |
| 8 | 3 — Add and edit | 4 | Build the framed add/edit forms and color picker | subagent | |
| 9 | 3 — Add and edit | 4 | Replace the placeholder with the active-student list | subagent | |
| 10 | 4 — Archive and delete | 5 | Add archive and restore actions | Master | |
| 11 | 4 — Archive and delete | 5 | Add permanent deletion and confirmation | Master | |
| 12 | 4 — Archive and delete | 5 | Complete archived views and verify modal navigation | Master | |

## Prerequisites

- Design: `docs/designs/student-model-and-management.md`
- Prototype: None
- Feature branch exists: `feature/cov-93-student-model-and-management`
- Use the repository's fixtures-only Minitest convention. Student limits and the downgrade flow belong to later tickets.
- Run Rails commands with the mise Ruby shims on `PATH`; confirm `ruby -v` reports 4.0.5.

## Tasks

### Task 1 [Master]: Create the students table

**Skills:** safe-migration, write-tests
**Reference:** Read `db/migrate/20260918215009_add_student_limit_to_accounts.rb` and `db/schema.rb` for migration conventions.

**In scope:**

- Write database assertions first in `test/models/student_test.rb`: required account, name and color; a foreign key; and case-insensitive uniqueness within one family.
- Generate a migration with `account_id`, `name`, `grade_level`, `color`, `archived_at`, and timestamps. Make account, name, and color non-null; add the account foreign key and an expression unique index on `account_id` and `lower(name)`.
- Update `db/schema.rb` through migration, then verify migrate → rollback → migrate. Use `db:rollback:primary STEP=1` for this multi-database app and discard only unrelated schema-dump noise after inspecting it.

**NOT in scope:** Model validations, student limits, or student UI.

**Build order:**

1. **Test:** Add the database expectations in `test/models/student_test.rb`.
2. **Implement:** Generate the migration under `db/migrate/`; migrate to update `db/schema.rb`.
3. **Verify:** `bin/rails test test/models/student_test.rb`, then migrate → rollback → migrate.

### Task 2 [Master]: Implement student behavior and fixtures

**Skills:** write-tests
**Reference:** Read `app/models/account.rb` for `archive!` style and `test/fixtures/accounts.yml` for fixture labels.

**In scope:**

- Extend `test/models/student_test.rb` first for stripped names and grade levels, blank and 50-character limits, active versus archived duplicate messages, palette validation, ordered scopes, idempotent archive/restore, and color allocation. Cover two distinct initial colors, all eight used, tie order, and archived colors being excluded from counts.
- Implement `app/models/student.rb`: `COLORS`, account association, normalization, validations, `active`/`archived`, ordered listing, `archive!`, `restore!`, and `next_color_for(account)`. Assign a color on creation when none is provided.
- Add `test/fixtures/students.yml` with `one`, `two`, and `archived` on the `company` family, using account labels.

**NOT in scope:** Controllers, student limits, or UI.

**Build order:**

1. **Test:** Extend `test/models/student_test.rb` with the behaviors above.
2. **Implement:** Add `app/models/student.rb` and `test/fixtures/students.yml`.
3. **Verify:** `bin/rails test test/models/student_test.rb`.

When Tasks 1–2 are complete, run `/review-changes-mini` once for checkpoint 1. If they ran as a parallel batch, Master runs it after both return.

### Task 3 [Master]: Protect families with students during invitation acceptance

**Skills:** write-tests
**Reference:** Read `app/models/account.rb`, `app/services/family_invitation_acceptance.rb`, and their existing tests.

**In scope:**

- In `test/models/account_test.rb`, test that active and archived students block joining, another-parent precedence remains first, `students_empty?` calls the association directly, and destroying a family destroys its students.
- In `test/services/family_invitation_acceptance_test.rb`, test the student-specific refusal message and precedence when both another parent and students exist.
- Add `has_many :students, dependent: :destroy`; return `:has_students` after the other-parent check and before billing; remove the `respond_to?` fallback.
- Handle `:has_students` in `FamilyInvitationAcceptance`.

**NOT in scope:** Student limits, subscription quantity, or changes to the other invitation outcomes.

**Build order:**

1. **Test:** Extend the two existing test files.
2. **Implement:** Update `app/models/account.rb` and `app/services/family_invitation_acceptance.rb`.
3. **Verify:** `bin/rails test test/models/account_test.rb test/services/family_invitation_acceptance_test.rb`.

### Task 4 [Master]: Add copy, privacy filtering, and demo students

**Skills:** write-tests
**Reference:** Read `config/locales/en.yml`, `config/initializers/filter_parameter_logging.rb`, `db/seeds.rb`, and `docs/product/ux-notes.md`.

**In scope:**

- Add the design's student labels, field errors, archived section, confirmation, toast, and invitation message to `config/locales/en.yml`.
- Add `:grade_level` to the parameter filter; keep the existing `:name` filter.
- Add two idempotent students to the local "Cove Family" seed block, without touching production seeds.
- Add `test/integration/student_privacy_test.rb` to assert both `name` and `grade_level` are filtered.

**NOT in scope:** Sending student data to Loops, analytics, email, or error reports.

**Build order:**

1. **Test:** Add `test/integration/student_privacy_test.rb`.
2. **Implement:** Update the locale, filter, and seeds files.
3. **Verify:** `bin/rails test test/integration/student_privacy_test.rb`; run local seeds twice and confirm the demo family still has two seeded students.

When Tasks 3–4 are complete, run `/review-changes-mini` once for checkpoint 2. If they ran as a parallel batch, Master runs it after both return.

### Task 5 [Master]: Add a custom modal trigger

**Skills:** write-tests, style-ui
**Reference:** Read `app/components/ui_modal_component.rb`, its template, `test/components/ui_modal_component_test.rb`, and `test/components/previews/ui_modal_component_preview.rb`.

**In scope:**

- Test that a caller-supplied `ButtonComponent` opens the modal and that existing callers retain the default trigger.
- Add a `trigger` slot and render it in place of the built-in trigger when supplied; keep the modal's existing lazy loading, focus, and dismissal behavior.
- Add a preview showing a primary button in the trigger slot.

**NOT in scope:** Changes to Jumpstart's separate `ModalComponent` or modal styling beyond the supplied trigger.

**Build order:**

1. **Test:** Extend `test/components/ui_modal_component_test.rb`.
2. **Implement:** Update `app/components/ui_modal_component.rb`, `.html.erb`, and the preview.
3. **Verify:** `bin/rails test test/components/ui_modal_component_test.rb`.

### Task 6 [Master]: Document the modal trigger slot

**Skills:** style-ui
**Reference:** Read the existing `UiModalComponent` entry in `docs/COMPONENT_CATALOG.md`.

**In scope:**

- Update the catalog entry with the `trigger` slot, its required `click->ui-modal#open:prevent` action, and a `ButtonComponent` example.

**NOT in scope:** Other catalog entries or component previews.

**Build order:**

1. **Test:** Use Task 5's component test as the behavior check.
2. **Implement:** Update `docs/COMPONENT_CATALOG.md`.
3. **Verify:** `bin/rails test test/components/ui_modal_component_test.rb`.

When Tasks 5–6 are complete, run `/review-changes-mini` once for checkpoint 3.

### Task 7 [Master]: Add student routes and create/update actions

**Skills:** write-tests
**Reference:** Read `config/routes.rb`, `app/controllers/students_controller.rb`, and `app/controllers/accounts_controller.rb`.

**In scope:**

- Write `test/integration/students_test.rb` first for sign-in, both parents' access, tenant-scoped 404s, permitted fields, add/edit, duplicate handling including a `RecordNotUnique` race, and 422 responses that preserve submitted values.
- Expand RESTful student routes, including a nested singular archive resource and a `delete` confirmation GET.
- Implement index, new, create, edit, and update in `StudentsController`; scope every record lookup through `Current.account.students`. Redirect edits of archived students to `/students`. Keep parameters explicit.
- Return framed new/edit responses and 422 framed validation responses; successful writes redirect to `/students` with the specified notice.
- Replace the obsolete student-specific assertion in `test/integration/coming_soon_pages_test.rb` with an assertion for the new students page; retain assertions for the other placeholder pages.

**NOT in scope:** Archive/restore/delete action bodies, limit enforcement, or a Pundit policy.

**Build order:**

1. **Test:** Add `test/integration/students_test.rb` and update `test/integration/coming_soon_pages_test.rb`.
2. **Implement:** Update `config/routes.rb` and `app/controllers/students_controller.rb`.
3. **Verify:** Run the focused integration tests, completing their view-dependent assertions with Tasks 8–9 before checkpoint review.

### Task 8 [subagent]: Build the framed add/edit forms and color picker

**Skills:** write-tests, style-ui
**Reference:** Read `FormFieldComponent` and `ButtonComponent` in `docs/COMPONENT_CATALOG.md` and the modal frame ID in `app/javascript/controllers/ui_modal_controller.js`.

**In scope:**

- Complete the form assertions introduced in Task 7 for labels, maxlength, retained values/errors, and the native radio group.
- Add `app/views/students/new.html.erb`, `edit.html.erb`, `_form.html.erb`, and `_color_picker.html.erb`.
- Use `turbo_frame_tag "modal-lazy-content"`; `form_with`; labeled name and grade fields; eight accessible swatches with a selected ring and check mark; and the design's add/save controls.

**NOT in scope:** Archive/delete controls until their endpoints exist, custom JavaScript for radios, or a reusable catalog color component.

**Build order:**

1. **Test:** Use Task 7's failing integration assertions for framed forms and validation.
2. **Implement:** Add the four view files.
3. **Verify:** `bin/rails test test/integration/students_test.rb`.

### Task 9 [subagent]: Replace the placeholder with the active-student list

**Skills:** write-tests, style-ui
**Reference:** Read `CardComponent`, `EmptyStateComponent`, `ButtonComponent`, and `UiModalComponent` in the catalog; read `app/views/students/index.html.erb`.

**In scope:**

- Add `test/integration/students_index_test.rb` first for creation-order cards, optional grade text, no-active-students empty state, and add/edit modal triggers.
- Replace the placeholder index with its header, primary Add trigger, active card grid, color dots, grade labels, and Edit triggers.
- Add `app/views/students/_color_dot.html.erb` and eight `--student-*` tokens in `app/assets/tailwind/application.css`. Choose muted colors with measured ≥3:1 contrast against white and cream, without repeating hex values in views.

**NOT in scope:** Archived section or archive/delete actions.

**Build order:**

1. **Test:** Add `test/integration/students_index_test.rb`.
2. **Implement:** Update the index, add the dot partial, and add CSS tokens.
3. **Verify:** `bin/rails test test/integration/students_index_test.rb test/integration/coming_soon_pages_test.rb`.

When Tasks 7–9 are complete, run `/review-changes-mini` once for checkpoint 4. If Tasks 8–9 ran in parallel, Master runs it after both return.

### Task 10 [Master]: Add archive and restore

**Skills:** write-tests
**Reference:** Read `app/models/student.rb`, the singular archive route from Task 7, and `app/controllers/students_controller.rb`.

**In scope:**

- Add `test/integration/student_archives_test.rb` first for both parents, tenant-scoped 404s, archive/restore, idempotent requests, unchanged color on restore, and notices.
- Implement `app/controllers/students/archives_controller.rb` with `create` and `destroy`, scoped student lookup, and redirects to `/students`.

**NOT in scope:** Permanent deletion or archived card rendering.

**Build order:**

1. **Test:** Add `test/integration/student_archives_test.rb`.
2. **Implement:** Add `app/controllers/students/archives_controller.rb`.
3. **Verify:** `bin/rails test test/integration/student_archives_test.rb`.

### Task 11 [Master]: Add permanent deletion and confirmation

**Skills:** write-tests, style-ui
**Reference:** Read `app/controllers/students_controller.rb`, the form from Task 8, and `docs/product/product-brief.md`'s student deletion rule.

**In scope:**

- Extend `test/integration/students_test.rb` first for framed confirmation, both parents' ability to delete, tenant-scoped 404s, and removal of the record.
- Add `delete` and `destroy` to `StudentsController`. Render `app/views/students/delete.html.erb` in `modal-lazy-content`; destroy with the specified notice.
- Add Archive and Delete controls to the edit form. The Delete link loads confirmation into the same frame; Cancel returns to edit for an active student and closes for an archived student.

**NOT in scope:** Undo deletion or deleting another family's student.

**Build order:**

1. **Test:** Extend `test/integration/students_test.rb`.
2. **Implement:** Update the controller and form; add the confirmation view.
3. **Verify:** `bin/rails test test/integration/students_test.rb`.

### Task 12 [Master]: Complete archived views and modal navigation

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/students/index.html.erb`, `app/javascript/controllers/turbo_resilience_controller.js`, and `test/system/turbo_resilience_system_test.rb`.

**In scope:**

- Write `test/system/students_system_test.rb` first for add/edit validation in the open modal; successful full-page navigation, closed modal, and toast; archive toggle, restore, and confirmed delete. Synchronize on visible post-submit state.
- Extend the index with the archived count toggle, `?archived=1` section, muted cards, Restore button, and Delete modal. Keep action controls at full contrast and give the archived `<h2>` a sans class.
- Resolve the existing `turbo:frame-missing` handler's conflict with successful frame-form redirects: for a successful redirected modal-frame response, prevent the missing-frame fallback and visit the response as a full page. Keep its network-failure behavior for actual failures.

**NOT in scope:** Student limits, downgrade selection, student detail pages, or reusable student pickers.

**Build order:**

1. **Test:** Add `test/system/students_system_test.rb`, including 422 and successful redirect paths.
2. **Implement:** Update the index and `app/javascript/controllers/turbo_resilience_controller.js`.
3. **Verify:** Run `bin/rails test:system test/system/students_system_test.rb` separately from other Rails test processes.

When Tasks 10–12 are complete, run `/review-changes-mini` once for checkpoint 5. Then run the full Rails test suite, system suite, RuboCop, and `git diff --check` sequentially; inspect `git diff` before reporting completion.

## Task Dependencies

- Task 2 depends on Task 1.
- Task 3 depends on Task 2; Task 4 can proceed once the Student model exists.
- Task 5 is independent of the student data work; Task 6 follows Task 5.
- Task 7 depends on Tasks 2–4. Tasks 8–9 depend on Tasks 5 and 7; their view work can run in parallel after Task 7 establishes routes and tests.
- Tasks 10–11 depend on the student routes and forms. Task 12 depends on Tasks 9–11.
- Each phase reaches a usable boundary: persisted student data; reusable modal support; add/edit management; then the complete archive/delete flow.
