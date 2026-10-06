> Ticket: COV-107
> Branch: feature/cov-107-redesign-students

# Plan: Page Structure, Phase 1: Shared Foundations

Build the shared pieces that make the Page structure rules in
`docs/product/ux-notes.md` easy to follow: one page header component used
everywhere, written-style date/time helpers, modal behavior fixes, and
docs that steer new work away from retired components.

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Create PageHeaderComponent | Master | ✅ |
| 2    | 1     | 1          | Use PageHeader on Dashboard, Subjects, Schedules, Support | Clone | ✅ |
| 3    | 1     | 1          | Use PageHeader on Students and the Settings layout | Clone | ✅ |
| 4    | 2     | 2          | Date/time format helpers | Master | ✅ |
| 5    | 2     | 2          | Use the helpers where signed-in pages show dates | Clone | ✅ |
| 6    | 3     | 3          | Modals open as full-height sheets on phones | Master | ✅ |
| 7    | 3     | 3          | Ask before discarding unsaved changes in a modal | Master | ✅ |
| 8    | 4     | 4          | Mark retired components in code and catalog | Clone | ✅ |
| 9    | 4     | 4          | Point AGENTS.md and style-ui at the page rules | Master | ✅ |

## Prerequisites

- Design: `docs/product/ux-notes.md`, sections "States and interactions"
  and "Page structure (signed-in app)". Read both before any task. They
  are the spec.
- Prototype: None
- Branch `feature/cov-107-redesign-students` is checked out.
- Shell: `export PATH="$HOME/.local/share/mise/shims:$PATH"` before any
  `bin/rails` command (see AGENTS.md "Environment").

## Tasks

### Task 1 [Master]: Create PageHeaderComponent

**Skills:** create-component, write-tests, style-ui
**Reference:** `app/views/students/index.html.erb` (current hand-built
header), `app/components/empty_state_component.rb` (slot style),
`app/components/dropdown_component.rb` (for the "…" menu),
`test/components/empty_state_component_test.rb` (test style)

**In scope:**

- `app/components/page_header_component.rb` + `.html.erb`, test, and
  Lookbook preview in `test/components/previews/`.
- Args: `title:` (required), `description:` (optional, one line).
- Slots: `primary_action` (one), `secondary_actions` (renders_many, max
  two; raise `ArgumentError` on a third), `menu` (optional "…" overflow
  content, rendered with `DropdownComponent`, icon trigger with
  `aria-label` "More actions").
- Layout (from ux-notes Header rules): title `<h1>` top-left (serif via
  the existing `h1` tag rule; don't add font classes), description below
  in `font-sans text-muted-foreground`. Actions right of the title,
  vertically centered on the title line (not the title + description
  block). Primary is rightmost; secondary actions sit to its left.
- Phones (below `sm`): actions wrap to their own row under the title. The
  primary keeps its text label; secondary actions move into the "…" menu
  (render them a second time inside the menu with `sm:hidden`, and hide
  the inline copies with `hidden sm:flex`).
- Bottom margin: 32px desktop, 24px phones (`mb-6 sm:mb-8`). All spacing
  on the 4px grid (no `.5` steps).

**NOT in scope:**

- Using it on any page (Tasks 2–3).
- Back links, record switchers, tabs, or toolbars.
- Any text other than title and description (the rules forbid it).

**Build order:**

1. **Test:** `test/components/page_header_component_test.rb`: renders the
   title as `h1`; renders the description when given and omits it when
   not; renders the primary action; secondary actions render inline and
   again inside the "…" menu; a third secondary action raises
   `ArgumentError`; with no actions, no actions wrapper is rendered.
2. **Implement:** the component, template, and preview (previews: title
   only; title + description; full header with primary, two secondary,
   and menu).
3. **Verify:** `bin/rails test test/components/page_header_component_test.rb`

### Task 2 [Clone]: Use PageHeader on Dashboard, Subjects, Schedules, Support

**Skills:** style-ui
**Reference:** `app/components/page_header_component.rb` (from Task 1)

**In scope:**

- Replace the hand-built `<h1>` + description block in:
  `app/views/dashboard/show.html.erb`,
  `app/views/subjects/index.html.erb`,
  `app/views/schedules/index.html.erb`,
  `app/views/support/show.html.erb`
  with `render PageHeaderComponent.new(title:, description:)`. Keep the
  same title and description text.
- Today the outer `<div class="mb-8">` wraps the header *and* the empty
  state. Remove that wrapper so the header's own margin sets the gap, and
  the empty state renders directly after the header.

**NOT in scope:**

- Changing any text, including "Schedules" vs. "Schedule" (that's an
  audit item for Phase 2).
- Changing the empty states.

**Build order:**

1. **Test:** none new. These are visual swaps covered by existing tests.
2. **Implement:** the four view changes.
3. **Verify:** `bin/rails test` (the whole suite; titles are asserted in
   controller and system tests). Fix anything that asserted the old
   markup.

### Task 3 [Clone]: Use PageHeader on Students and the Settings layout

**Skills:** style-ui
**Reference:** `app/components/page_header_component.rb` (from Task 1)

**In scope:**

- `app/views/students/index.html.erb`: replace the header `<div>` with
  `PageHeaderComponent`. Put the existing conditional actions
  (`render "add_trigger"` / `render "limit_prompt"`) in the
  `primary_action` slot **unchanged**. Phase 3 moves them.
- `app/views/layouts/sidebar.html.erb`: replace the Settings `<h1>` and
  description with `PageHeaderComponent` (title "Settings", same
  description key). Keep `settings-content` and the tab nav as they are.

**NOT in scope:**

- Any Students behavior change (add card, limit prompt, archived list):
  that's Phase 3.
- The `<h1 class="h3">` headings inside individual settings pages.

**Build order:**

1. **Test:** none new.
2. **Implement:** the two view changes.
3. **Verify:** `bin/rails test test/system/students_system_test.rb` and
   `bin/rails test`.
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 1 (Tasks 1–3). If Tasks 2–3 ran as a parallel batch, the
   master runs this review once the whole batch returns instead. It runs
   exactly once per checkpoint.

### Task 4 [Master]: Date/time format helpers

**Skills:** write-tests
**Reference:** `app/helpers/application_helper.rb` (add methods here;
see AGENTS.md: never create a helper file that collides with a Jumpstart
engine helper), `config/locales/en.yml`

**In scope:** (formats from ux-notes "Formats")

- `config/locales/en.yml`: add `date.formats.friendly: "%-d %b %Y"`,
  `date.formats.friendly_short: "%-d %b"`, and
  `time.formats.friendly: "%-l:%M%P"`, plus `today`/`tomorrow`/
  `yesterday` strings under a `friendly_dates` key.
- `ApplicationHelper#friendly_date(date)`: "Today"/"Tomorrow"/
  "Yesterday" when it matches; otherwise "9 Sep" in the current year and
  "9 Sep 2025" in other years. Accepts Date or Time (convert with
  `to_date` in the current time zone).
- `ApplicationHelper#friendly_time(time)`: "5:07pm", always with minutes
  ("5:00pm").
- `ApplicationHelper#friendly_date_range(start_date, end_date)`:
  "9–12 Sep 2025" (same month), "30 Sep–2 Oct 2025" (same year),
  "28 Dec 2025–3 Jan 2026" (different years), with an en dash and no
  spaces. In the current year, drop the year. Same day returns
  `friendly_date`.

**NOT in scope:**

- Changing the existing `:long` format (the public legal page uses it).
- Using the helpers in views (Task 5).

**Build order:**

1. **Test:** `test/helpers/application_helper_test.rb` (create it if
   missing): wrap each case in `travel_to Time.zone.local(2025, 9, 9, 12)`.
   Cover today/tomorrow/yesterday, the current year without the year,
   another year with it, Time input, `friendly_time` for 5:07pm, 5:00pm,
   and 12:30am, and all three range shapes plus the same-day range.
2. **Implement:** the locale keys and three helper methods.
3. **Verify:** `bin/rails test test/helpers/application_helper_test.rb`

### Task 5 [Clone]: Use the helpers where signed-in pages show dates

**Reference:** `app/helpers/application_helper.rb` (from Task 4)

**In scope:**

- `app/views/api_tokens/index.html.erb:31` and
  `app/views/api_tokens/show.html.erb:40`: replace
  `strftime("%b %e, %Y")` with `friendly_date(...)`.
- `app/helpers/account_deletion_helper.rb:27`: replace
  `l(subscription.current_period_end.to_date, format: :long)` with
  `friendly_date(subscription.current_period_end)`.

**NOT in scope:**

- `app/views/public/_legal_page.html.erb` (public, not signed-in).
- Restructuring the API tokens table (Phase 3, if the audit flags it).

**Build order:**

1. **Test:** run `grep -rn "active_until\|current_period_end" test/` and
   update any assertion that expects the old long date to the new format.
2. **Implement:** the three replacements.
3. **Verify:** `bin/rails test`
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 2 (Tasks 4–5). If run as a parallel batch, the master runs
   it once the batch returns. It runs exactly once per checkpoint.

### Task 6 [Master]: Modals open as full-height sheets on phones

**Skills:** style-ui, write-tests
**Reference:** `app/components/ui_modal_component.rb` (`dialog_classes`,
`size_classes`, `content_wrapper_classes`),
`app/assets/tailwind/components/modal.css`,
`test/components/ui_modal_component_test.rb`

**In scope:**

- Below `sm` (640px), every non-`:fullscreen` `UiModalComponent` fills
  the screen: full width, full height (`h-dvh max-h-dvh`), no outer
  margin or rounding, content scrolling inside. From `sm` up, it keeps
  today's centered, sized look. Long content scrolls inside the modal on
  desktop too (cap height at the viewport and use `overflow-y-auto` on the
  content wrapper).
- Check that the close button and the footer buttons stay reachable on a
  390×844 viewport.

**NOT in scope:**

- Drag-to-dismiss or snap points (that's the Drawer; not wanted).
- Changing modal content or the Stimulus controller.

**Build order:**

1. **Test:** in `test/components/ui_modal_component_test.rb`, assert that
   a `size: :md` modal's dialog has the phone full-screen classes and the
   `sm:` sized classes.
2. **Implement:** class changes in `ui_modal_component.rb` (and
   `modal.css` only if a `dialog.modal` rule there fights the new
   classes; check it first).
3. **Verify:** `bin/rails test test/components/ui_modal_component_test.rb`
   and `bin/rails test test/system/students_system_test.rb`. Then use the
   run skill to open the Students "Add student" modal at 390px and 1280px
   widths and save screenshots to `.context/modal-phone.png` and
   `.context/modal-desktop.png`.

### Task 7 [Master]: Ask before discarding unsaved changes in a modal

**Skills:** write-tests, style-ui
**Reference:** `app/javascript/controllers/ui_modal_controller.js`
(`close`, `backdropClose`, `handleDialogCancel`),
`app/components/ui_modal_component.html.erb`,
`test/system/students_system_test.rb` ("cancel closes the add and edit
modals without saving…")

**In scope:**

- In `ui_modal_controller.js`: after content loads, mark the modal
  "dirty" on any `input`/`change` event inside a `<form>` in it. Clear
  the flag on form submit and when the modal closes.
- When a dirty modal is asked to close (close button, Cancel button using
  `ui-modal#close`, Esc, or backdrop click), don't close. Instead show an
  inline prompt inside the modal, pinned at its bottom: "Discard your
  changes?" with "Keep editing" (secondary) and "Discard" (primary,
  rightmost). Keep editing hides the prompt; Discard closes the modal.
  Do NOT use `window.confirm` or a second modal (ux-notes: only a
  confirmation may sit on a modal; an inline prompt avoids stacking).
- Render the prompt markup (hidden by default) in
  `ui_modal_component.html.erb`, with text from `en.yml`.

**NOT in scope:**

- Leaving the page (`beforeunload`) or Turbo navigation guards.
- Modals without a form (no change in behavior).

**Build order:**

1. **Test:** in `test/system/students_system_test.rb`, add "closing the
   add modal after typing asks before discarding": type a name, click
   Cancel, see "Discard your changes?"; click Keep editing and the typed
   name is still there; click Cancel, then Discard, and the modal is
   closed with no student created. Add "closing an untouched modal closes
   right away". Update the existing cancel test only if it types before
   cancelling.
2. **Implement:** the controller, template, and locale changes (4 files
   including the test).
3. **Verify:** `bin/rails test:system test/system/students_system_test.rb`
   (don't run it at the same time as another test process).
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 3 (Tasks 6–7). It runs exactly once per checkpoint.

### Task 8 [Clone]: Mark retired components in code and catalog

**Reference:** `docs/COMPONENT_CATALOG.md` (Quick Reference + each
component's detail section)

**In scope:**

- Add an `# AIDEV-NOTE:` above the class in
  `app/components/table_component.rb` ("Retired for new work: ux-notes
  forbids tables; use a structured list. Existing uses are being
  replaced."),
  `app/components/breadcrumb_component.rb` ("Retired: pages are at most
  one level deep; record pages use a single back link.") and
  `app/components/drawer/component.rb` ("Only for the phone navigation
  menu in the app shell. Use UiModalComponent for every other overlay.").
- In `docs/COMPONENT_CATALOG.md`: prefix each of those three components'
  Purpose cell with "**Don't use for new work.**" and add the same one-line
  reason to each detail section. In `UiModalComponent`'s detail section,
  add "Only a confirmation may open on top of a modal; prefer an inline
  prompt (see the unsaved-changes prompt)."

**NOT in scope:**

- Deleting the components or changing their existing uses.
- Running update-catalog.

**Build order:**

1. **Test:** none (docs and comments only).
2. **Implement:** the four file edits.
3. **Verify:** `bin/rubocop` (comments in .rb files) and `bin/rails test test/components`.

### Task 9 [Master]: Point AGENTS.md and style-ui at the page rules

**In scope:**

- `AGENTS.md`, "Product docs" bullet: change "`ux-notes.md` — read before
  writing user-facing text or screen states" to "…user-facing text,
  screen states, or page layout".
- `~/.claude/skills/style-ui/SKILL.md` (global, **outside the repo**, so
  it won't appear in git): in its checklist, add one generic line: "If
  `docs/product/ux-notes.md` has a page structure section, check the
  page's header, overlays, lists, spacing, and phone behavior against it."
  Keep it project-agnostic. Show the user the exact diff of this file in
  the report, since git won't track it.

**NOT in scope:**

- Any other skill or doc.

**Build order:**

1. **Test:** none.
2. **Implement:** the two edits.
3. **Verify:** `git diff AGENTS.md` and `grep -n "page structure"
   ~/.claude/skills/style-ui/SKILL.md`.
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 4 (Tasks 8–9). If run as a parallel batch, the master runs
   it once the batch returns. It runs exactly once per checkpoint.

## Task Dependencies

- Tasks 2 and 3 depend on Task 1, and can run in parallel with each other.
- Task 5 depends on Task 4.
- Task 7 depends on Task 6 (both touch the modal; do them sequentially).
- Tasks 4, 6, and 8 don't depend on Task 1 and could run in any order;
  run checkpoints in order for clean reviews.
- Tasks 8 and 9 can run in parallel.
