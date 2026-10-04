> Ticket: COV-106
> Branch: feature/cov-106-students-downgrade-flow

# Plan: Students — downgrade flow

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add the `kept_on_free` column | Master | ✅ |
| 2 | 1 | 1 | Add downgraded-family fixtures | subagent | ✅ |
| 3 | 1 | 2 | Add family limit and picker rules | Master | ✅ |
| 4 | 1 | 2 | Compute student editability and clear picks on archive | subagent | ✅ |
| 5 | 2 | 3 | Block direct edits to read-only students | Master | ✅ |
| 6 | 2 | 3 | Add the picker route, controller, and modal | Master | ✅ |
| 7 | 2 | 3 | Add the read-only View modal and delete return path | Master | ✅ |
| 8 | 3 | 4 | Show the downgrade banner and suppress header actions | Master | ✅ |
| 9 | 3 | 4 | Show read-only cards with View actions | subagent | ✅ |
| 10 | 3 | 4 | Add picker interaction and system coverage | subagent | ✅ |
| 11 | 3 | 5 | Update the product brief and run final verification | Master | ✅ |

## Prerequisites

- Design: [student-downgrade-flow.md](../designs/student-downgrade-flow.md)
- Prototype: None
- Feature branch exists: `feature/cov-106-students-downgrade-flow`
- Before Rails commands, put mise shims on `PATH` and confirm Ruby 4.0.5. Run Rails and system test processes sequentially in this worktree.
- Use this project's hand-written Minitest fixtures. Its project-specific fixture rule takes precedence over the imported generic factory guidance.

## Tasks

### Task 1 [Master]: Add the `kept_on_free` column

**Skills:** safe-migration, write-tests
**Reference:** Read `db/migrate/20261003120000_create_students.rb` and the database assertions in `test/models/student_test.rb`.

**In scope:**

- Generate a migration adding `students.kept_on_free` as boolean, `default: false`, `null: false`, without an index.
- Add a database-level test for the default and non-null constraint.

**NOT in scope:**

- Family selection rules or views.

**Build order:**

1. **Test:** Add the database assertions in `test/models/student_test.rb` and observe the missing-column failure.
2. **Implement:** Generate the migration in `db/migrate/`; run migrate → rollback → migrate, inspecting schema changes for unrelated Rails dumper noise.
3. **Verify:** `bin/rails test test/models/student_test.rb`

### Task 2 [subagent]: Add downgraded-family fixtures

**Skills:** None
**Reference:** Read `test/fixtures/accounts.yml`, `users.yml`, `account_users.yml`, and `students.yml`.

**In scope:**

- Add matching `downgraded` account, user, and membership labels.
- Add five active students on that family: `kept` and `kept_two` selected; `read_only`, `read_only_two`, and `read_only_three` unselected. Use literal names and association labels.

**NOT in scope:**

- Changes to existing fixture families or subscription fixtures.

**Build order:**

1. **Test:** Run an existing fixture-loading student test to establish the starting result.
2. **Implement:** Update the four fixture files.
3. **Verify:** `bin/rails test test/models/student_test.rb`

After Tasks 1–2, run `review-changes-mini` once for checkpoint 1. If run as a parallel batch, the Master runs the review after both tasks return.

### Task 3 [Master]: Add family limit and picker rules

**Skills:** write-tests
**Reference:** Read `app/models/account.rb` and `test/models/account_test.rb`, including the existing Premium status and reload tests.

**In scope:**

- Add `over_free_student_limit?`, memoized per account instance and cleared by `reload`.
- Add `student_pick_needed?`, counting only active selected students.
- Add `keep_students_on_free(ids)`: lock the family row, validate exactly two distinct active IDs belonging to that family, replace the selection in one transaction, and return `false` with an account error on invalid input.
- Cover never-picked, changed picks, forged, duplicate, archived, and cross-family IDs; Free, Premium, `past_due`, and re-subscription behavior.

**NOT in scope:**

- Controllers, student editability, or billing changes.

**Build order:**

1. **Test:** Add behavior-focused tests in `test/models/account_test.rb`, including the memoization and reload cases.
2. **Implement:** Add the methods in `app/models/account.rb`.
3. **Verify:** `bin/rails test test/models/account_test.rb`

### Task 4 [subagent]: Compute editability and clear picks on archive

**Skills:** write-tests
**Reference:** Read `app/models/student.rb`, `test/models/student_test.rb`, and `test/integration/student_archives_test.rb`.

**In scope:**

- Add `Student#editable?` from the family's current over-limit state and the student's stored pick.
- Clear `kept_on_free` when archiving, including the already-archived case where applicable.
- Test that archiving a kept student leaves the other pick intact; reaching two active students makes both editable; re-subscribing makes all editable while retaining flags for a later downgrade. Preserve the existing restore limit check.

**NOT in scope:**

- A model validation blocking all student updates; archive and delete must remain available.

**Build order:**

1. **Test:** Add student and archive behavior tests.
2. **Implement:** Update `app/models/student.rb`.
3. **Verify:** `bin/rails test test/models/student_test.rb test/integration/student_archives_test.rb`

Task 4 depends on Task 3. After Tasks 3–4, run `review-changes-mini` once for checkpoint 2.

### Task 5 [Master]: Block direct edits to read-only students

**Skills:** fix-bug, write-tests
**Reference:** Read `app/controllers/students_controller.rb` and `test/integration/students_test.rb`.

**In scope:**

- Guard both `edit` and `update` after the current-family student lookup; redirect read-only requests to `/students` with the design's notice.
- Test unchanged data after a direct PATCH, stale edit requests, allowed edits to selected students, and renewed Premium access.
- Preserve the existing archived-student behavior and family-scoped 404.

**NOT in scope:**

- Blocking archive, delete, or records outside `/students`.

**Build order:**

1. **Test:** Add integration tests in `test/integration/students_test.rb`.
2. **Implement:** Update `app/controllers/students_controller.rb`.
3. **Verify:** `bin/rails test test/integration/students_test.rb`

### Task 6 [Master]: Add the picker route, controller, and modal

**Skills:** write-tests, style-ui
**Reference:** Read `config/routes.rb`, `app/views/students/edit.html.erb`, `app/views/students/_form.html.erb`, and the catalog entries for `CheckboxComponent`, `AlertComponent`, `ButtonComponent`, and `UiModalComponent`. The catalog scan found all required components.

**In scope:**

- Add `/students/kept/edit` and its update route, handled by `Students::KeptController`.
- Render active students in grid order inside the lazy modal frame, with selected checkboxes, grade descriptions, and a server error alert.
- Accept only scoped active IDs. Redirect when the family is no longer over the Free limit; on valid save redirect with selected names; on invalid save rerender the refreshed picker with an error and no changed flags.
- Test authentication, validation, stale state, and another family's IDs.

**NOT in scope:**

- Client-side checkbox behavior or new catalog components.

**Build order:**

1. **Test:** Add `test/integration/students_kept_test.rb` for the routes and responses.
2. **Implement:** Update `config/routes.rb`; add `app/controllers/students/kept_controller.rb` and `app/views/students/kept/edit.html.erb`.
3. **Verify:** `bin/rails test test/integration/students_kept_test.rb`

### Task 7 [Master]: Add the read-only View modal and delete return path

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/students/edit.html.erb`, `_form.html.erb`, `delete.html.erb`, and `test/integration/students_test.rb`.

**In scope:**

- Add `StudentsController#show` with the existing current-family lookup and a `students/show.html.erb` lazy modal frame showing color, name, grade, explanation, Delete, Close, and Archive.
- Make the delete confirmation's Cancel link return to View for a read-only active student and Edit for an editable active student; retain archived behavior.
- Test View, archive and delete access, the return links, authentication, and cross-family 404.

**NOT in scope:**

- Changing delete confirmation copy or archived card actions.

**Build order:**

1. **Test:** Extend `test/integration/students_test.rb`.
2. **Implement:** Update `app/controllers/students_controller.rb` and `app/views/students/delete.html.erb`; add `app/views/students/show.html.erb`.
3. **Verify:** `bin/rails test test/integration/students_test.rb`

Tasks 5–7 are sequential because they share the student routes and controller. After Task 7, run `review-changes-mini` once for checkpoint 3.

### Task 8 [Master]: Show the downgrade banner and suppress header actions

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/students/index.html.erb`, `_limit_prompt.html.erb`, `test/integration/students_index_test.rb`, `docs/product/ux-notes.md`, and the catalog entries for `CardComponent`, `ButtonComponent`, and `UiModalComponent`.

**In scope:**

- Add `students/_free_limit_banner.html.erb` above the grid with the design's before-pick and after-pick states, lazy picker trigger, and `/pricing` link.
- While over the Free limit, hide both the header Add trigger and the normal limit prompt.
- Add the approved copy under `students` in `config/locales/en.yml`.
- Test no-pick, saved-pick, Premium, `past_due`, and return-to-limit states.

**NOT in scope:**

- A page redesign or a new banner component.

**Build order:**

1. **Test:** Extend `test/integration/students_index_test.rb`.
2. **Implement:** Update `index.html.erb` and `en.yml`; add `_free_limit_banner.html.erb`.
3. **Verify:** `bin/rails test test/integration/students_index_test.rb`

### Task 9 [subagent]: Show read-only cards with View actions

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/students/_student_card.html.erb`, `test/integration/students_index_test.rb`, and the catalog entries for `BadgeComponent`, `ButtonComponent`, and `UiModalComponent`.

**In scope:**

- Show a neutral small Read-only badge beside an active unselected student's name and a View modal trigger in place of Edit.
- Keep selected, Premium, and under-limit cards editable. Keep archived cards' existing appearance and actions.
- Test each card state and its modal URL.

**NOT in scope:**

- Dimming active read-only cards or changing the View modal itself.

**Build order:**

1. **Test:** Extend `test/integration/students_index_test.rb`.
2. **Implement:** Update `app/views/students/_student_card.html.erb`.
3. **Verify:** `bin/rails test test/integration/students_index_test.rb`

Task 9 follows Task 8 because both extend the index tests.

### Task 10 [subagent]: Add picker interaction and system coverage

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/students/kept/edit.html.erb`, `test/system/students_system_test.rb`, and an existing `app/javascript/controllers/` Stimulus controller.

**In scope:**

- Add `pick_limit_controller.js`: once two boxes are checked, disable unchecked boxes; enable Save only at exactly two; recompute when a box changes.
- Wire the existing picker modal to that controller.
- System-test the checked/disabled/Save states, saving a pick, changing it, and viewing a read-only student. Keep server validation authoritative when JavaScript is unavailable.

**NOT in scope:**

- A JavaScript-only selection rule or another interaction framework.

**Build order:**

1. **Test:** Extend `test/system/students_system_test.rb` with the picker and View flows.
2. **Implement:** Add `app/javascript/controllers/pick_limit_controller.js` and update `app/views/students/kept/edit.html.erb`.
3. **Verify:** `bin/rails test:system test/system/students_system_test.rb`

Task 10 follows Task 6 and can proceed alongside Task 9 once Task 8 is complete; their implementation files do not overlap. The Master runs `review-changes-mini` once for checkpoint 4 after Tasks 8–10 all finish.

### Task 11 [Master]: Update product rules and run final verification

**Skills:** None
**Reference:** Read the Students section of `docs/product/product-brief.md` and the COV-105 limit rules already in the code.

**In scope:**

- Mark Students as built and document active-student counting, creation and restore limits, Free and Premium limit prompts, archive and delete behavior, downgrade picking, re-subscription, and the future rule that read-only students cannot receive new assignments but retain existing ones.
- Run focused tests, then the full Rails suite, system tests, RuboCop, and `git diff --check`. Inspect `git diff` before reporting completion during execution.

**NOT in scope:**

- Billing, Stripe, schedules, or architecture diagrams; the design assigns diagram updates to close-out.

**Build order:**

1. **Test:** Compare the documented rules with the completed behavior tests and add any missing acceptance coverage in the relevant existing test file before changing behavior.
2. **Implement:** Update `docs/product/product-brief.md`.
3. **Verify:** `bin/rails test`, `bin/rails test:system`, `bin/rubocop`, and `git diff --check`

After Task 11, run `review-changes-mini` once for checkpoint 5, followed by the final `/review-changes` gate required by `/execute-plan`.

## Task Dependencies

- Task 2 depends on Task 1's column. Tasks 3 and 4 depend on the fixtures; Task 4 also depends on Task 3's family rule.
- Tasks 5–7 depend on the model rules and proceed sequentially where they share routes or controller code.
- Task 8 depends on the picker route and modal. Task 9 follows Task 8's index tests. Task 10 depends on the picker modal and may run alongside Task 9 after Task 8.
- Task 11 follows the completed behavior and UI.
