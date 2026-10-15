> Ticket: COV-118
> Branch: chore/cov-118-add-new

# Plan: Inline add tile at the end of card lists

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Create the card-style `AddTileComponent` | Master | ✅ |
| 2 | 1 | 1 | Add Lookbook previews | subagent | ✅ |
| 3 | 1 | 1 | Allow a modal trigger wrapper to fill a grid cell | Master | ✅ |
| 4 | 2 | 2 | Add the tile to Active learners | Master | ✅ |
| 5 | 2 | 2 | Verify learner tile interactions in the browser | subagent | ✅ |
| 6 | 3 | 3 | Add the tile to Active classes | Master | ✅ |
| 7 | 3 | 3 | Replace the no-active-classes line with an empty state | Master | ✅ |
| 8 | 3 | 3 | Verify class interactions and document the list rule | subagent | ✅ |

## Prerequisites

- Design: `docs/designs/inline-add-tile.md`
- Prototype: None; use the design's Notion screenshot reference and Cove's existing card styles.
- Feature branch exists: `chore/cov-118-add-new`.
- Catalog scan: `ButtonComponent`, `CardComponent`, `EmptyStateComponent`, and `UiModalComponent` exist. `AddTileComponent` does not, so Task 1 uses `/create-component`. The catalog entry remains for `/close-out`, as the design specifies.
- Follow the project's fixture-only testing convention. Use the `write-tests` skill for behavior changes and `style-ui` for views and components.

## Tasks

### Task 1 [Master]: Create the card-style AddTileComponent

**Skills:** create-component, write-tests, style-ui
**Reference:** Read `app/components/button_component.rb`, `app/components/card_component.rb`, and `test/components/card_component_test.rb` for argument, radius, and test patterns.
**Prototype:** None — match the card treatment described in the design.
**Primary tasks:** Learners: open, add, switch to Archived. Classes: open, filter, add, switch status tab.

**In scope:**

- Run `/create-component` for `AddTileComponent`; keep it card-style only.
- Accept required `text:`, `data: {}`, and `classes: nil`. Render a full-height, full-width `<button type="button">` with a plus icon, wrapping label, dashed neutral border, card radius, hover treatment, and visible primary-color focus ring.
- Touch at most `app/components/add_tile_component.rb`, its `.html.erb`, and `test/components/add_tile_component_test.rb`.

**NOT in scope:**

- A row-style tile, modal wiring, list placement, or catalog update.

**Build order:**

1. **Test:** In `test/components/add_tile_component_test.rb`, assert the native button, label, plus icon, passed data attributes and classes, and focus/height styling.
2. **Implement:** Add the two component files using existing tokens and the catalog's `icon` helper.
3. **Verify:** `bin/rails test test/components/add_tile_component_test.rb`.

### Task 2 [subagent]: Add Lookbook previews

**Skills:** style-ui
**Reference:** Read `test/components/previews/card_component_preview.rb` and its preview templates.

**In scope:**

- Add `test/components/previews/add_tile_component_preview.rb` and a grid template under `test/components/previews/add_tile_component_preview/`.
- Show a default tile and a three-column grid with two `CardComponent` examples beside the tile, including a longer label to show wrapping and height matching.

**NOT in scope:**

- Component behavior, production page markup, or a row variant.

**Build order:**

1. **Test:** Use Task 1's component test as the behavior gate; this task adds presentation examples only.
2. **Implement:** Add the preview class and grid template.
3. **Verify:** Open both previews in Lookbook and confirm the grid example shows equal-height cells.

### Task 3 [Master]: Allow a modal trigger wrapper to fill a grid cell

**Skills:** write-tests, style-ui
**Reference:** Read `app/components/ui_modal_component.rb`, its `.html.erb`, and `test/components/ui_modal_component_test.rb`.

**In scope:**

- Add an optional wrapper class argument to `UiModalComponent` and apply it to its outer Stimulus-controller element. The default output stays unchanged.
- This lets inline triggers pass `h-full` so `AddTileComponent` can fill the grid cell.

**NOT in scope:**

- Dialog size or behavior, modal content, and page-specific triggers.

**Build order:**

1. **Test:** Extend `test/components/ui_modal_component_test.rb` to assert an optional wrapper class appears on the outer element and the trigger remains inside its Stimulus scope.
2. **Implement:** Update the component Ruby and template files.
3. **Verify:** `bin/rails test test/components/ui_modal_component_test.rb`.
4. **Checkpoint 1:** Once Tasks 1–3 are complete, Master runs `/review-changes-mini` once for the group. If Tasks 2 and 3 ran in parallel, review after both return.

## Phase 2: Learners

### Task 4 [Master]: Add the tile to Active learners

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/learners/index.html.erb`, `_add_trigger.html.erb`, `_limit_modal.html.erb`, and `test/integration/learners_index_test.rb`.
**Prototype:** None — preserve the current card grid and header.
**Primary tasks:** 1. Open a learner to edit 2. Add a learner 3. Switch to Archived

**In scope:**

- Give both learner trigger partials an optional tile mode. It renders `AddTileComponent` with `t("learners.index.add")`, the existing modal action, and a full-height wrapper; their default header/empty-state button remains unchanged.
- Append the appropriate trigger after the last card only in the nonempty Active grid. Use the existing `Current.account.can_add_learner?` branch for both header and tile.
- In the integration test, assert tile placement and absence on Archived and empty views, both under-limit and limit-modal wiring, and the unchanged header action. Scope existing page-level add-trigger assertions to the header or tile.

**NOT in scope:**

- Learner limits, form behavior, archived cards, or the empty-state design.

**Build order:**

1. **Test:** Add the described assertions to `test/integration/learners_index_test.rb`, including the downgraded family's limit modal.
2. **Implement:** Update only the three learner view files.
3. **Verify:** `bin/rails test test/integration/learners_index_test.rb`.

### Task 5 [subagent]: Verify learner tile interactions in the browser

**Skills:** write-tests
**Reference:** Read `test/system/learners_system_test.rb`; retain its existing modal and submit assertions.

**In scope:**

- Add system coverage for opening the add form from the inline tile, reaching the limit and seeing the tile switch to the limit modal after the redirect, and opening that limit modal from the tile.
- Scope existing page-level "Add learner" clicks to the header. Existing `click_button` calls inside `dialog[open]` already target the form and need no change.

**NOT in scope:**

- Production code or learner form tests, whose selectors are already form-specific.

**Build order:**

1. **Test:** Add the browser scenarios and scope the existing page-level clicks in `test/system/learners_system_test.rb`.
2. **Implement:** No production change is expected; if a scenario fails, return the evidence to Master for a scoped fix.
3. **Verify:** `bin/rails test test/system/learners_system_test.rb`.
4. **Checkpoint 2:** Master runs `/review-changes-mini` once for Tasks 4–5.

## Phase 3: Classes and list guidance

### Task 6 [Master]: Add the tile to Active classes

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/application/_lazy_modal.html.erb`, `app/views/courses/_add_trigger.html.erb`, `app/views/courses/index.html.erb`, and `test/integration/courses_index_test.rb`.
**Prototype:** None — preserve the current grid, toolbar, tabs, and header.
**Primary tasks:** 1. Open a class to edit 2. Filter by learner or subject 3. Add a class 4. Switch status tab

**In scope:**

- Add an optional tile trigger to the shared lazy-modal partial and pass through the full-height wrapper class; preserve its default button and hidden-form paths.
- Expose that option through `courses/_add_trigger`. Append the tile after the final card only when `@status == "active"` and `@courses.any?`, including filtered results.
- Test that the tile uses the unfiltered `new_course_path`, appears last for Active results, and is absent for Completed, Archived, no-match, and empty lists. Scope existing page-level trigger assertions where necessary.

**NOT in scope:**

- Prefilling filters, class form behavior, or the no-active-classes empty state.

**Build order:**

1. **Test:** Extend `test/integration/courses_index_test.rb` for placement, status/filter exclusions, and modal URL.
2. **Implement:** Update the three view partial/page files.
3. **Verify:** `bin/rails test test/integration/courses_index_test.rb`.

### Task 7 [Master]: Replace the no-active-classes line with an empty state

**Skills:** write-tests, style-ui
**Reference:** Read the existing family-level empty state in `app/views/courses/index.html.erb`, `config/locales/en.yml`, and `test/integration/courses_index_test.rb`.
**Prototype:** None — reuse `EmptyStateComponent`.
**Primary tasks:** 1. Open a class to edit 2. Filter by learner or subject 3. Add a class 4. Switch status tab

**In scope:**

- When the family has classes but Active has none and no filter is set, render `EmptyStateComponent` with the `book-open` icon, title "No active classes", description "Find past classes under Completed and Archived, or add a new one.", and the existing "Add class" trigger.
- Replace the `courses.index.none_active` translation with title and description keys.
- Test this state and confirm filtered no-match and family-level empty states retain their distinct behavior and have no tile.

**NOT in scope:**

- Completed/Archived empty states, filter controls, or header placement.

**Build order:**

1. **Test:** Update `test/integration/courses_index_test.rb` for the exact title, description, action, and exclusions.
2. **Implement:** Update `app/views/courses/index.html.erb` and `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/courses_index_test.rb`.

### Task 8 [subagent]: Verify class interactions and document the list rule

**Skills:** write-tests
**Reference:** Read `test/system/courses_system_test.rb` and the surrounding "Lists" bullets in `docs/product/ux-notes.md`.

**In scope:**

- Add a system scenario that opens "Add class" from the tile while filtered, submits a class that does not match the filter, and observes the "Class added" toast. Confirm the tile is absent on Completed and Archived tabs.
- Scope existing page-level "Add class" clicks to the header; leave submit clicks inside the open dialog scoped there.
- Add the design's "Adding" rule under "Lists" in `docs/product/ux-notes.md`, checking it against adjacent toolbar guidance.

**NOT in scope:**

- A row-style implementation, filter prefill, or other product-doc changes.

**Build order:**

1. **Test:** Update `test/system/courses_system_test.rb` and run the new scenario.
2. **Implement:** Add the specified Lists bullet to `docs/product/ux-notes.md`.
3. **Verify:** `bin/rails test test/system/courses_system_test.rb`.
4. **Checkpoint 3:** Master runs `/review-changes-mini` once for Tasks 6–8 after all return. Then run the affected tests, the full `bin/rails test` gate, `git diff --check`, and inspect `git diff` before reporting implementation complete.

## Task Dependencies

- Task 1 comes first and supplies the component for both lists.
- Tasks 2 and 3 can run in parallel after Task 1.
- Task 4 depends on Tasks 1 and 3; Task 5 depends on Task 4.
- Task 6 depends on Tasks 1 and 3; Task 7 depends on Task 6; Task 8 depends on Tasks 6–7.
- Phases 1 and 2 each leave a deployable state. Phase 3 completes the Classes behavior and documentation.
