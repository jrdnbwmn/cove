> Ticket: COV-122
> Branch: feature/cov-122-classes-list-as-rows

# Plan: Classes list as rows

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add literal name-and-subject search | Master | ✅ |
| 2 | 1 | 1 | Preserve search and page after modal actions | subagent | ✅ |
| 3 | 2 | 2 | Add the shared modal row trigger | Master | |
| 4 | 2 | 3 | Replace class cards with responsive rows | Master | |
| 5 | 2 | 3 | Connect the inline Add class row | Master | |
| 6 | 2 | 3 | Connect search, pagination, and empty states | Master | |
| 7 | 2 | 4 | Finish browser coverage, product docs, and validation | Master | |

## Prerequisites

- Design: `docs/designs/classes-list-as-rows.md`. The existing local copy matches the supplied design.
- Prototype: None. Follow the design's desktop columns and phone stacking.
- Feature branch already exists: `feature/cov-122-classes-list-as-rows`.
- Reuse the catalog's `FormFieldComponent`, `SelectComponent`, `UiTabsComponent`, `PaginationComponent`, `ButtonComponent`, `DropdownComponent`, `UiModalComponent`, and `EmptyStateComponent`. No new component is required.
- Reuse `.row-list`, `card_link_classes`, `course_status_date`, and `learners/name_with_dot`.
- Pagy detail resolved: version 43 defaults to an empty out-of-range page and discontinued `overflow: :last_page`. Clamp locally before calling Pagy, using the current tab's already-computed count. Leave the shared pagination concern unchanged. [Pagy upgrade guide](https://github.com/ddnexus/pagy/blob/43.3.0/docs/guides/upgrade-guide.md)
- Use existing fixtures and explicitly created test records; no factories or new gems.
- Before Rails commands, prepend `/Users/jordan/.local/share/mise/shims` to `PATH` and confirm Ruby 4.0.5. Keep Rails test processes sequential.
- Phase 1 delivers independently deployable search and return-path support. Phase 2 connects the complete user-facing change.

## Tasks

### Task 1 [Master]: Add literal name-and-subject search

**Skills:** write-tests
**Reference:** `app/models/course.rb`, `test/models/course_test.rb`

**In scope:**

- Add `Course.search(term)` using parameterized, case-insensitive matching against name **or** subject.
- Escape wildcard characters with `sanitize_sql_like`; keep the scope chainable with existing family, status, learner, and subject scopes.

**NOT in scope:**

- Learner-name search, indexes, migrations, controller normalization, or ordering changes.

**Build order:**

1. **Test:** Extend `test/models/course_test.rb` for name matches, subject matches, mixed case, substrings, literal `%` and `_`, unmatched terms, and composition with family/filter scopes.
2. **Implement:** Add the scope in `app/models/course.rb`; keep existing ordering.
3. **Verify:** `bin/rails test test/models/course_test.rb`.

### Task 2 [subagent]: Preserve search and page after modal actions

**Skills:** write-tests
**Reference:** `app/controllers/concerns/course_list_return.rb`, `test/integration/courses_test.rb`

**In scope:**

- Add `q` and `page` to `CourseListReturn::LIST_PARAMS`.
- Preserve the current same-origin, `/classes`-only return-path restriction.

**NOT in scope:**

- Page clamping, other return-path concerns, or changes to mutation controllers.

**Build order:**

1. **Test:** Extend `test/integration/courses_test.rb` so create, update, delete, Complete/Archive, and Reopen/Restore preserve search and page alongside existing filters. Update the test that currently expects `page` to be discarded; cover unrelated and structured query parameters being excluded.
2. **Implement:** Update `app/controllers/concerns/course_list_return.rb` and its explanatory comment.
3. **Verify:** `bin/rails test test/integration/courses_test.rb`.
4. **Review:** Run `review-changes-mini` for checkpoint 1, tasks 1–2. If executed as a parallel batch, the master runs this exactly once after both tasks return.

### Task 3 [Master]: Add the shared modal row trigger

**Skills:** write-tests, style-ui
**Reference:** `app/views/application/_modal_trigger_button.html.erb`, `app/views/application/_lazy_modal.html.erb`, `test/helpers/application_helper_test.rb`
**Prototype:** None; design's "+ Add class" row.
**Primary tasks:** 4. Add a class.

**In scope:**

- Add an optional `row: false` local to both shared partials.
- Render the row variant through `ButtonComponent`: borderless, muted, plus icon, and the existing modal-open action.
- Retain the existing default button and tile behavior.

**NOT in scope:**

- Changing `AddTileComponent`, modal internals, or other callers.

**Build order:**

1. **Test:** Add `test/views/modal_trigger_button_test.rb` using `ActionView::TestCase`; render the partials and assert row styling, accessible text, modal action, lazy source, and unchanged default/tile branches.
2. **Implement:** Update only the two shared partials. Ensure the row variant does not inherit the tile's full-height wrapper.
3. **Verify:** `bin/rails test test/views/modal_trigger_button_test.rb test/components/add_tile_component_test.rb test/components/ui_modal_component_test.rb`.
4. **Review:** Master runs `review-changes-mini` exactly once for checkpoint 2, task 3.

### Task 4 [Master]: Replace cards with responsive rows

**Skills:** write-tests, style-ui
**Reference:** `app/views/courses/_course_card.html.erb`, `app/views/billing/_charges.html.erb`, `app/assets/tailwind/components/cards.css`, `test/integration/courses_index_test.rb`
**Prototype:** None; design's desktop and phone row layouts.
**Primary tasks:** 1. Find a class and see who takes it and its subject at a glance. 2. Open a class to edit it. 3. Change its status from the "…" menu.

**In scope:**

- Replace `_course_card.html.erb` with `_course_row.html.erb`; render rows inside one `.row-list` in `courses/index.html.erb`.
- Desktop: wrapping name, aligned subject and learner columns, status date on Completed/Archived, and menu. Keep the subject column's space when blank.
- Phone: name, subject, learners, date stacked; menu top-right.
- Preserve stretched Edit button behavior, portaled menu, hidden status forms, Delete confirmation, active-learner lookup, and existing copy.

**NOT in scope:**

- New components, shared CSS changes, progress text, class detail pages, or status behavior changes.

**Build order:**

1. **Test:** Update `test/integration/courses_index_test.rb` for row structure, subjects, visible learners, "No learners," dates, Edit source, menu actions, and existing empty states. Preserve stable `data-course` and content selectors.
2. **Implement:** Add the row partial, remove the card partial, and replace the index grid. Preserve the existing inline add trigger until task 5 connects its row variant.
3. **Verify:** `bin/rails test test/integration/courses_index_test.rb`.

### Task 5 [Master]: Connect the inline Add class row

**Skills:** write-tests, style-ui
**Reference:** `app/views/courses/_add_trigger.html.erb`, `app/views/courses/index.html.erb`, `test/system/courses_system_test.rb`
**Prototype:** None; design's muted add row below the list box.
**Primary tasks:** 2. Open a class to edit it. 4. Add a class.

**In scope:**

- Pass `row` through `courses/_add_trigger.html.erb`.
- Replace the inline tile with the row variant beneath the bordered list.
- Update card/tile-specific integration and system assertions, including replacing the obsolete card-bottom alignment test with responsive row coverage.

**NOT in scope:**

- Header/empty-state add changes or pagination calculations.

**Build order:**

1. **Test:** Update `test/integration/courses_index_test.rb` and `test/system/courses_system_test.rb` for Active-only placement, absence on empty/Completed/Archived views, equivalent Add modal behavior, whole-row Edit clicks, desktop column alignment, and phone stacking.
2. **Implement:** Update `_add_trigger.html.erb` and `index.html.erb`; preserve filter return behavior. Task 6 adds the last-page condition.
3. **Verify:** Run `bin/rails test test/integration/courses_index_test.rb`, then `bin/rails test test/system/courses_system_test.rb`, sequentially.

### Task 6 [Master]: Connect search, pagination, and empty states

**Skills:** write-tests, style-ui
**Reference:** `app/controllers/courses_controller.rb`, `lib/jumpstart/app/controllers/billing_controller.rb`, `app/components/pagination_component.rb`, `app/views/courses/index.html.erb`
**Prototype:** None; design's toolbar, pagination, and no-result states.
**Primary tasks:** 5. Narrow the list by tab, learner, subject, or search.

**In scope:**

- Update four files: `app/controllers/courses_controller.rb`, `app/views/courses/index.html.erb`, `config/locales/en.yml`, and `test/integration/courses_index_test.rb`.
- Normalize string `q`: trim, truncate to 100 characters, treat blank as absent; ignore arrays/hashes. Remove blank search from the URL.
- Compute search visibility from the current tab plus learner/subject filters **before** search; show it above 12 classes or whenever search is active.
- Apply search before calculating all tab counts. Paginate the selected tab at 12, retaining ordered enrollment preloading.
- Normalize invalid page input to 1; clamp past-end pages to `max(1, ceil(count / 12))`, passing the known count and clamped page to Pagy.
- Add the Enter-submitted search field first in the existing GET form. Tab links retain `q`; tabs and form submissions omit `page`.
- Render pagination only above one page, preserve list state in its links, and show the inline add row only on the final Active page with results.
- Add the exact search/no-match/Clear all translations from the design. Preserve other empty states.

**NOT in scope:**

- New JavaScript, live search, global pagination changes, sorting changes, or additional filters.

**Build order:**

1. **Test:** Extend index integration coverage for 12/13 boundaries, pre-search visibility, combined filters/search/counts, malformed/blank/long `q`, escaped echoed input, foreign-family exclusion, invalid and overflowing pages, empty collections, pagination URLs, page reset, and final-page add visibility. Retain query-growth coverage.
2. **Implement:** Follow the scope above. Keep query preparation in private controller methods. Canonicalizing blank search must preserve valid tab, filters, and page.
3. **Verify:** `bin/rails test test/models/course_test.rb test/integration/courses_index_test.rb test/integration/courses_test.rb test/integration/course_forms_test.rb`.
4. **Review:** Master runs `review-changes-mini` exactly once for checkpoint 3, tasks 4–6, after all three finish.

### Task 7 [Master]: Complete browser coverage, docs, and validation

**Skills:** write-tests, style-ui
**Reference:** `test/system/courses_system_test.rb`, `test/application_system_test_case.rb`, `docs/product/product-brief.md`, `docs/product/ux-notes.md`
**Prototype:** None; verify the approved desktop and phone layouts.
**Primary tasks:** 1. Find a class and see who takes it and its subject at a glance. 2. Open a class to edit it. 3. Change its status from the "…" menu. 4. Add a class. 5. Narrow the list by tab, learner, subject, or search.

**In scope:**

- Add browser coverage for Enter search, clearing search, pagination, tab/filter page resets, and modal actions preserving search/page.
- Cover removing the final item on page 2 and returning to the remaining last page; cover reaching zero results.
- Add the design's exact product-brief sentence and update counts to include search.
- Verify desktop and phone behavior, including long names, blank subjects, wrapped learners, menus, and keyboard access.

**NOT in scope:**

- Unrelated documentation cleanup, catalog changes, deployment, or PR creation.

**Build order:**

1. **Test:** Extend `test/system/courses_system_test.rb` with the remaining navigation and modal-return flows. Use `wait_for_turbo_navigation` for submissions/navigation before inspecting replacement content.
2. **Implement:** Update `docs/product/product-brief.md`; make any corrective code change in its owning task and rerun the affected checks.
3. **Verify:** Build Tailwind, run `bin/rails test`, then `PARALLEL_WORKERS=4 bin/rails test test/system/courses_system_test.rb`, then `bin/rubocop` and `git diff --check`. Keep Rails runs sequential and report their output.
4. **Visual verification:** Save and inspect desktop and phone screenshots under `.context/`; include paginated, searched, and Completed/Archived examples.
5. **Review:** Inspect `git diff`, then run `review-changes-mini` exactly once for checkpoint 4, task 7. The separately invoked `/execute-plan` workflow handles its required final review.

## Task Dependencies

- Tasks 1–2 are independent and can be implemented in parallel; run their Rails checks sequentially.
- Task 3 can follow checkpoint 1; it does not depend on search behavior.
- Task 4 establishes the row markup used by task 5.
- Task 5 depends on tasks 3–4.
- Task 6 depends on tasks 1, 4, and 5; task 2 enables its modal-return behavior.
- Task 7 follows all implementation tasks.
- Check each task's diff and focused tests before moving on; each task changes at most four files.
