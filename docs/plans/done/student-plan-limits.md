> Ticket: COV-105
> Branch: feature/cov-105-student-plan-limits

# Plan: Students — plan limits

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add and test the family capacity rule | Master | ✅ |
| 2 | 1 | 1 | Enforce capacity when a student becomes active | Master | ✅ |
| 3 | 1 | 1 | Handle direct create and restore refusals | Master | ✅ |
| 4 | 1 | 2 | Show the plan-specific prompt on the students page | subagent | ✅ |
| 5 | 1 | 2 | Explain and disable restoration at capacity | subagent | ✅ |
| 6 | 1 | 2 | Verify browser flows and existing student behavior | subagent | ✅ |

## Prerequisites

- Design: `docs/designs/student-plan-limits.md`
- Prototype: None
- Feature branch exists: `feature/cov-105-student-plan-limits`
- Use mise's Ruby 4.0.5 for Rails commands. Run Rails tests sequentially in this worktree.

## Tasks

### Task 1 [Master]: Add the family capacity rule

**Skills:** write-tests
**Reference:** Read `app/models/account.rb` and `test/models/account_test.rb` for existing entitlement and limit behavior.

**In scope:**

- Add `Account#can_add_student?` using a fresh `students.active.count < students_allowed` query.
- Test Free, paid Premium, Complimentary Premium, a raised Premium limit, and an archived student that does not consume a slot. Include a loaded-association case to prove the answer stays current.

**NOT in scope:**

- Student validation, UI, billing changes, or a new limit setting.

**Build order:**

1. **Test:** Add behavior tests in `test/models/account_test.rb`; confirm the new tests fail.
2. **Implement:** Add the method in `app/models/account.rb`.
3. **Verify:** `bin/rails test test/models/account_test.rb`

### Task 2 [Master]: Enforce capacity when a student becomes active

**Skills:** write-tests
**Reference:** Read `app/models/student.rb`, `test/models/student_test.rb`, and the student error keys in `config/locales/en.yml`.

**In scope:**

- Validate active creation and archived-to-active restoration. Lock the family row before checking `can_add_student?`, with an `# AIDEV-NOTE:` explaining concurrent saves.
- Add the approved Free and Premium model-error copy, pluralized by limit; Complimentary Premium uses Premium copy.
- Test the second Free student succeeds, the third fails, restoration fails at capacity and succeeds after a slot opens, archived creation bypasses the limit, and edits and archiving still work while over capacity. Include a concurrent last-slot test using separate database connections.
- Move existing color and general student behavior tests that create many students to an eligible Premium family; keep limit tests on Free families.

**NOT in scope:**

- Controller responses, page prompts, downgrade read-only behavior, or a migration.

**Build order:**

1. **Test:** Add the new behavior cases in `test/models/student_test.rb`; confirm they fail.
2. **Implement:** Add the validation in `app/models/student.rb` and its error translations in `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/models/student_test.rb`

### Task 3 [Master]: Handle direct create and restore refusals

**Skills:** write-tests
**Reference:** Read `app/controllers/students_controller.rb`, `app/controllers/students/archives_controller.rb`, `test/integration/students_test.rb`, and `test/integration/student_archives_test.rb`.

**In scope:**

- Keep the existing create failure response: HTTP 422 with entered values and the model error.
- Rescue only a failed restore validation in `Students::ArchivesController#destroy`; redirect to `/students` with HTTP 303 and the model's error as the alert. Confirm the student remains archived.
- Add direct-request tests for both refusals and for editing and archiving while over capacity. Adjust older successful-create tests to open a slot first where needed.

**NOT in scope:**

- A `GET /students/new` guard, a second capacity rule in either controller, or changes to archive and delete semantics.

**Build order:**

1. **Test:** Add refusal and regression cases in the two integration test files; confirm new cases fail.
2. **Implement:** Make only the required controller change; retain the existing create response unless a test exposes a gap.
3. **Verify:** `bin/rails test test/integration/students_test.rb test/integration/student_archives_test.rb`
4. **Checkpoint 1:** Run `/review-changes-mini` once for Tasks 1–3 after all three finish. If any tasks ran in parallel, the master runs it after the whole group returns.

### Task 4 [subagent]: Show the plan-specific prompt on the students page

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/students/index.html.erb`, `app/views/students/_add_trigger.html.erb`, `app/views/pricing/show.html.erb`, and `test/integration/students_index_test.rb`. The component catalog's Quick Reference confirms `ButtonComponent` already provides the upgrade link.
**Prototype:** None

**In scope:**

- Show the Add trigger while capacity remains. At capacity, show the approved Free upgrade button or Premium/Complimentary "Contact us" link using the existing support email and pricing link patterns.
- Let the header wrap on phones. Keep the empty-state Add trigger.
- Test Free, Premium, Complimentary Premium, raised-limit, and under-limit rendering. Update the existing header Add test, whose Free fixture starts at capacity.

**NOT in scope:**

- New components, a new page, a slots-left indicator, or altered billing behavior.

**Build order:**

1. **Test:** Add assertions in `test/integration/students_index_test.rb`; confirm new cases fail.
2. **Implement:** Update `app/views/students/index.html.erb` and add `app/views/students/_limit_prompt.html.erb`, using the translations added in Task 2.
3. **Verify:** `bin/rails test test/integration/students_index_test.rb`

### Task 5 [subagent]: Explain and disable restoration at capacity

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/students/index.html.erb`, `app/views/students/_student_card.html.erb`, `app/views/students/_form.html.erb`, and their existing integration tests. The catalog confirms the existing `ButtonComponent`, `FormFieldComponent`, and `CardComponent` patterns.
**Prototype:** None

**In scope:**

- Show the approved archived-section note at capacity with the appropriate upgrade or support link.
- Pass `can_restore:` to archived cards; hide Restore at capacity while keeping Delete available.
- Render the model's base error in the add form, preserving entered values.
- Test those states in `test/integration/students_index_test.rb` and `test/integration/student_forms_test.rb`.

**NOT in scope:**

- A new restore flow, changes to deletion, or suppressing an already-open stale form.

**Build order:**

1. **Test:** Add archived-action and base-error assertions; confirm new cases fail.
2. **Implement:** Update the three student views named above.
3. **Verify:** `bin/rails test test/integration/students_index_test.rb test/integration/student_forms_test.rb`

### Task 6 [subagent]: Verify browser flows and existing student behavior

**Skills:** write-tests
**Reference:** Read `test/system/students_system_test.rb` and the current students modal flow.

**In scope:**

- Update older system tests that assume `company` has an open slot.
- Test the Free prompt at capacity, an archived card without Restore, and a stale Add modal: another save fills the final slot after the modal opens, then submission keeps the typed name and shows the model error.
- Verify an available slot still permits Add and Restore.

**NOT in scope:**

- New UI, Stripe or billing tests, or downgrade selection behavior.

**Build order:**

1. **Test:** Add and adjust cases in `test/system/students_system_test.rb`; confirm new cases fail.
2. **Implement:** Correct only behavior exposed by these tests within the approved scope.
3. **Verify:** Run `bin/rails test:system test/system/students_system_test.rb`, then `bin/rails test` sequentially. Run `git diff --check` and inspect `git diff`.
4. **Checkpoint 2:** Run `/review-changes-mini` once for Tasks 4–6 after all three finish. If tasks ran in parallel, the master runs it after the whole group returns.

## Task Dependencies

- Task 2 depends on Task 1's capacity rule.
- Task 3 depends on Task 2's validation and error message.
- Task 4 depends on Task 2's translations.
- Task 5 depends on Task 4 because both update `students/index.html.erb` and its integration test.
- Task 6 depends on Tasks 4–5.
- The master runs each checkpoint review once, after every task in that checkpoint is complete.
