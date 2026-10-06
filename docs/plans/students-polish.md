> Ticket: COV-107
> Branch: feature/cov-107-redesign-students

# Plan: Students Polish

Small follow-ups to the Students redesign, decided by the user:

1. Student cards get a subtle hover: the border goes one shade darker.
2. The "…" icon stays horizontal (no change).
3. Active/Archived becomes underline tabs (`UiTabsComponent`, links mode).
   `SegmentedControlComponent` is deleted.
4. No modal ever opens on top of another modal (rule already added to
   `docs/product/ux-notes.md`, "Where things open"). Delete inside the
   Edit modal swaps the modal's content to the confirmation instead of
   stacking a second modal.

Read first: `AGENTS.md` (env gotchas: mise shims, sequential system
tests, `-i` for single system tests), `docs/product/ux-notes.md`.
TDD for every behavior change: write or update the test, see it fail,
then implement.

## Status

| Task | Checkpoint | Description | Assign | Done |
| ---- | ---------- | ----------- | ------ | ---- |
| 1    | 1          | ux-notes: filters may use tabs | Master | |
| 2    | 1          | Student card hover border | Master | |
| 3    | 1          | Active/Archived as underline tabs; delete SegmentedControlComponent | Master | |
| 4    | 2          | Delete swaps the Edit modal's content (no stacked modal) | Master | |
| 5    | 2          | Audit other modals for stacking; full test run | Master | |

## Task 1: ux-notes — filters may use tabs

`docs/product/ux-notes.md`, "Sections and tabs": replace

> Tabs switch views of a page, never list items. Each has its own URL, about
> five at most, scrolling sideways on phones. Filters use a filter or
> segmented control, not tabs.

with

> Tabs switch views of a page, never list items. Each has its own URL, about
> five at most, scrolling sideways on phones. A list's Active/Archived switch
> uses underline tabs with counts; other filters use a filter control.

No other doc changes. Don't touch the "no modal on a modal" line (already
done).

## Task 2: Student card hover border

File: `app/views/students/_student_card.html.erb`.

- Active, clickable cards only. When the pointer is over the card's click
  target (the name button's stretched `::after`), the card border goes one
  step darker than its resting border. Find the resting border token in
  `CardComponent` and pick the next darker neutral step. Add
  `transition-colors`. No shadow, no movement.
- Hovering the "…" button must NOT change the card border. Because the
  stretched link is the hover target, use a `:has()` variant on the card
  keyed to the name button, e.g. add `data-student-card-link` to the name
  `<button>` and pass `has-[[data-student-card-link]:hover]:border-…` in
  the `CardComponent` `classes:`. The "…" button sits above (z-10), so
  hovering it doesn't hover the link.
- Archived cards render no name button, so they get no hover automatically.
- Update the card's AIDEV-NOTE to mention the hover.

Test (`test/integration/students_index_test.rb`): an active student's
name button has `data-student-card-link`, and an archived student's card
has none. Verify the real hover in a browser (`bin/dev`, `/students`):
border darkens over the card, not over "…".

## Task 3: Active/Archived as underline tabs

### 3a. Give links-mode tabs an accessible name

`UiTabsComponent` links mode renders a bare `<nav>` with no label. Add an
optional `label:` param (default `nil`) that renders `aria-label` on the
links-mode `<nav>` only. Add a component test in
`test/components/ui_tabs_component_test.rb` (create if missing): with
`label:`, the nav has the aria-label; without it, there's no aria-label.
Update the param doc comment.

### 3b. Use it on Students

`app/views/students/index.html.erb`: replace the `SegmentedControlComponent`
block with

```erb
<%= render UiTabsComponent.new(mode: :links, variant: :underline, label: t(".filter_label"), tab_list_classes: "w-full border-b border-neutral-200") do |tabs| %>
  <% tabs.with_tab(title: t(".active"), href: students_path, active: !@show_archived, meta: @students.size) %>
  <% tabs.with_tab(title: t(".archived"), href: students_path(archived: 1), active: @show_archived, meta: @archived_count) %>
<% end %>
```

Match the settings tabs in `app/views/application/_account_navbar.html.erb`
for look. Keep the wrapper's `mb-4` spacing and the
`@archived_count.positive?` condition. Check `meta: 0` still renders
"0" (the Active tab can be 0); if `meta.present?` hides it, pass the count
as a string. Update the AIDEV-NOTE above it.

Tests: tabs render `aria-current="page"`, not `"true"`. Update
`test/integration/students_index_test.rb` (around lines 221, 222, 241, 256)
and `test/system/students_system_test.rb` (line 112) to the new markup;
keep `nav[aria-label='Filter students']`.

### 3c. Delete SegmentedControlComponent

Remove:
- `app/components/segmented_control_component.rb`, `.html.erb`, and the
  `segmented_control_component/` folder
- `test/components/segmented_control_component_test.rb`
- `test/components/previews/segmented_control_component_preview.rb`
- its kitchen sink demo (`app/views/dev/kitchen_sink/show.html.erb` ~line
  178). If `test/integration/dev/kitchen_sink_test.rb` asserts on it,
  update that test.
- its `docs/COMPONENT_CATALOG.md` table row (line 26) and section (~619–650)

Then `grep -rn -i "segmented" app test docs/COMPONENT_CATALOG.md` must
return nothing (plan docs in `docs/plans/` may still mention it).

## Task 4: Delete swaps the Edit modal's content

Today `app/views/students/_actions.html.erb` nests a second
`UiModalComponent` for Delete, which stacks on the Edit modal. Change it
so Delete replaces the modal's content with the confirmation, and Cancel
swaps the edit form back. Most of this already exists:
`students/delete.html.erb` renders inside the `modal-lazy-content` frame,
and without `from=list` its Cancel is a link back to the edit page (or
the read-only page), which navigates the same frame.

### 4a. Delete becomes a frame link

In `_actions.html.erb`, replace the nested modal with a link to
`delete_student_path(student)` (no `from` param) that targets the
`modal-lazy-content` frame (it's already inside that frame, so a plain
link navigates it). Keep the look (ghost, red text) and the "Delete"
label. Remove the "A confirmation may stack on an edit modal" AIDEV-NOTE.

In `_delete_content.html.erb`, the `close_on_cancel: true` caller is gone.
Update its AIDEV-NOTE: list and archived confirms close the modal on
Cancel; confirms reached from Edit or the read-only view swap back.

### 4b. One heading at a time

The card's Edit modal has the component title "Edit Maya", which would
sit above the swapped-in "Delete Maya?" heading (two headings — the
problem audit M-11 fixed for the list's delete modal). Fix it by moving
the title into the frame:

- `_student_card.html.erb`: drop `title:` from the editable and read-only
  `UiModalComponent`s.
- `students/edit.html.erb`: render the "Edit <name>" heading
  (`students.index.edit_title`) inside the frame, styled the same as
  `UiModalComponent#title_classes`.
- `students/show.html.erb`: same, with the student's name as heading.
- Leave the Add modal (`_add_trigger`) and `new.html.erb` alone.

### 4c. Don't ask "discard changes?" after a swap

`ui_modal_unsaved_changes_controller.js` marks the modal dirty on any
input and only clears on submit/close. After swapping to the
confirmation, closing would wrongly ask to discard. Clear the dirty flag
when the lazy content frame finishes loading new content (listen for
`turbo:frame-load` on the dialog → `clearDirty`). Edits typed before
clicking Delete are dropped; Cancel reloads the saved values.

**Ask the user before implementing** if they'd rather keep typed edits
on Cancel; that needs more work and isn't in this plan.

### Tests

- `test/integration/students_test.rb` "the edit form offers archive and
  delete": Delete is now a link to `delete_student_path(@maya)`, not a
  button; no nested modal markup in the edit response.
- `test/integration/students_index_test.rb`: editable/read-only card modals
  render no component title `h2`; `edit_student_path` response contains the
  "Edit Maya" heading.
- `test/system/students_system_test.rb`:
  - "deleting a student asks for confirmation and removes them": Delete
    shows "Delete Maya?" in the same dialog (`dialog[open]` count 1, no
    "Edit Maya" heading visible), then deletes.
  - Replace "cancelling Delete returns to the open edit modal with its
    fields intact" with: cancelling Delete shows the edit form again in
    the same dialog (count 1) with saved values, and closing then doesn't
    show the discard prompt.
  - Read-only student: Delete → confirmation → Cancel returns to the
    read-only view in the same dialog.
- Existing list "…" → Delete and archived → Delete tests should pass
  unchanged.

## Task 5: Audit and full run

- Look for other modal-on-modal cases: any `UiModalComponent` rendered
  inside a modal's content or a lazy-loaded modal view (check
  `accounts/show`, `billing/subscriptions/_subscription`,
  `billing/_info`, `account/passwords/edit`). **Report** them to the user
  with a suggested fix; don't change them in this plan.
- Run `bin/rails test`, then `bin/rails test:system` (sequentially), then
  `bin/rubocop`. Show output.
- If any `db/*schema.rb` changed only by reordering/version bump, revert
  it (see AGENTS.md).
- `git diff` to confirm the change set. Don't commit; the user runs
  `/review-changes`.
