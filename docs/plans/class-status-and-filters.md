> Ticket: COV-111
> Branch: feature/cov-111-class-status-and-filters

# Plan: Classes — status and filters

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add class status persistence and model behavior | Master | ✅ |
| 2 | 1 | 1 | Add status routes and scoped transition controllers | Master | ✅ |
| 3 | 1 | 1 | Preserve list state through existing class mutations | Master | ✅ |
| 4 | 2 | 2 | Build filtered status-aware list query | Master | ✅ |
| 5 | 2 | 2 | Render the filter toolbar, tabs, and empty states | subagent | ✅ |
| 6 | 2 | 2 | Add class-card status dates and action menus | subagent | ✅ |
| 7 | 3 | 3 | Add editable modal status controls and unsaved-change guard | Master | ✅ |
| 8 | 3 | 3 | Update product behavior documentation | Master | ✅ |
| 9 | 4 | 4 | Run final feature and quality verification | Master | ✅ |

## Prerequisites

- Design: [docs/designs/class-status-and-filters.md](../designs/class-status-and-filters.md)
- Prototype: None
- Feature branch exists: `feature/cov-111-class-status-and-filters`
- Use Ruby 4.0.5 via mise shims for every Rails command.
- The plan relies on the existing `SelectComponent`, link-mode underline `UiTabsComponent`, `DropdownComponent`, `UiModalComponent`, and `EmptyStateComponent`; no new component or JavaScript controller is needed.

## Tasks

### Task 1 [Master]: Add class status persistence and model behavior

**Skills:** safe-migration, write-tests
**Reference:** Read `app/models/course.rb`, `test/models/course_test.rb`, and `test/fixtures/courses.yml` for the existing Course conventions.

**In scope:**

- Generate a migration adding nullable `completed_at` and `archived_at` to `courses`, plus the named `courses_not_completed_and_archived` database constraint.
- Add Course status scopes, predicates, guarded transition methods, validation, learner/subject filter scopes, and case-insensitive subject options scoped to a family.
- Add active `completed` and `archived` company-family fixtures, with fixed relative timestamps.
- Cover valid transitions, rejected stale transitions, direct status conflicts, constraint enforcement, filters, and subject-option selection.

**NOT in scope:**

- New indexes, a status enum/column, a data backfill, or any schedule behavior.

**Build order:**

1. **Test:** Extend `test/models/course_test.rb` for model transitions, validation, filter scopes/options, and the database constraint.
2. **Implement:** Generate `db/migrate/*_add_statuses_to_courses.rb`; update `app/models/course.rb` and `test/fixtures/courses.yml`.
3. **Verify:** Run migration forward, `bin/rails db:rollback:primary STEP=1`, migrate forward again, then `bin/rails test test/models/course_test.rb`.

### Task 2 [Master]: Add status routes and scoped transition controllers

**Skills:** write-tests
**Reference:** Read `app/controllers/learners/archives_controller.rb`, `config/routes.rb`, and `test/integration/courses_test.rb`.

**In scope:**

- Add nested singular completion and archive resources beneath classes.
- Implement `Courses::CompletionsController` and `Courses::ArchivesController`, scoped through `Current.account.courses`.
- Use model transition results to emit the approved notice/alert copy and redirect back to the filtered/tabbed list.
- Test completion, reopen, archive, restore, stale requests, guest redirects, and cross-family 404s.

**NOT in scope:**

- Altering learner archive behavior or adding authorization abstractions.

**Build order:**

1. **Test:** Add endpoint behavior and family-isolation coverage in `test/integration/courses_test.rb`.
2. **Implement:** Update `config/routes.rb`; add `app/controllers/courses/completions_controller.rb` and `app/controllers/courses/archives_controller.rb`.
3. **Verify:** `bin/rails test test/integration/courses_test.rb`.
4. **Checkpoint:** After Tasks 1–3 are complete, run `review-changes-mini` once for Checkpoint 1. If work was parallelized, the master runs it after all three tasks return.

### Task 3 [Master]: Preserve list state through existing class mutations

**Skills:** write-tests
**Reference:** Read `app/controllers/courses_controller.rb`, `app/views/courses/_add_trigger.html.erb`, `app/views/courses/_course_card.html.erb`, and `test/integration/courses_test.rb`.

**In scope:**

- Keep valid `status`, learner, and subject list state when adding, editing, deleting, or opening a class from the list.
- Ensure a newly added active class returns to the originating tab/filter URL and remains invisible on a non-Active tab until that tab changes.
- Preserve delete confirmation and safe fallback to `/classes`.

**NOT in scope:**

- Changing class form fields or status semantics.

**Build order:**

1. **Test:** Add return-path and status-preservation requests to `test/integration/courses_test.rb`.
2. **Implement:** Update `app/controllers/courses_controller.rb`, `app/views/courses/_add_trigger.html.erb`, and the existing card link behavior as required.
3. **Verify:** `bin/rails test test/integration/courses_test.rb`.

### Task 4 [Master]: Build the filtered, status-aware list query

**Skills:** write-tests
**Reference:** Read `app/controllers/courses_controller.rb`, `app/models/course.rb`, and `test/integration/courses_index_test.rb`.

**In scope:**

- Parse `status`, learner, and subject query parameters safely.
- Ignore unknown status and foreign, archived, or malformed learner parameters.
- Apply filters in combination, preload enrollments, retain the active-learner lookup, and calculate tab counts with database count queries.
- Expose the current tab, selected filters, tab URLs, and unfiltered-family presence needed by the view.

**NOT in scope:**

- Pagination, cookie/session persistence, or new database indexes.

**Build order:**

1. **Test:** Add list request assertions for default Active, each status, combined filters, invalid values, counts, and query-count behavior in `test/integration/courses_index_test.rb`.
2. **Implement:** Update `app/controllers/courses_controller.rb`; use the Course scopes created in Task 1.
3. **Verify:** `bin/rails test test/integration/courses_index_test.rb`.

### Task 5 [subagent]: Render the filter toolbar, tabs, and empty states

**Skills:** style-ui, write-tests
**Reference:** Read `app/views/learners/index.html.erb`, `app/components/select_component.rb`, `app/components/ui_tabs_component.rb`, and `docs/COMPONENT_CATALOG.md`.
**Prototype:** None — retain the established Cove list hierarchy.
**Primary tasks:** 1. Find a class and open it. 3. Add a class. 4. Look back at past classes.

**In scope:**

- Add GET filter controls using `SelectComponent`, preserving status with a hidden field.
- Add accessible link-mode underline tabs for Active, Completed, and Archived, preserving learner/subject filters and showing filtered counts.
- Render the specified no-match and per-tab empty states, while retaining the COV-110 large empty state only for families with no classes.
- Add approved UI copy and test the rendered markup/state combinations.

**NOT in scope:**

- New components, Stimulus controllers, or visual redesign of the existing header/card grid.

**Build order:**

1. **Test:** Extend `test/integration/courses_index_test.rb` for toolbar visibility, filter values, URLs, tab counts, empty states, and clear-filter links.
2. **Implement:** Update `app/views/courses/index.html.erb` and `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/courses_index_test.rb`.
4. **Checkpoint:** After Tasks 4–6 are complete, run `review-changes-mini` once for Checkpoint 2. If work was parallelized, the master runs it after all three tasks return.

### Task 6 [subagent]: Add class-card status dates and action menus

**Skills:** style-ui, write-tests
**Reference:** Read `app/views/learners/_learner_card.html.erb`, `app/views/courses/_course_card.html.erb`, `app/helpers/application_helper.rb`, and `app/components/dropdown_component.rb`.
**Prototype:** None — match the existing learner-card action-menu pattern.
**Primary tasks:** 1. Find a class and open it. 2. Mark a class complete. 4. Look back at past classes.

**In scope:**

- Add the status-date line using `friendly_date`.
- Add the portaled, accessible “…” menu with status-specific actions and hidden external forms using HTML `form` attributes.
- Keep the menu above the stretched card click target and route deletion through the existing lazy confirmation modal.
- Add card/menu rendering and end-to-end action coverage for every status.

**NOT in scope:**

- Muting or badging completed/archived cards, or changing the existing delete confirmation copy.

**Build order:**

1. **Test:** Add rendering assertions in `test/integration/courses_index_test.rb` and action-menu coverage in `test/system/courses_system_test.rb`.
2. **Implement:** Update `app/views/courses/_course_card.html.erb` and `config/locales/en.yml`.
3. **Verify:** Run `bin/rails test test/integration/courses_index_test.rb`, then `bin/rails test test/system/courses_system_test.rb`.

### Task 7 [Master]: Add editable modal status controls and unsaved-change guard

**Skills:** style-ui, write-tests
**Reference:** Read `app/views/courses/_form.html.erb`, `app/views/courses/_actions.html.erb`, `app/javascript/controllers/ui_modal_unsaved_changes_controller.js`, and `app/views/learners/_actions.html.erb`.
**Prototype:** None — preserve the existing modal layout and footer.
**Primary tasks:** 1. Correct name, subject, or learners. 2. Change status. 3. Delete.

**In scope:**

- Add the status row and status-specific, non-nested forms to the edit modal only.
- Keep completed and archived classes normally editable; saving must not alter their timestamps.
- Extend the existing unsaved-changes controller only as necessary so a status submit prompts to discard edits before leaving the modal.
- Test status text, action availability, dirty-form confirmation, successful transitions, and unchanged add-modal behavior.

**NOT in scope:**

- Confirmation for reversible status changes, a new modal, or changes to the form’s learner rules.

**Build order:**

1. **Test:** Extend `test/integration/course_forms_test.rb` and `test/system/courses_system_test.rb` for status controls and the unsaved-edits flow.
2. **Implement:** Update `app/views/courses/_form.html.erb` and, only if required by the failing browser test, `app/javascript/controllers/ui_modal_unsaved_changes_controller.js`.
3. **Verify:** Run `bin/rails test test/integration/course_forms_test.rb`, then `bin/rails test test/system/courses_system_test.rb`.
4. **Checkpoint:** After Tasks 7–8 are complete, run `review-changes-mini` once for Checkpoint 3. If work was parallelized, the master runs it after both tasks return.

### Task 8 [Master]: Update product behavior documentation

**Skills:** documentation
**Reference:** Read the Classes section of `docs/product/product-brief.md` and the approved design’s Docs section.

**In scope:**

- Document the Active, Completed, and Archived rules; allowed transitions; edit/delete behavior; and list filtering.
- Keep terminology aligned with the Cove glossary.

**NOT in scope:**

- Architecture diagrams, component catalog changes, or AGENTS.md changes.

**Build order:**

1. **Test:** Re-read the documented rules against the approved design’s acceptance criteria.
2. **Implement:** Update `docs/product/product-brief.md`.
3. **Verify:** `git diff --check`.

### Task 9 [Master]: Run final feature and quality verification

**Skills:** review-changes-mini
**Reference:** Read the complete `origin/main...HEAD` diff and the approved design acceptance criteria.

**In scope:**

- Verify migration reversibility, focused model/integration/system coverage, full Rails suite, RuboCop, and whitespace.
- Perform the requested browser/system validation for modal controls, filters, and menu actions.
- Inspect the final diff for scope and copy compliance, including absence of “Done” in class-status UI.

**NOT in scope:**

- Implementing new behavior discovered outside the approved scope.

**Build order:**

1. **Test:** Run focused course tests, then `bin/rails test`, `bin/rubocop`, and `git diff --check`.
2. **Implement:** Address only directly evidenced failures within this approved plan.
3. **Verify:** Inspect `git diff origin/main...HEAD`.
4. **Checkpoint:** Run `review-changes-mini` once for Checkpoint 4 after all final gates pass.

## Task Dependencies

- Task 2 depends on Task 1’s Course transitions and constraint.
- Task 3 depends on Task 2’s routes and target status behavior.
- Task 4 depends on Task 1’s scopes and filter methods.
- Task 5 depends on Task 4’s view state and can proceed independently of Tasks 6–7.
- Task 6 depends on Tasks 1–3 and can run in parallel with Task 5.
- Task 7 depends on Tasks 1–3 and can run in parallel with Task 6 once the shared card markup is settled.
- Task 8 can run after the behavioral work is complete.
- Task 9 depends on every prior task.
