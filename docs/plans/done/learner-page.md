> Ticket: COV-121
> Branch: feature/cov-121-learner-page

# Plan: Learner page

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 — Fixed grades | 1 | Prepare canonical fixtures, seeds, and assertions | Master | ✅ |
| 2 | 1 | 1 | Convert existing grade values | Master | ✅ |
| 3 | 1 | 2 | Replace grade text fields with the fixed select | Master | ✅ |
| 4 | 1 | 2 | Update browser coverage for grade selection | Master | ✅ |
| 5 | 1 | 3 | Enforce canonical grades in Rails | Master | ✅ |
| 6 | 1 | 3 | Enforce canonical grades in PostgreSQL | Master | ✅ |
| 7 | 2 — Learner pages | 4 | Support a switcher beside the shared page title | Master | ✅ |
| 8 | 2 | 5 | Add the family-scoped learner page | Master | ✅ |
| 9 | 2 | 5 | Add switching, Edit, and archived state | Master | ✅ |
| 10 | 2 | 5 | Show current classes and the filtered Classes link | Master | ✅ |
| 11 | 2 | 6 | Preserve page-aware action destinations | Master | ✅ |
| 12 | 2 | 6 | Verify learner-page browser flows and phone layout | Master | ✅ |
| 13 | 2 | 7 | Make active and archived cards open learner pages | Master | ✅ |
| 14 | 3 — Confirmations and completion | 8 | Preserve unsaved learner details through Delete → Cancel | Master | ✅ |
| 15 | 3 | 8 | Apply confirmation recovery to class editing | Master | ✅ |
| 16 | 3 | 9 | Explain learner deletion and count every class link | Master | ✅ |
| 17 | 3 | 10 | Explain class deletion and count every learner link | subagent | ✅ |
| 18 | 3 | 10 | Update the product and UX rules | subagent | ✅ |
| 19 | 3 | 11 | Complete regression and visual verification | Master | ✅ |

## Prerequisites

- **Design:** `docs/designs/learner-page.md`. The existing untracked copy in this workspace matches the supplied design.
- **Prototype:** None. Follow the approved screen descriptions and existing product layout.
- The current branch is already `feature/cov-121-learner-page`; keep it.
- Reuse the catalog's `PageHeaderComponent`, `DropdownComponent`, `UiModalComponent`, `SelectComponent`, `ButtonComponent`, `AlertComponent`, `EmptyStateComponent`, and existing learner color partials. No new base component is required.
- Each task changes at most four files. Complete each checkpoint before proceeding; keep Rails test processes sequential, including during delegated work.
- Before Rails commands, prepend `/Users/jordan/.local/share/mise/shims` to `PATH` and confirm Ruby **4.0.5**.
- Generate migrations with Rails. Keep conversion and constraint migrations separate, with conversion first.
- The conversion is intentionally lossy. Its documented `down` leaves canonical values intact; rolling back the constraint does not recover original free text. Retain no backup learner data.
- Each phase ends with a working, independently deployable increment. This plan does not authorize deployment.
- After approval, save this plan as `docs/plans/learner-page.md`, annotate the local design, and commit both documents. Implementation begins only when `/execute-plan` is invoked.

## Tasks

### Task 1 [Master]: Prepare canonical fixtures, seeds, and assertions

**Skills:** write-tests
**Reference:** `test/fixtures/learners.yml`, `db/seeds.rb`, `test/models/learner_test.rb`, `test/integration/learners_index_test.rb`

**In scope:** Convert fixture and seed grades to full canonical labels; update affected model and card assertions without introducing validation yet.

**NOT in scope:** Converting existing database rows, changing form controls, or accepting legacy aliases permanently.

**Build order:**

1. **Test:** Update existing expectations to labels such as `3rd grade`; retain coverage for optional grades and whitespace normalization.
2. **Implement:** Update the four referenced files. Preserve fixture labels, relationships, and unrelated seed behavior.
3. **Verify:** `bin/rails test test/models/learner_test.rb test/integration/learners_index_test.rb`

### Task 2 [Master]: Convert existing grade values

**Skills:** safe-migration, write-tests
**Reference:** The design's Existing-grade mapping; `test/migrations/remove_kept_on_free_from_learners_test.rb`

**In scope:** A generated `NormalizeLearnerGradeLevels` data migration, its migration test, and the resulting `db/schema.rb` version change.

**NOT in scope:** Schema constraints, runtime alias conversion, retained originals, or logging learner identities and grades.

**Build order:**

1. **Test:** Add `test/migrations/normalize_learner_grade_levels_test.rb`. Cover every canonical label, all specified aliases for grades 1–12, case and whitespace variations, blanks/NULL, unmatched values, and active/archived records.
2. **Implement:** Use a migration-local record class, frozen mapping, and writes that bypass current model validation. Silence SQL logging during conversion; preserve unrelated attributes. Document the lossy, no-op `down`.
3. **Verify:** Run migration → `db:rollback:primary` → migration, then `bin/rails test test/migrations/normalize_learner_grade_levels_test.rb`. Confirm repeat conversion preserves canonical results.

Run **review-changes-mini once for checkpoint 1, Tasks 1–2**, after both tasks finish. If executed as a parallel batch, the master runs the review after the whole batch returns.

### Task 3 [Master]: Replace grade text fields with the fixed select

**Skills:** style-ui, write-tests
**Reference:** `app/views/learners/_form.html.erb`, `app/views/courses/_form.html.erb`, `app/components/select_component.rb`
**Prototype:** None — approved Add/Edit learner modal
**Primary tasks:** 1. Save learner details. 2. Deliberately archive or delete an existing learner.

**In scope:** The learner form, `config/locales/en.yml`, `test/integration/learner_forms_test.rb`, and `test/integration/learners_test.rb`.

**NOT in scope:** Changing name/color behavior, permitting custom grades, or changing action destinations.

**Build order:**

1. **Test:** Assert both Add and Edit have the 14 canonical options followed by explicit “No grade level”; verify selected values and preservation after other validation errors. Update existing request submissions to canonical labels.
2. **Implement:** Render `SelectComponent` with stable ID `learner_grade_level`, blank value for No grade level, no placeholder/create/clear control, and `select_allow_empty_option_value: true`. Show field errors through the component.
3. **Verify:** `bin/rails test test/integration/learner_forms_test.rb test/integration/learners_test.rb`

### Task 4 [Master]: Update browser coverage for grade selection

**Skills:** style-ui, write-tests
**Reference:** `test/system/learners_system_test.rb`, existing TomSelect interactions in `test/system/courses_system_test.rb`
**Prototype:** None — approved Add/Edit learner modal
**Primary tasks:** 1. Save learner details. 2. Deliberately archive or delete an existing learner.

**In scope:** Existing learner system tests: replace grade text entry with actual select interactions and canonical assertions.

**NOT in scope:** Card navigation changes or changing the existing Delete-cancel behavior before Task 14.

**Build order:**

1. **Test:** Cover choosing a grade, returning to No grade level, saving NULL, and keeping the selected grade after validation failure.
2. **Implement:** Update only `test/system/learners_system_test.rb`; exercise the visible enhanced control inside the dialog.
3. **Verify:** `bin/rails test test/system/learners_system_test.rb`

Run **review-changes-mini once for checkpoint 2, Tasks 3–4**, after both tasks finish. If executed as a parallel batch, the master runs it after the whole batch returns.

### Task 5 [Master]: Enforce canonical grades in Rails

**Skills:** write-tests
**Reference:** `app/models/learner.rb`, `test/models/learner_test.rb`, `test/integration/learners_test.rb`

**In scope:** A frozen ordered canonical grade list and inclusion validation allowing NULL; model and request coverage.

**NOT in scope:** Accepting aliases on new submissions or changing learner-cap validation.

**Build order:**

1. **Test:** Accept every canonical label and blank/NULL; reject aliases, unknown labels, and oversized values. Test tampered create/update grades return 422 with an inline error and leave persisted data unchanged.
2. **Implement:** Add inclusion validation in `Learner`, retaining blank-to-NULL normalization. Update the former arbitrary-grade length test to the fixed-vocabulary behavior.
3. **Verify:** `bin/rails test test/models/learner_test.rb test/integration/learners_test.rb`

### Task 6 [Master]: Enforce canonical grades in PostgreSQL

**Skills:** safe-migration, write-tests
**Reference:** Task 2's migration/test; existing database assertions in `test/models/learner_test.rb`

**In scope:** A generated `EnforceLearnerGradeLevels` constraint migration, `db/schema.rb`, its migration test, and any required isolation adjustment to the conversion test.

**NOT in scope:** Changing the column type, adding a grade model, or combining data conversion with schema enforcement.

**Build order:**

1. **Test:** Add `test/migrations/enforce_learner_grade_levels_test.rb`; bypass Rails validation to prove every canonical value and NULL succeed while blank, aliases, and unknown values fail.
2. **Implement:** Add named check `learners_grade_level_is_canonical` using frozen labels in the migration. Conversion tests must temporarily remove this check when simulating legacy rows and restore it in `ensure`.
3. **Verify:** Run migration → `db:rollback:primary` → migration; run both new migration tests, then `bin/rails test`.

Inspect `db/schema.rb`. Restore only migration-generated noise in the three auxiliary schema dumps after confirming their baseline.

Run **review-changes-mini once for checkpoint 3, Tasks 5–6**, after both tasks finish. If executed as a parallel batch, the master runs it after the whole batch returns.

### Task 7 [Master]: Support a switcher beside the shared page title

**Skills:** style-ui, write-tests
**Reference:** `app/components/page_header_component.rb`, its template, test, and preview
**Prototype:** None — approved learner-page header
**Primary tasks:** 1. Review this learner's current classes. 2. Switch learners. 3. Edit details.

**In scope:** Add an optional title-adjacent slot to `PageHeaderComponent`; update its Ruby file, template, component test, and preview.

**NOT in scope:** A new header component, changing existing action rules, or placing interactive dropdown markup inside an `<h1>`.

**Build order:**

1. **Test:** Assert the suffix is adjacent to the heading, existing headers remain valid, and existing action limits still apply.
2. **Implement:** Keep one semantic heading; allow its text to wrap beside a nonshrinking switcher. Preserve existing desktop and phone action placement.
3. **Verify:** `bin/rails test test/components/page_header_component_test.rb`

Run **review-changes-mini once for checkpoint 4, Task 7**. If executed in a parallel batch, the master reviews once the whole batch returns.

### Task 8 [Master]: Add the family-scoped learner page

**Skills:** style-ui, write-tests
**Reference:** `app/controllers/learners_controller.rb`, `config/routes.rb`, `app/helpers/application_helper.rb`
**Prototype:** None — approved active and archived learner pages
**Primary tasks:** Review one learner's identity and return to Learners.

**In scope:** Enable `show`, extend the existing family-scoped lookup, add `app/views/learners/show.html.erb`, and update `test/integration/learners_test.rb`.

**NOT in scope:** Premium gating, another authorization system, or changing archived edit/update protection.

**Build order:**

1. **Test:** Replace the obsolete assertion that `/learners/:id` is missing. Cover active/archived access, guests, missing/other-family IDs, both parents, Free access, and Learners sidebar selection.
2. **Implement:** Render the shared header with existing color/name partials, optional grade, and “← Learners.” Reuse existing translation keys for this initial shell.
3. **Verify:** `bin/rails test test/integration/learners_test.rb`

### Task 9 [Master]: Add switching, Edit, and archived state

**Skills:** style-ui, write-tests
**Reference:** The shared header and dropdown components; `app/views/learners/index.html.erb` for capacity messaging
**Prototype:** None — approved active and archived learner pages
**Primary tasks:** 1. Review this learner's current classes. 2. Switch learners. 3. Edit details. Archived: 1. View the retained learner identity and archive state. 2. Restore the learner or switch to an active learner.

**In scope:** Learner controller/show view, `config/locales/en.yml`, and new `test/integration/learner_page_test.rb`.

**NOT in scope:** Archived destinations, a header action menu, or editing archived learners.

**Build order:**

1. **Test:** Assert destination order, exclusion of current/archived/other-family learners, hidden empty switcher, outlined Edit, and archived view-only state with allowed/blocked Restore.
2. **Implement:** Populate active destinations through the family's `active.ordered` scope. Use the title-adjacent dropdown; put outlined Edit in the always-visible action slot. Add the exact archive notice and capacity explanation with the existing support email path. Add page copy, including Task 10's classes copy.
3. **Verify:** `bin/rails test test/integration/learner_page_test.rb test/integration/learners_test.rb`

### Task 10 [Master]: Show current classes and the filtered Classes link

**Skills:** style-ui, write-tests
**Reference:** `Course.active`, `Course.ordered`, learner associations, `test/integration/courses_index_test.rb`
**Prototype:** None — approved Current classes and activities section
**Primary tasks:** 1. Review this learner's current classes. 2. Switch learners. 3. Edit details.

**In scope:** Learner controller/show view and `test/integration/learner_page_test.rb`.

**NOT in scope:** Add class, class-row navigation, pagination/search, or future sections.

**Build order:**

1. **Test:** Cover enrollment filtering, active-only status, existing subject/name ordering, omitted blank subjects, more than 12 rows, exact empty copy, filtered Classes URL, and complete absence of the section for archived learners.
2. **Implement:** Read `@learner.courses.active.ordered`; render noninteractive divided rows with phone stacking. Render “See all in Classes” in both active states using `courses_path(learner: @learner.id)`.
3. **Verify:** `bin/rails test test/integration/learner_page_test.rb test/integration/courses_index_test.rb`

Run **review-changes-mini once for checkpoint 5, Tasks 8–10**, after all three tasks finish. If executed as a parallel batch, the master runs it after the whole batch returns.

### Task 11 [Master]: Preserve page-aware action destinations

**Skills:** write-tests
**Reference:** `app/controllers/concerns/course_list_return.rb`, learner controller and archive controller

**In scope:** New `LearnerReturn` concern, both learner controllers, and new `test/integration/learner_page_actions_test.rb`.

**NOT in scope:** Arbitrary return URLs, changing class return behavior, or changing Add/Delete destinations.

**Build order:**

1. **Test:** Cover Save, Archive, Restore, refused Restore, validation failure/retry, both parents, and list-origin actions. Verify Add/Delete always return to Learners; malformed, external, and different-record referrers fall back safely.
2. **Implement:** Recognize only a same-origin referrer whose path exactly matches the scoped learner's page. Generate the destination locally. Reuse this for Save/Archive/Restore and archived edit/update rejection.
3. **Verify:** `bin/rails test test/integration/learner_page_actions_test.rb test/integration/learner_archives_test.rb test/integration/learners_test.rb`

### Task 12 [Master]: Verify learner-page browser flows and phone layout

**Skills:** style-ui, write-tests
**Reference:** `test/application_system_test_case.rb`, `test/system/learners_system_test.rb`
**Prototype:** None — approved learner-page and modal flows
**Primary tasks:** Review current classes, switch learners, edit details, and restore archived learners.

**In scope:** New `test/system/learner_page_system_test.rb`.

**NOT in scope:** Broad shared-modal changes or unrelated browser-test repairs.

**Build order:**

1. **Test:** Cover Edit → Save/Archive, archived → Restore, capacity refusal, validation recovery, Cancel/discard, switching, and the filtered Classes destination.
2. **Implement:** Add desktop and phone cases with long names, wrapping Edit, stacked class rows, keyboard access, and no horizontal overflow. Use `wait_for_turbo_navigation` around redirecting submissions.
3. **Verify:** `bin/rails test test/system/learner_page_system_test.rb`

Run **review-changes-mini once for checkpoint 6, Tasks 11–12**, after both tasks finish. If executed as a parallel batch, the master runs it after the whole batch returns.

### Task 13 [Master]: Make active and archived cards open learner pages

**Skills:** style-ui, write-tests
**Reference:** `app/views/learners/_learner_card.html.erb`, existing stretched-link and portaled-menu behavior
**Prototype:** None — approved Learners list
**Primary tasks:** 1. Open a learner. 2. Add or manage learners.

**In scope:** The learner card partial, `test/integration/learners_index_test.rb`, and `test/system/learners_system_test.rb`.

**NOT in scope:** Changing the card layout, Add triggers, or status-appropriate menu actions.

**Build order:**

1. **Test:** Assert active/archived card navigation and that menu Edit/Archive/Restore/Delete never activate the card link. Update old card-opens-Edit expectations and editing helpers.
2. **Implement:** Use real stretched navigation links for both identities; retain the independent Edit modal trigger/hidden form and the menu's elevated click target.
3. **Verify:** `bin/rails test test/integration/learners_index_test.rb`, then `bin/rails test test/system/learners_system_test.rb`, then `bin/rails test`.

Run **review-changes-mini once for checkpoint 7, Task 13**. If executed in a parallel batch, the master reviews once the whole batch returns.

### Task 14 [Master]: Preserve unsaved learner details through Delete → Cancel

**Skills:** style-ui, write-tests
**Reference:** `app/javascript/controllers/ui_modal_unsaved_changes_controller.js`, `app/components/ui_modal_component.html.erb`
**Prototype:** None — approved delete confirmation flow
**Primary tasks:** 1. Understand what permanent deletion removes. 2. Confirm deletion or keep the record.

**In scope:** The shared unsaved-changes controller, modal template, learner actions partial, and existing learner system tests.

**NOT in scope:** Nested dialogs, persisting drafts, sending unsaved data in URLs, or changing ordinary modal callers.

**Build order:**

1. **Test:** Replace the existing saved-form recovery expectation: change name, grade, and color; open Delete; Cancel; assert all unsaved values and dirty state remain in the same dialog.
2. **Implement:** Opt Delete links into an in-memory form-state capture. Use Turbo frame-render hooks to restore editable controls before enhanced controls reconnect. Preserve dirty state; clear captured data on close, successful completion, or disconnect. Exclude authentication/method fields.
3. **Verify:** `bin/rails test test/system/learners_system_test.rb test/components/ui_modal_component_test.rb`

Run the two test files sequentially.

### Task 15 [Master]: Apply confirmation recovery to class editing

**Skills:** style-ui, write-tests
**Reference:** Task 14's controller hooks; `app/views/courses/_actions.html.erb`
**Prototype:** None — approved class delete confirmation
**Primary tasks:** 1. Understand what permanent deletion removes. 2. Confirm deletion or keep the record.

**In scope:** Class actions partial and `test/system/courses_system_test.rb`.

**NOT in scope:** Changing class status transitions or submitting unsaved details while opening a confirmation.

**Build order:**

1. **Test:** Change name, custom subject, selected learners, and an allowed status; Delete → Cancel must restore every value and still ask before discarding.
2. **Implement:** Opt the class Delete link into the shared capture. Cover a newly typed subject absent from the fetched form's options, repeated confirmation cycles, and direct-card Cancel closing immediately.
3. **Verify:** `bin/rails test test/system/courses_system_test.rb`

Run **review-changes-mini once for checkpoint 8, Tasks 14–15**, after both tasks finish. If executed as a parallel batch, the master runs it after the whole batch returns.

### Task 16 [Master]: Explain learner deletion and count every class link

**Skills:** style-ui, write-tests
**Reference:** `app/views/learners/_delete_content.html.erb`, `Learner#enrollments`, existing delete request tests
**Prototype:** None — approved learner delete confirmation
**Primary tasks:** 1. Understand what permanent deletion removes. 2. Confirm deletion or keep the record.

**In scope:** Learner confirmation partial, `config/locales/en.yml`, and `test/integration/learners_test.rb`. Prepare the class confirmation translations needed by Task 17 in the same locale edit.

**NOT in scope:** Export, future record counts, or removing class records.

**Build order:**

1. **Test:** Cover zero/one/multiple links across active/completed/archived classes; active/archived wording; named destructive label; both parents; deletion removing links while preserving every class.
2. **Implement:** Count persisted enrollments when rendering the confirmation. Say classes remain, omit zero-count copy, retain permanence warning, and suggest archiving or keeping the learner archived. Preserve direct-card versus Edit cancellation.
3. **Verify:** `bin/rails test test/integration/learners_test.rb test/models/learner_test.rb`

Run **review-changes-mini once for checkpoint 9, Task 16**. If executed in a parallel batch, the master reviews once the whole batch returns.

### Task 17 [subagent]: Explain class deletion and count every learner link

**Skills:** style-ui, write-tests
**Reference:** `app/views/courses/delete.html.erb`, `test/integration/course_forms_test.rb`, Task 16's translations
**Prototype:** None — approved class delete confirmation
**Primary tasks:** 1. Understand what permanent deletion removes. 2. Confirm deletion or keep the record.

**In scope:** Class delete template and `test/integration/course_forms_test.rb`.

**NOT in scope:** Class transition changes, a Completed-to-Archived action, or changing Classes tab/filter returns.

**Build order:**

1. **Test:** Cover zero/one/multiple learners including archived learners, named confirmation labels, every class status, retained learner records, and unchanged filtered return behavior.
2. **Implement:** Count all enrollments; explain link removal and permanence. Suggest archiving, or keeping an archived class archived, without introducing a transition action.
3. **Verify:** Master runs `bin/rails test test/integration/course_forms_test.rb test/integration/courses_test.rb` after the delegated batch returns.

### Task 18 [subagent]: Update the product and UX rules

**Skills:** None
**Reference:** Approved design; `docs/product/product-brief.md`, `docs/product/ux-notes.md`

**In scope:** Those two product documents only.

**NOT in scope:** Ticket-specific implementation details, architecture/catalog regeneration, or documenting deferred features as built.

**Build order:**

1. **Test:** Check the proposed wording against the design and implemented behavior; no new automated test is needed for documentation.
2. **Implement:** Document learner record pages, archived view-only behavior, optional fixed grades, action destinations, Classes owning creation, and retained links versus historical records. Add the exception allowing all current-class summary rows without search, pagination, or an inline Add action.
3. **Verify:** Master reviews the document diff and runs `git diff --check`.

The master runs **review-changes-mini once for checkpoint 10, Tasks 17–18**, after both delegated tasks return and their verification finishes.

### Task 19 [Master]: Complete regression and visual verification

**Skills:** style-ui, write-tests
**Reference:** `.github/workflows/ci.yml`, all changed tests, approved acceptance criteria
**Prototype:** None — all approved screens
**Primary tasks:** Open/manage learners, review classes, switch learners, edit/restore, and deliberately confirm deletion.

**In scope:** Final verification and screenshots under `.context/`; route any necessary fix back through its owning task and tests.

**NOT in scope:** Extra features, committing implementation here, opening a PR, merging, or running the next workflow command.

**Build order:**

1. **Test:** Audit coverage against every acceptance criterion, including archived-link retention through class edits and restoration.
2. **Implement:** Inspect desktop and phone screenshots for populated/empty/archived pages, long-name switcher, grade dropdown, Edit actions, and both confirmations. Inspect the saved images before accepting them.
3. **Verify:** Run the following sequentially, capture actual output, and inspect `git diff origin/main...HEAD` plus `git diff`:

   ```bash
   bin/rails db:migrate:status
   bin/rails test
   PARALLEL_WORKERS=4 bin/rails test:system
   bin/rubocop
   bin/erb_lint --lint-all
   git diff --check
   git diff --cached --check
   ```

Run **review-changes-mini once for checkpoint 11, Task 19**. If executed in a parallel batch, the master reviews once the whole batch returns.

## Task Dependencies

- Task 1 → Task 2.
- Tasks 3–4 form the coordinated form/control update; complete both before checkpoint 2.
- Task 5 depends on canonical callers from Tasks 1–4. Task 6 follows both conversion and Rails validation.
- Task 7 precedes Tasks 8–10; those three build the page incrementally.
- Task 11 depends on the page route. Task 12 verifies the completed page/action integration.
- Task 13 follows Task 12 so card navigation exposes the completed page.
- Task 14 follows the fixed grade select and page flows. Task 15 reuses its confirmation-state handling.
- Task 16 follows Task 15. Tasks **17 and 18 can run in parallel** afterward because their files do not overlap.
- Delegated agents do not commit. The master runs Rails tests sequentially and reviews the integrated batch.
- Task 19 follows all implementation and documentation tasks.
- After execution, the next user-invoked command is `/review-changes`.
