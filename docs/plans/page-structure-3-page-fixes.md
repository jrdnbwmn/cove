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
| 1    | A     | 1          | Create SegmentedControlComponent | Master | ✅   |
| 2    | A     | 1          | Students: Active/Archived control in a list toolbar | Master | ✅   |
| 3    | A     | 2          | Students: Add stays at the limit and explains it | Master | ✅   |
| 4    | A     | 2          | Students: card opens on click; actions in a "…" menu | Master | ✅   |
| 5    | A     | 2          | Students: final pass against the audit | Master | ✅   |
| 6    | B     | 3          | Turn audit fix groups into tasks; get approval | Master | ✅   |
| 7    | B     | 4          | Students: Delete confirmation stacks on top of Edit (M-11) | Master |      |
| 8    | B     | 4          | Subjects and Support placeholder empty states (M-14, M-17) | Clone  |      |
| 9    | B     | 4          | Remove the Notifications page (M-21) | Clone  |      |
| 10   | B     | 5          | Settings tabs: regroup, hide API, fix phone overflow (U-2, U-28, U-29) | Master |      |
| 11   | B     | 5          | Security tab: password, two-factor, connected accounts (U-8, U-17, U-18, U-19) | Master |      |
| 12   | B     | 5          | Family page: parents as rows, invite note, delete at the bottom (F-1 to F-5, F-11) | Master |      |
| 13   | B     | 6          | Remove the Edit parent page (F-12 to F-14) | Master |      |
| 14   | B     | 6          | Edit family as a modal; transfer ownership (F-6 to F-10) | Master |      |
| 15   | B     | 6          | Invite a parent as a modal (F-15 to F-18) | Master |      |
| 16   | B     | 7          | Cancel and resume as modals (F-30 to F-34) | Master |      |
| 17   | B     | 7          | Plan change as a focused page (F-35, F-36) | Master |      |
| 18   | B     | 7          | Two-factor: enable on POST, not GET (U-15) | Master |      |
| 19   | B     | 8          | Two-factor setup as a modal flow (U-10, U-12 to U-14, U-16) | Master |      |
| 20   | B     | 8          | Billing page: one plan summary, one primary, spacing (F-20 to F-23, F-25) | Master |      |
| 21   | B     | 8          | Billing dates and charges as rows (F-24, F-28) | Master |      |
| 22   | B     | 9          | Billing email and info forms (F-26, F-27) | Clone  |      |
| 23   | B     | 9          | One h1 per Settings page; Profile form layout (U-1, U-3, U-5, U-6, U-9, U-11) | Master |      |
| 24   | B     | 10         | Invitation accept page (F-19) | Clone  |      |
| 25   | B     | 10         | Checkout heading and a way back (F-41, F-42) | Clone  |      |
| 26   | B     | 10         | Optional cleanup of dead code (U-4, U-7, F-29, F-37, F-43) | Master |      |

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

- Append Tasks 7+ to this plan, one per fix group, in the audit's
  priority order and in this plan's task format (Skills, Reference, In
  scope, NOT in scope, Build order with Test/Implement/Verify, ≤4 files,
  checkpoints of ≤3 tasks with a review-changes-mini instruction on each
  checkpoint's last task). Add rows to the Status table and update Task
  Dependencies.
- Present the new tasks to the user. **Stop and wait for explicit
  approval** before executing any of them.

**NOT in scope:**

- Executing the new tasks before approval.
- Schedule, Dashboard, and first run. These are deferred to their own
  ticket (Dashboard/Schedule findings M-1, M-2, M-15, M-16 are drafted in
  `.context/ticket-dashboard-schedule.md`); list them as deferred.
  Settings structure IS in scope (user decision, 6 Oct 2026): the tab
  regroup, Security tab, and two-factor flow become tasks.
- Asking the audit's Questions again: they were answered in Phase 2 (see
  "Decisions" in the audit file).

**Build order:**

1. **Test:** none.
2. **Implement:** the plan update.
3. **Verify:** every Fix group maps to a task or a deferred note. Commit
   the plan update (`docs: add audit fix tasks to page structure plan`).
4. **Checkpoint:** run review-changes-mini covering checkpoint 3 (Task 6)
   on the plan diff.

## Part B tasks (from the Phase 2 audit)

Tasks 7–26 are approved from the audit's Fix groups, in its priority order.
Approval recorded 6 Oct 2026: Task 7 should first attempt a stacked delete
confirmation; Task 8's Subjects state has no action; Task 26 is included; and
Tasks 18 and 19 remain separate for the two-factor correctness fix and layout.
Each task lists the audit finding IDs it closes; read those entries in
`.context/page-structure-audit.md` and the "Decisions" there first. Tasks marked
[Clone] touch files no other task in their checkpoint touches, so they can run
in parallel.

### Task 7 [Master]: Students: Delete confirmation stacks on top of Edit (M-11)

**Skills:** write-tests, style-ui
**Reference:** audit M-11; `app/views/students/_actions.html.erb`,
`app/views/students/delete.html.erb`, `app/components/ui_modal_component.rb`;
ux-notes: "Only a confirmation may open on top of a modal."

**In scope:**

- Today the Edit modal's Delete swaps the modal's content, so the title
  "Edit Maya" sits above the heading "Delete Maya?". Make Delete open the
  confirmation as a second dialog on top of the Edit modal (its own
  `UiModalComponent`, no title, one heading). Cancel closes only the
  confirmation and leaves Edit open; Escape closes only the top dialog.
- Both lazy modals use the Turbo frame id `modal-lazy-content`. Two frames
  with one id in the DOM will collide: render the confirmation inline
  (not lazy) inside the Edit form's actions, or give it its own frame.

**NOT in scope:**

- Moving every modal title into its content (the audit's alternative; it
  touches more than 4 files). If stacking can't be made to work (focus return,
  scroll lock count, Escape), STOP and ask.
- The "…" menu delete (already one heading, Task 5).

**Build order:**

1. **Test:** system test: from Edit, Delete opens one confirmation on top;
   Cancel returns to Edit with its fields intact; confirming deletes. Update
   the integration test that asserts the Edit form's Delete link.
2. **Implement:** `_actions.html.erb`, `delete.html.erb` (Cancel behavior),
   `en.yml` only if copy changes.
3. **Verify:** `bin/rails test:system test/system/students_system_test.rb`
   and `bin/rails test test/integration/students_test.rb`

### Task 8 [Clone]: Subjects and Support placeholder empty states (M-14, M-17)

**Skills:** write-tests, style-ui
**Reference:** audit M-14, M-17; `app/views/subjects/index.html.erb`,
`app/views/support/show.html.erb`, `EmptyStateComponent` in
`docs/COMPONENT_CATALOG.md`, ux-notes "States and interactions" and "Voice and
copy"

**In scope:**

- Subjects: replace "Coming soon" with an empty state that says what will
  live here and when it matters, with no action until a real one exists.
- Support: a real way to get help: a `mailto:` button to
  `Jumpstart.config.support_email` with a subject, plus one line on what to
  include.
- Locale keys for the new copy; remove the old "coming soon" keys if unused.

**NOT in scope:**

- Schedule and Dashboard placeholders (deferred, see "Deferred").

**Build order:**

1. **Test:** integration tests: Subjects renders its empty state; Support
   renders a `mailto:` link.
2. **Implement:** the two views and `en.yml`.
3. **Verify:** `bin/rails test test/integration`

### Task 9 [Clone]: Remove the Notifications page (M-21)

**Skills:** write-tests
**Reference:** audit M-21 and Decision 4; `config/routes/users.rb`
(`resources :notifications`), `app/views/application/_navbar.html.erb` (the
bell)

**In scope:**

- Remove the in-app Notifications page route, its nav dropdown, and the bell.
- Remove or update tests that request `/notifications`.
- Before removing anything else, check `bridge--notification-token` (Hotwire
  Native push tokens) and report what depends on it.

**NOT in scope:**

- The notifiers themselves (ownership transfer, accepted invite): they also
  send email. Keep them.
- Deleting Jumpstart's `lib/` notification views.

**Build order:**

1. **Test:** a request to `/notifications` no longer routes to a page;
   notifier tests still pass.
2. **Implement:** `routes/users.rb`, `_navbar.html.erb`, affected tests.
3. **Verify:** `bin/rails test`
4. **Checkpoint:** (master) when Tasks 7–9 are all done, run
   review-changes-mini covering checkpoint 4. It runs exactly once per
   checkpoint, after the batch returns.

### Task 10 [Master]: Settings tabs: regroup, hide API, fix phone overflow (U-2, U-28, U-29)

**Skills:** write-tests, style-ui
**Reference:** audit U-2, U-28, U-29, Decisions 5 and 6;
`app/views/application/_account_navbar.html.erb`,
`app/views/layouts/sidebar.html.erb`

**In scope:**

- Tabs become Profile, Security, Family, Billing. Security points at today's
  Password page (renamed). The API tab is hidden; the API routes and pages stay.
- "Connected accounts" stays as its own tab until Task 11 folds it into
  Security, so nothing is unreachable in between.
- The tab strip scrolls sideways inside its own `min-w-0` container so the
  Settings column is 390px wide on phones, not ~599px. Recheck form widths.
- Tab label matches page name; "Family" comes from i18n (U-29).
- Files: `_account_navbar.html.erb`, `layouts/sidebar.html.erb`, `en.yml`, and
  the tab-active helper.

**NOT in scope:**

- The Security page's contents (Task 11). API token pages (hidden, not fixed).

**Build order:**

1. **Test:** system test: the Settings tabs show Profile, Security, Family,
   Billing (and Connected accounts for now), not API; at 390px the page does
   not scroll sideways.
2. **Implement:** the four files.
3. **Verify:** `bin/rails test` and the system test above.

### Task 11 [Master]: Security tab: password, two-factor, connected accounts (U-8, U-17, U-18, U-19)

**Skills:** write-tests, style-ui
**Reference:** audit U-8, U-17 to U-19, Decision 5;
`app/views/account/passwords/edit.html.erb`,
`app/views/users/connected_accounts/_connected_account.html.erb`,
`lib/jumpstart/app/views/users/connected_accounts/index.html.erb`

**In scope:**

- One Security page with three spaced sections (48px, 32px on phones):
  change password (including "no password yet"), two-factor, connected
  accounts. Remove the temporary Connected accounts tab from Task 10;
  redirect the old connected accounts index to Security.
- Connected accounts: "Google" (not "Google oauth2"), "Disconnect Google"
  with a confirm naming the consequence, an empty state with "Connect
  Google", `text-muted-foreground` instead of `text-muted`.
- Files: `passwords/edit.html.erb`, `_connected_account.html.erb`, an `app/`
  override or redirect for the connected accounts index, `en.yml`.

**NOT in scope:**

- The two-factor flow itself (Tasks 18 and 19). One `h1` per page (Task 23).

**Build order:**

1. **Test:** system or integration tests: Security shows all three sections;
   Disconnect asks for confirmation; the old connected accounts URL lands on
   Security.
2. **Implement:** the four files.
3. **Verify:** `bin/rails test` and the system tests for Settings.

### Task 12 [Master]: Family page: parents as rows, invite note, delete at the bottom (F-1 to F-5, F-11)

**Skills:** write-tests, style-ui
**Reference:** audit F-1 to F-5, F-11, Decision 7;
`app/views/accounts/show.html.erb`; `docs/product/product-brief.md` (parent
limits)

**In scope:**

- Replace the parents/invitations table with rows: avatar, name and an
  "Owner" badge (no Roles column), email under the name, "…" menu. Rows stack
  on phones. Pending invitations render as rows too, with "Remove invitation"
  in their "…" menu.
- "Invite a parent" is a list-toolbar action. At the second parent it stays;
  a plain note explains the limit (Decision 7).
- "Edit family" moves to the page header. "Delete family" is a distinct
  destructive section at the bottom; its confirm names the family and the
  consequence.
- Copy: "Saved.", "Invitation sent to {email}.", "Remove invitation", "Invite a
  parent" (glossary: parent, not user).
- Files: `accounts/show.html.erb`, a new row partial, `en.yml`.

**NOT in scope:**

- Removing a parent (Task 13), the Edit family modal (Task 14), the invite
  modal (Task 15). Their links keep working as they do today.

**Build order:**

1. **Test:** system test: parents render as rows with no table; Owner badge;
   at two parents the invite button remains and a note explains; Delete family
   confirm names the family; at 390px nothing is clipped.
2. **Implement:** the three files.
3. **Verify:** `bin/rails test` and the Family system tests.
4. **Checkpoint:** run review-changes-mini covering checkpoint 5 (Tasks 10–12).

### Task 13 [Master]: Remove the Edit parent page (F-12 to F-14)

**Skills:** write-tests, style-ui
**Reference:** audit F-12 to F-14, Decision 8;
`app/views/account_users/edit.html.erb`, `_form.html.erb`, the row partial
from Task 12, `config/routes/accounts.rb`

**In scope:**

- Delete the Edit parent page and its form. "Remove {name}" goes in the
  parent row's "…" menu with a confirm that names the consequence: they get a
  new family of their own, and the students stay.
- Close off `edit`/`update` in routes and the controller if nothing else uses
  them. Keep `destroy`.
- Files: the row partial, `routes/accounts.rb`, the account users controller
  (if needed), plus deleting the two views.

**NOT in scope:**

- Ownership transfer (Task 14).

**Build order:**

1. **Test:** request tests: `edit` for an account user is no longer routable;
   removing a parent from the row menu works and keeps the students.
2. **Implement:** as above.
3. **Verify:** `bin/rails test` and the Family system tests.

### Task 14 [Master]: Edit family as a modal; transfer ownership (F-6 to F-10)

**Skills:** write-tests, style-ui
**Reference:** audit F-6 to F-10;
`app/views/accounts/edit.html.erb`, `_form.html.erb`,
`app/views/accounts/transfers/_form.html.erb`, `accounts/show.html.erb`

**In scope:**

- "Edit family" opens a modal from the Family page; no breadcrumb page, no
  red Delete in a header. Buttons bottom right, stacked on phones; "Save".
- Transfer ownership is a bottom section "Transfer ownership to {name}" with a
  confirm that names the parent and the consequence; the picker says "Parent".
  The divider only renders when `can_transfer?`.

**NOT in scope:**

- Delete family (Task 12). Inviting parents (Task 15).

**Build order:**

1. **Test:** system test: Edit family opens a modal and saves with "Saved.";
   transfer shows only when allowed and its confirm names the parent.
2. **Implement:** the four files.
3. **Verify:** `bin/rails test` and the Family system tests.

### Task 15 [Master]: Invite a parent as a modal (F-15 to F-18)

**Skills:** write-tests, style-ui
**Reference:** audit F-15 to F-18;
`app/views/accounts/account_invitations/new.html.erb`, `edit.html.erb`,
`app/controllers/accounts/account_invitations_controller.rb`,
`accounts/show.html.erb`

**In scope:**

- "Invite a parent" and editing an invitation open as modals; sending stays on
  the Family page with a toast. The alert sits above the fields; buttons
  bottom right, stacked on phones.
- Remove the Admin checkbox the controller ignores (it forces `admin: true`).

**NOT in scope:**

- The accept page (Task 24). "Remove invitation" in the row menu (Task 12).

**Build order:**

1. **Test:** system test: invite from the Family page in a modal, see the
   toast and the pending row; the edit modal has no role section.
2. **Implement:** the four files.
3. **Verify:** `bin/rails test` and the Family system tests.
4. **Checkpoint:** run review-changes-mini covering checkpoint 6 (Tasks 13–15).

### Task 16 [Master]: Cancel and resume as modals (F-30 to F-34)

**Skills:** write-tests, style-ui
**Reference:** audit F-30 to F-34;
`app/views/billing/subscriptions/cancels/show.html.erb`, `resumes/show.html.erb`,
`lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb`
(copy into `app/` to override), `billing/subscriptions/_subscription.html.erb`;
`docs/product/product-brief.md` (billing, no refunds)

**In scope:**

- Cancel is one modal: lead with the end date and what stays (the family goes
  to Free; nothing is deleted), the no-refunds note, "Cancel Premium", no
  second generic confirm. A failure shows inline with a next step.
- Resume is a modal with no extra confirm.
- Buttons bottom right, stacked on phones.

**NOT in scope:**

- Billing page layout (Task 20), plan change (Task 17). Stripe calls and
  billing logic do not change.

**Build order:**

1. **Test:** controller/system tests with Stripe stubbed at the HTTP boundary
   (WebMock): cancel modal shows the end date and note; failure renders
   inline; resume works.
2. **Implement:** the four files.
3. **Verify:** `bin/rails test`

### Task 17 [Master]: Plan change as a focused page (F-35, F-36)

**Skills:** write-tests, style-ui
**Reference:** audit F-35, F-36, Decision 9;
`app/views/billing/subscriptions/edit.html.erb`, `plan_changes/show.html.erb`,
the checkout's `minimal` layout, `en.yml`

**In scope:**

- Both plan-change steps use one focused frame (the checkout's `minimal`
  layout) with a "Back to Billing" link. Cove copy replaces the Jumpstart
  line. Buttons bottom right, stacked on phones; "Keep yearly plan".

**NOT in scope:**

- Price or plan logic (see AGENTS.md: no feature logic depends on price).

**Build order:**

1. **Test:** request tests: both steps render with the minimal layout and a
   back link to Billing.
2. **Implement:** the views, the controller(s) that choose the layout, `en.yml`.
3. **Verify:** `bin/rails test`

### Task 18 [Master]: Two-factor: enable on POST, not GET (U-15)

**Skills:** write-tests
**Reference:** audit U-15;
`lib/jumpstart/app/controllers/users/two_factor_controller.rb`,
`lib/jumpstart/app/views/users/two_factor/backup_codes.html.erb`,
`config/routes/users.rb`

**In scope:**

- Today a plain GET to `/user/two_factor/backup_codes` generates and saves
  backup codes and an OTP secret, so a prefetch changes data. Generate them
  on a POST from "Enable"; GET only renders.
- Copy the controller and view into `app/` to override Jumpstart's.

**NOT in scope:**

- The layout (Task 19).

**Build order:**

1. **Test:** integration tests: a GET leaves `otp_secret` and backup codes
   unchanged; the POST creates them; the existing enable/disable flow still
   passes.
2. **Implement:** controller override, view override, route, the Enable
   control on Security.
3. **Verify:** `bin/rails test`
4. **Checkpoint:** run review-changes-mini covering checkpoint 7 (Tasks 16–18).

### Task 19 [Master]: Two-factor setup as a modal flow (U-10, U-12 to U-14, U-16)

**Skills:** write-tests, style-ui
**Reference:** audit U-10, U-12 to U-14, U-16; the `app/` copies from Task 18
(`backup_codes.html.erb`, `verify.html.erb`, the controller)

**In scope:**

- The two steps become one modal with Back/Next, left-aligned, bottom-right
  buttons stacked on phones, headings matching Settings.
- The verify code field has a visible label and an inline error (not only a
  toast).
- "Disable two-factor" moves to the bottom of Security with a specific
  confirm text.

**NOT in scope:**

- Changing how two-factor codes work.

**Build order:**

1. **Test:** system test: enable flow through the modal (Next, verify with a
   code, error inline on a wrong code); disable asks a specific confirm.
2. **Implement:** the two views, the controller (inline error), Security.
3. **Verify:** `bin/rails test` and the Settings system tests.

### Task 20 [Master]: Billing page: one plan summary, one primary, spacing (F-20 to F-23, F-25)

**Skills:** write-tests, style-ui
**Reference:** audit F-20 to F-23, F-25;
`app/views/billing/show.html.erb`, `_plan_state.html.erb`,
`subscriptions/_subscription.html.erb`, `en.yml`; `docs/product/product-brief.md`

**In scope:**

- One plan section with one primary action. Free and Complimentary show no
  empty "subscriptions" block and no contradicting "not currently
  subscribed" line.
- Premium: one summary (name, price, status, renewal date). Cancel moves to a
  bottom destructive area.
- Grace period: one line saying what changes (2 students editable, the
  picker, nothing deleted).
- Section spacing 48px (32px on phones).

**NOT in scope:**

- Date formats and the charges list (Task 21). The h1 (Task 23).

**Build order:**

1. **Test:** integration tests per plan state (Free, Premium, grace period,
   Complimentary): one primary action, the right summary.
2. **Implement:** the four files.
3. **Verify:** `bin/rails test`

### Task 21 [Master]: Billing dates and charges as rows (F-24, F-28)

**Skills:** write-tests, style-ui
**Reference:** audit F-24, F-28; `billing/_charges.html.erb`,
`_plan_state.html.erb`, `subscriptions/cancels/show.html.erb`,
`subscriptions/plan_changes/show.html.erb` (adapt if Tasks 16 and 17 already
changed them); the `friendly_date` helpers

**In scope:**

- Use `friendly_date` / `friendly_date_range` instead of `l(date, :long)` and
  `strftime`.
- Billing history becomes rows (date, amount, "Invoice"/"Receipt" text links)
  that stack on phones; no icon-only download links.

**NOT in scope:**

- The upcoming-invoice page (Task 26).

**Build order:**

1. **Test:** tests that dates render through the helpers and charges render
   as rows with named links.
2. **Implement:** the four files.
3. **Verify:** `bin/rails test`
4. **Checkpoint:** run review-changes-mini covering checkpoint 8 (Tasks 19–21).

### Task 22 [Clone]: Billing email and info forms (F-26, F-27)

**Skills:** write-tests, style-ui
**Reference:** audit F-26, F-27; `billing/_email.html.erb`, `billing/_info.html.erb`

**In scope:**

- The billing email is a regular form: label above, Save bottom right,
  stacked on phones.
- Billing info shows saved text in plain sans, with "Edit" opening a modal.

**NOT in scope:**

- What billing info is collected.

**Build order:**

1. **Test:** system test: edit the billing email; edit billing info in a modal.
2. **Implement:** the two partials (and `en.yml` if copy changes).
3. **Verify:** `bin/rails test`

### Task 23 [Master]: One h1 per Settings page; Profile form layout (U-1, U-3, U-5, U-6, U-9, U-11)

**Skills:** write-tests, style-ui
**Reference:** audit U-1, U-3, U-5, U-6, U-9, U-11;
`app/views/devise/registrations/edit.html.erb`,
`app/views/account/passwords/edit.html.erb` (already restructured by Task 11)

**In scope:**

- One `h1` per Settings page; the tab's own heading becomes an `h2` or goes.
- Profile: buttons bottom right (stacked on phones), sections separated by
  the 48px gap (not a bare `<hr>`), Delete account and Transfer ownership as
  `ButtonComponent`s.
- Confirm the "Email me a link" action gives a toast on success and an inline
  error on failure.

**NOT in scope:**

- The avatar file input (U-4) and the dead reconfirmation alert (U-7): Task 26.

**Build order:**

1. **Test:** each Settings page has exactly one `h1`; the Profile buttons
   stack at 390px.
2. **Implement:** the two views (and the connected accounts/API headings if
   they still show a second `h1`).
3. **Verify:** `bin/rails test` and the Settings system tests.
4. **Checkpoint:** run review-changes-mini covering checkpoint 9 (Tasks 22–23).

### Task 24 [Clone]: Invitation accept page (F-19)

**Skills:** write-tests, style-ui
**Reference:** audit F-19; `app/views/account_invitations/show.html.erb`

**In scope:**

- Left-aligned focused page; `ButtonComponent`s; Decline confirm names the
  family; buttons stacked on phones; sentence-case "Accept invitation".

**NOT in scope:**

- Invitation acceptance logic.

**Build order:**

1. **Test:** request test: the page shows Accept and Decline; Decline's
   confirm names the family.
2. **Implement:** the view (and `en.yml` if copy changes).
3. **Verify:** `bin/rails test`

### Task 25 [Clone]: Checkout heading and a way back (F-41, F-42)

**Skills:** write-tests, style-ui
**Reference:** audit F-41, F-42, F-40 (leave the testimonial);
`app/views/checkouts/show.html.erb`

**In scope:**

- Plain left-aligned `h1` (no synthetic bold on the 400-only serif); a
  visible "Back" link above the title.

**NOT in scope:**

- The testimonial (Decision 10). Opening `/checkout` in a browser (its GET
  creates a Stripe session): test with Stripe stubbed.

**Build order:**

1. **Test:** request test with the Stripe call stubbed (WebMock): the page has
   a Back link and an unbolded left-aligned `h1`.
2. **Implement:** the view.
3. **Verify:** `bin/rails test`

### Task 26 [Master]: Cleanup of dead code (U-4, U-7, F-29, F-37, F-43)

**Skills:** write-tests
**Reference:** audit U-4, U-7, F-29, F-37, F-43

**In scope:**

- Remove the unreachable reconfirmation alert (`User` isn't `:confirmable`),
  the unreachable non-admin billing branch, and the upcoming-invoice page
  Cove never reaches. Leave U-4 (avatar input) and F-43 (non-Stripe checkout
  branches) alone unless asked.
- Files: `devise/registrations/edit.html.erb`, `billing/show.html.erb`,
  `billing/subscriptions/upcomings/show.html.erb` (and its route if unused).

**NOT in scope:**

- Any visible change.

**Build order:**

1. **Test:** existing tests stay green; add one asserting the removed route is
   gone if the page is deleted.
2. **Implement:** the removals.
3. **Verify:** `bin/rails test`
4. **Checkpoint:** run review-changes-mini covering checkpoint 10 (Tasks
   24–26; if Task 26 is skipped, after Task 25).

## Deferred

- **Dashboard, Schedule, first run** (own ticket; drafted in
  `.context/ticket-dashboard-schedule.md`): M-1, M-2, M-15, M-16. M-1 waits
  until school plans exist.
- **M-3** (phone nav): stays as it is.
- **M-18, M-19, M-20, M-22:** no longer apply once the Notifications page is
  removed (Task 9).
- **U-20 to U-27** (API tokens): the API tab is hidden and unused (Task 10),
  so these pages aren't fixed.
- **F-40** (checkout testimonial): stays for now (Decision 10).
- **Audit Fix groups 1 to 3** are done: M-4 to M-12 closed by Tasks 2 to 5,
  except M-11's Edit-to-Delete case, which is Task 7.
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
- Tasks 7–26 wait for the user's approval of this list.
- Tasks 8 and 9 touch different files from each other and from Task 7; they
  can run as one parallel clone batch.
- Task 11 depends on Task 10 (it removes the temporary tab). Tasks 18 and 19
  and Task 23 all touch the Security or Profile pages: run Task 18 after 11,
  Task 19 after 18, and Task 23 after 11 and 19.
- Family pages: Tasks 12, 13, 14, 15 all edit `accounts/show.html.erb` or the
  row partial; run them in that order, one at a time. Task 13 needs Task 12's
  row partial.
- Billing views: Tasks 16, 17, 20, 21, 22 share `_subscription.html.erb`,
  `_plan_state.html.erb`, or the cancel/plan-change views; run them in
  numeric order.
- Tasks 24 and 25 touch different files and can run as one parallel clone
  batch; Task 26 runs after them.
