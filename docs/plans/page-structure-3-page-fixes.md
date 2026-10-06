> Ticket: COV-107
> Branch: feature/cov-107-redesign-students

# Plan: Page Structure, Phase 3: Fix Pages

Bring pages in line with `docs/product/ux-notes.md`, starting with
Students. Part A (Tasks 1–5) is fully specified. Part B (Task 6) turns
the Phase 2 audit into further tasks, which the user approves before
they're executed.

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | A     | 1          | Create SegmentedControlComponent | Master |      |
| 2    | A     | 1          | Students: Active/Archived control in a list toolbar | Master |      |
| 3    | A     | 2          | Students: Add stays at the limit and explains it | Master |      |
| 4    | A     | 2          | Students: card opens on click; actions in a "…" menu | Master |      |
| 5    | A     | 2          | Students: final pass against the audit | Master |      |
| 6    | B     | 3          | Turn audit fix groups into tasks; get approval | Master |      |

## Prerequisites

- Phases 1 and 2 are complete: `docs/plans/page-structure-1-foundations.md`
  and `docs/plans/page-structure-2-audit.md`.
  `.context/page-structure-audit.md` exists with Fix groups.
- Design: `docs/product/ux-notes.md` ("States and interactions", "Page
  structure"). Students rules: `docs/product/product-brief.md`,
  "Students" section (limits, archive, downgrade). Read both before any
  task.
- Prototype: None. Layout follows ux-notes; ask the user if a layout
  choice isn't covered.
- Known state of Students today (`app/views/students/index.html.erb`):
  the header holds Add student (`_add_trigger`) or, at the limit, a
  dashed "disabled add" card with limit text (`_limit_prompt`), which
  breaks the header rules. Archived students appear in a separate section
  behind a "show archived" link. Each card has Edit/View/Restore/Delete
  buttons in its footer. There is no student record page: `show` is a
  read-only modal.

## Tasks

### Task 1 [Master]: Create SegmentedControlComponent

**Skills:** create-component, write-tests, style-ui
**Reference:** `app/components/ui_tabs_component.rb` (look only; tabs are
for navigation, which this is not), `test/components/badge_component_test.rb`

**In scope:**

- A link-based segmented control for filtering a list (ux-notes:
  "Filters use a filter or segmented control, not tabs").
- `app/components/segmented_control_component.rb` + `.html.erb`, test, and
  preview. Arg `label:` (accessible group name). Slot `renders_many
  :options` with `text:`, `href:`, `selected:` (bool), and an optional
  `count:` shown after the text.
- Markup: a `nav` with `aria-label`, links with `aria-current="true"` on the
  selected option. Selected option has a filled background; others are
  plain. 40px tall (on the 4px grid), works at 390px without wrapping for
  two options.

**NOT in scope:**

- JS or in-place filtering (each option is a normal link to a URL).
- A general toolbar component.

**Build order:**

1. **Test:** `test/components/segmented_control_component_test.rb`:
   renders each option as a link with its href; the selected option has
   `aria-current="true"` and others don't; the count renders when given;
   the nav has the given `aria-label`.
2. **Implement:** the component, template, and preview.
3. **Verify:** `bin/rails test test/components/segmented_control_component_test.rb`

### Task 2 [Master]: Students: Active/Archived control in a list toolbar

**Skills:** write-tests, style-ui
**Reference:** `app/views/students/index.html.erb`,
`app/controllers/students_controller.rb#index`,
`test/system/students_system_test.rb` ("archived students are hidden
until toggled and can be restored")

**In scope:**

- Above the student grid, add a toolbar row (a plain flex row in the
  view; no new component) holding `SegmentedControlComponent` with
  "Active" and "Archived", each with its count. Show it only when the
  family has at least one archived student.
- `?archived=1` shows **only** archived cards in the same grid (not a
  second section); the default shows only active. Remove the "show/hide
  archived" link and the separate archived `<section>`. Keep the
  restore-blocked note: show it above the grid in the Archived view.
- If there are archived students but no active ones, the Active view
  still shows the toolbar above the empty state, so archived students
  stay reachable.
- Locale keys for "Active" and "Archived"; remove keys no longer used
  (`show_archived`, `hide_archived`, `archived_heading`).

**NOT in scope:**

- Card actions (Task 4). Search, sort, or pagination (families have ≤12
  students in normal use).

**Build order:**

1. **Test:** update the archived system test: Archived control appears
   only when one exists; clicking "Archived" shows the archived student
   and hides active ones; Restore returns them to Active. Add "a family
   whose students are all archived still sees the Archived control".
2. **Implement:** `index.html.erb`, `students_controller.rb` (only if
   `@show_archived`/queries need adjusting), and `en.yml`.
3. **Verify:** `bin/rails test:system test/system/students_system_test.rb`
   and `bin/rails test test/controllers`.
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 1 (Tasks 1–2). It runs exactly once per checkpoint.

### Task 3 [Master]: Students: Add stays at the limit and explains it

**Skills:** write-tests, style-ui
**Reference:** `app/views/students/_add_trigger.html.erb`,
`app/views/students/_limit_prompt.html.erb` (text to reuse),
`app/models/account.rb` (`can_add_student?`, `over_free_student_limit?`,
`students_allowed`, `premium?`)

**In scope:** (ux-notes, "Plan limits…" bullet)

- Header primary action is always "Add student" when the family has any
  students (empty state keeps its own Add button, and the header has none
  then, as today). This includes families over the Free limit after a
  downgrade.
- When `can_add_student?` is false, the Add button opens a modal (no lazy
  load needed) instead of the add form. The modal is titled with the
  limit, gives a one-sentence explanation, and has one action:
  - Free: "See plans" → `pricing_path` (matches the app's other Upgrade
    links).
  - Premium at its cap: "Contact us" → the existing `mail_to` support link
    and subject from `_limit_prompt`.
  - Buttons: "Close" (secondary) left of the action (primary, rightmost).
- Replace `_limit_prompt.html.erb` with `_limit_modal.html.erb` (delete
  the old partial). Copy follows ux-notes Voice (no exclamation points,
  calm, no urgency).
- The free-limit downgrade banner (`_free_limit_banner`) stays as is. It's
  already in the content.

**NOT in scope:**

- Changing limits, the kept-students picker, or billing.
- The archived restore-blocked note (Task 2).

**Build order:**

1. **Test:** update "a family at its Free limit sees the upgrade prompt
   instead of Add student" → "at the Free limit, Add student explains the
   limit and links to plans": Add student is visible; clicking it opens
   the limit modal with a link to `/pricing`; no add form. Add the Premium
   cap equivalent with "Contact us".
2. **Implement:** `index.html.erb`, new `_limit_modal.html.erb` (delete
   `_limit_prompt.html.erb`), `en.yml` (move/rename the `limit_prompt`
   keys).
3. **Verify:** `bin/rails test:system test/system/students_system_test.rb`

### Task 4 [Master]: Students: card opens on click; actions in a "…" menu

**Skills:** write-tests, style-ui
**Reference:** `app/views/students/_student_card.html.erb`,
`app/components/dropdown_component.rb` (see AGENTS.md: use
`with_item_custom` for non-standard items),
`app/views/application/_sidebar_account_menu.html.erb` (dropdown usage)

**In scope:** (ux-notes Lists: "Clicking an item opens it; per-item
actions go in a '…' menu. Nothing hover-only.")

- Remove the card footer buttons. The whole card opens on click:
  editable → the Edit modal; read-only → the View modal; archived → no
  click target (it has only menu actions).
- Use the "stretched link" pattern: the student's name is the real
  `<button>` modal trigger, with `after:absolute after:inset-0` covering
  the card. The "…" button sits top-right, above it (`relative z-10`),
  with `aria-label` "Actions for <name>". The focus ring shows on the
  card.
- "…" menu items: active and editable → Archive, Delete; read-only →
  Delete; archived → Restore (only when `can_restore`), Delete. Archive
  and Restore submit their existing forms. Delete opens the existing
  delete confirmation modal. The dropdown portals its menu, so if a
  `UiModalComponent` inside a menu item doesn't open, render the delete
  modal outside the dropdown and trigger it from the menu item (e.g. a
  custom event the modal's controller listens for). Don't stack it on
  another modal.
- Delete is styled as destructive (red text) in the menu.

**NOT in scope:**

- A student record page. The after-create redirect rule needs one; see
  "Deferred" below.
- The Edit modal's own Archive/Delete buttons (leave them).

**Build order:**

1. **Test:** update the existing edit, delete, archived-delete, and
   restore system tests to go through the card click or "…" menu (use
   `find("[aria-label='Actions for Ada']").click` per AGENTS.md). Add
   "clicking a student card opens their edit modal" and "the actions
   menu is reachable by keyboard" (tab to "…", press Enter, the menu
   opens).
2. **Implement:** `_student_card.html.erb` and `en.yml` (plus at most one
   small helper partial if the delete modal must live outside the
   dropdown).
3. **Verify:** `bin/rails test:system test/system/students_system_test.rb`

### Task 5 [Master]: Students: final pass against the audit

**Skills:** run, style-ui
**Reference:** `.context/page-structure-audit.md`, "Main" → Students
findings

**In scope:**

- Re-check every Students finding from the audit. Fix any remaining one
  that fits in ≤4 files; list the rest in the report.
- Screenshot Students at 1280px and 390px in four states (empty, normal,
  at the Free limit with the modal open, Archived view) to
  `.context/students-*.png`.
- Mark the fixed Students findings as done in the audit file.

**NOT in scope:**

- Other pages.

**Build order:**

1. **Test:** add tests for any behavior you change.
2. **Implement:** remaining small fixes.
3. **Verify:** `bin/rails test` and `bin/rails test:system
   test/system/students_system_test.rb` (sequentially, not in parallel).
4. **Checkpoint:** when finished, run review-changes-mini covering
   checkpoint 2 (Tasks 3–5). It runs exactly once per checkpoint.

### Task 6 [Master]: Turn audit fix groups into tasks; get approval

**Skills:** write-plan (task format only)
**Reference:** `.context/page-structure-audit.md` ("Fix groups" and
"Questions for Jordan")

**In scope:**

- First, ask the user the "Questions for Jordan" from the audit, and wait
  for answers.
- Then append Tasks 7+ to this plan, one per fix group, in the audit's
  priority order and in this plan's task format (Skills, Reference, In
  scope, NOT in scope, Build order with Test/Implement/Verify, ≤4 files,
  checkpoints of ≤3 tasks with a review-changes-mini instruction on each
  checkpoint's last task). Add rows to the Status table and update Task
  Dependencies.
- Present the new tasks to the user. **Stop and wait for explicit
  approval** before executing any of them.

**NOT in scope:**

- Executing the new tasks before approval.
- Schedule, Dashboard structure, first run, and Settings structure. These
  are deferred to their own features; skip findings that only those
  redesigns would fix and list them as deferred.

**Build order:**

1. **Test:** none.
2. **Implement:** the plan update.
3. **Verify:** every Fix group maps to a task or a deferred note. Commit
   the plan update (`docs: add audit fix tasks to page structure plan`).
4. **Checkpoint:** run review-changes-mini covering checkpoint 3 (Task 6)
   on the plan diff.

## Deferred

- **After creating a student, go to their record page** (ux-notes "Where
  things open"). Students has no record page yet. Until one exists, the
  rule's fallback applies: stay on the list with a toast, which is what
  happens today. Build the record page (with its back link and student
  switcher) when it has real content, likely with school plans.

## Task Dependencies

- Task 2 depends on Task 1.
- Tasks 3 and 4 both edit `students/index` or the card and the same
  system test file; run them sequentially after Task 2.
- Task 5 depends on Tasks 2–4.
- Task 6 depends on Phase 2 being complete and can run after Task 5.
