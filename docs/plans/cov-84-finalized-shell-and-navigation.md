> Ticket: COV-84
> Branch: feature/cov-84-finalized-shell-and-navigation

# Plan: Finalized signed-in shell and sidebar navigation

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Extend `SidebarComponent` for inset styling, active accessibility, and mobile indicators | Master | ✅ |
| 2 | 1 | 1 | Define the failing link-tabs component contract | subagent | ✅ |
| 3 | 1 | 1 | Implement `UiTabsComponent` link mode | subagent | ✅ |
| 4 | 1 | 2 | Add component previews and kitchen-sink examples | subagent | ✅ |
| 5 | 1 | 2 | Regenerate the component catalog and map | Master | ✅ |
| 6 | 2 | 3 | Add the authenticated Schedules placeholder | Master | ✅ |
| 7 | 2 | 3 | Add the authenticated Subjects placeholder | Master | ✅ |
| 8 | 2 | 3 | Add the authenticated Students placeholder | Master | ✅ |
| 9 | 3 | 4 | Centralize sidebar and settings-tab highlighting | Master | ✅ |
| 10 | 3 | 4 | Build the signed-in shell and account menu | Master | ✅ |
| 11 | 3 | 4 | Verify navigation across desktop, collapsed, mobile, and Turbo states | Master | ✅ |
| 12 | 3 | 5 | Replace settings sub-navigation with horizontal link tabs | Master | ✅ |
| 13 | 3 | 5 | Move impersonation controls into the sidebar | Master | ✅ |
| 14 | 4 | 6 | Route ordinary flashes to toasts and Devise flashes to in-card alerts | Master | ✅ |
| 15 | 4 | 6 | Add persistent error-toast behavior and live-region accessibility | Master | ✅ |
| 16 | 4 | 6 | Run responsive, full-suite, lint, and diff verification | Master | ✅ |

## Prerequisites

- Design: [`docs/designs/cov-84-finalized-shell-and-navigation.md`](../designs/cov-84-finalized-shell-and-navigation.md)
- Prototype: [`.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp`](../../.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp) — preserve its sidebar hierarchy, inset panel, footer stack, account card, and horizontal settings tabs; continue using Cove tokens and typography.
- Feature branch exists: `feature/cov-84-finalized-shell-and-navigation`
- The approved design and plan are committed together so execute-plan starts from a clean working tree.
- No migration or data-model work is required.
- The component catalog already contains every required component; no `/prompts:create-component` prerequisite is needed.
- Before Rails commands: `export PATH="/Users/jordan/.local/share/mise/shims:$PATH"` and confirm Ruby 4.0.5.

## Tasks

### Task 1 [Master]: Extend the sidebar component

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `app/components/sidebar_component.rb`, `app/components/sidebar_component.html.erb`, and `app/components/sidebar_component/item_component.html.erb` for the existing Rails Blocks implementation
**Prototype:** `.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp` — match the cream, borderless sidebar surrounding an inset white panel

**In scope:**

- Add an `:inset` variant using literal `bg-background` classes with no sidebar border on desktop or mobile.
- Add `aria-current="page"` to active expanded and collapsed navigation links.
- Add a caller-supplied mobile-toggle indicator slot for the later impersonation dot.
- Preserve existing variants and panel-mode behavior unchanged.

**NOT in scope:**

- Product-specific navigation, account-menu markup, or impersonation logic.
- Broad `data-turbo-permanent` behavior or changes to vendored Jumpstart files.

**Build order:**

1. **Test:** Extend `test/components/sidebar_component_test.rb` for inset desktop/mobile surfaces, unchanged legacy variants, active/inactive `aria-current`, and the optional mobile indicator.
2. **Implement:** Update `app/components/sidebar_component.rb`, `app/components/sidebar_component.html.erb`, and `app/components/sidebar_component/item_component.html.erb`.
3. **Verify:** `bin/rails test test/components/sidebar_component_test.rb`

### Task 2 [subagent]: Define the link-tabs contract

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `app/components/ui_tabs_component.rb`, `app/components/ui_tabs_component.html.erb`, and the nested tab component
**Prototype:** `.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp` — tabs are page links, not same-page panels

**In scope:**

- Add a failing component test for an explicit `mode: :links`.
- Require real anchors with `href`, caller-computed active state, and one `aria-current="page"`.
- Require no `ui-tabs` controller, tablist/tab/tabpanel semantics, click-prevention action, panels, or initial `opacity-0`.
- Require natural-width horizontal items inside an overflow-scrollable row.

**NOT in scope:**

- Production implementation.
- Changes to the existing panel-tabs contract or Stimulus controller.

**Build order:**

1. **Test:** Add the link-mode contract to `test/components/ui_tabs_component_test.rb`.
2. **Implement:** Make no production change; capture the expected RED failure.
3. **Verify:** `bin/rails test test/components/ui_tabs_component_test.rb` must fail only on the new link-mode assertions.

### Task 3 [subagent]: Implement link tabs

**Skills:** `write-tests`, `style-ui`
**Reference:** Follow the RED contract in `test/components/ui_tabs_component_test.rb`

**In scope:**

- Add explicit `:panels` and `:links` modes.
- Extend `with_tab` with `href:` and `active:` in link mode.
- Render semantic navigation anchors with existing tab styles and horizontal overflow.
- Leave panel mode output and `ui_tabs_controller.js` unchanged.

**NOT in scope:**

- Inferring mode from panel count.
- Client-side navigation switching or URL-hash behavior for link tabs.

**Build order:**

1. **Test:** Run the Task 2 test and confirm its expected RED state.
2. **Implement:** Update `app/components/ui_tabs_component.rb`, `app/components/ui_tabs_component.html.erb`, `app/components/ui_tabs_component/tab_component.rb`, and `app/components/ui_tabs_component/tab_component.html.erb`.
3. **Verify:** `bin/rails test test/components/ui_tabs_component_test.rb`

After Tasks 1–3 are complete, the master runs `review-changes-mini` exactly once for checkpoint 1.

### Task 4 [subagent]: Showcase the component APIs

**Skills:** `style-ui`
**Reference:** Follow existing preview patterns in `test/components/previews/` and the navigation section of `app/views/dev/kitchen_sink/show.html.erb`
**Prototype:** `.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp`

**In scope:**

- Add an inset-sidebar preview.
- Add a horizontal link-tabs preview with an active destination.
- Add both examples to the kitchen sink without rendering a second global toast host.

**NOT in scope:**

- Production shell markup.
- Direct manual edits to generated catalog prose in this task.

**Build order:**

1. **Test:** Confirm the existing component tests pass before preview changes.
2. **Implement:** Update `test/components/previews/sidebar_component_preview.rb`, `test/components/previews/ui_tabs_component_preview.rb`, and `app/views/dev/kitchen_sink/show.html.erb`.
3. **Verify:** `bin/rails test test/components/sidebar_component_test.rb test/components/ui_tabs_component_test.rb test/integration/dev/kitchen_sink_test.rb`

### Task 5 [Master]: Update the component catalog

**Skills:** `source-command-update-catalog`
**Reference:** Read the Sidebar and UiTabs sections already present in `docs/COMPONENT_CATALOG.md`

**In scope:**

- Run `/prompts:update-catalog` once the two component APIs and previews are final.
- Document `SidebarComponent`’s inset variant/mobile indicator and `UiTabsComponent`’s explicit link mode.
- Refresh `docs/architecture/component-map.mermaid` if the catalog workflow changes it.

**NOT in scope:**

- Adding new components.
- Editing unrelated catalog entries.

**Build order:**

1. **Test:** Confirm both component suites pass before regeneration.
2. **Implement:** Run `/prompts:update-catalog` and review only the resulting catalog/map changes.
3. **Verify:** Re-run both component tests and inspect `git diff -- docs/COMPONENT_CATALOG.md docs/architecture/component-map.mermaid`.

Run `review-changes-mini` exactly once for checkpoint 2 after Tasks 4–5.

### Task 6 [Master]: Add the Schedules placeholder

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `app/views/dashboard/show.html.erb` and `test/components/previews/empty_state_component_preview/with_lucide_icon.html.erb`

**In scope:**

- Add `resources :schedules, only: :index` to `config/routes.rb`.
- Add an authenticated `SchedulesController#index`.
- Render an `h1` “Schedules” and `EmptyStateComponent` with the `calendar` icon, “Coming soon,” and “Schedule planning will be available here.”
- Verify unauthenticated visitors are redirected to sign-in.

**NOT in scope:**

- Schedule models, CRUD, account scoping, or Pundit.
- Shared abstractions for the three intentionally simple controllers.

**Build order:**

1. **Test:** Add the Schedules cases to `test/integration/coming_soon_pages_test.rb`: route, guest redirect, signed-in success, title, empty state, description, and icon.
2. **Implement:** Update `config/routes.rb`; create `app/controllers/schedules_controller.rb` and `app/views/schedules/index.html.erb`.
3. **Verify:** `bin/rails test test/integration/coming_soon_pages_test.rb`

### Task 7 [Master]: Add the Subjects placeholder

**Skills:** `write-tests`, `style-ui`
**Reference:** Follow the tested Schedules slice from Task 6

**In scope:**

- Add `resources :subjects, only: :index`.
- Add authenticated `SubjectsController#index`.
- Render an `h1` “Subjects” and `EmptyStateComponent` with `book-open`, “Coming soon,” and “Subject management will be available here.”

**NOT in scope:**

- Subject models, CRUD, account scoping, or Pundit.
- Refactoring the Schedules implementation.

**Build order:**

1. **Test:** Add equivalent Subjects behavior to `test/integration/coming_soon_pages_test.rb`.
2. **Implement:** Update `config/routes.rb`; create `app/controllers/subjects_controller.rb` and `app/views/subjects/index.html.erb`.
3. **Verify:** `bin/rails test test/integration/coming_soon_pages_test.rb`

### Task 8 [Master]: Add the Students placeholder

**Skills:** `write-tests`, `style-ui`
**Reference:** Follow the tested Schedules and Subjects slices

**In scope:**

- Add `resources :students, only: :index`.
- Add authenticated `StudentsController#index`.
- Render an `h1` “Students” and `EmptyStateComponent` with `users`, “Coming soon,” and “Student management will be available here.”

**NOT in scope:**

- Student models, limits, premium rules, CRUD, account scoping, or Pundit.
- Any implementation from the future Students ticket.

**Build order:**

1. **Test:** Add equivalent Students behavior to `test/integration/coming_soon_pages_test.rb`.
2. **Implement:** Update `config/routes.rb`; create `app/controllers/students_controller.rb` and `app/views/students/index.html.erb`.
3. **Verify:** `bin/rails test test/integration/coming_soon_pages_test.rb`

Run `review-changes-mini` exactly once for checkpoint 3 after Tasks 6–8.

### Task 9 [Master]: Centralize navigation highlighting

**Skills:** `write-tests`
**Reference:** Read `lib/jumpstart/app/helpers/nav_helper.rb` for path matching, but keep the vendored helper unchanged

**In scope:**

- Add app-owned, boundary-safe predicates to `ApplicationHelper` for sidebar and settings-tab activity.
- Cover Dashboard, the three product pages, Profile, Password/two-factor, Connected accounts, Billing descendants, Family descendants, API tokens, and optional Referrals.
- Explicitly leave Pricing and `/account_invitations/*` unmatched.

**NOT in scope:**

- Editing `lib/jumpstart`.
- Treating raw string prefixes such as `/account` as sufficient matching.

**Build order:**

1. **Test:** Add `test/helpers/application_helper_test.rb` with user-facing cases such as “settings stays highlighted across family member pages” and “invitation acceptance has no active sidebar item.”
2. **Implement:** Extend `app/helpers/application_helper.rb` with exact-or-descendant path matching and named navigation predicates.
3. **Verify:** `bin/rails test test/helpers/application_helper_test.rb`

### Task 10 [Master]: Build the signed-in shell and account menu

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `app/views/layouts/application.html.erb`, `_navbar.html.erb`, `_user_menu.html.erb`, `_dev_menu.html.erb`, and `_footer.html.erb`
**Prototype:** `.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp`

**In scope:**

- Branch the application layout so signed-in non-native pages use `SidebarComponent` and an inset white rounded content panel.
- Keep the existing navbar/footer path unchanged for signed-out and Hotwire Native requests.
- Add Cove logo, Home/Schedules/Subjects/Students, same-tab superadmin Admin, Support, Settings, and expanded/collapsed account triggers.
- Add an account dropdown with conditional Connected accounts/Billing, Family, development-only Jumpstart links, Sign out, Privacy, and Terms.
- Retain the existing top impersonation banner temporarily until Task 13 replaces it.

**NOT in scope:**

- Notifications in the new shell.
- Announcements/About links, a sidebar Pricing link, or edits to vendored partials.
- Styling changes outside the approved prototype hierarchy.

**Build order:**

1. **Test:** Update `test/integration/public_test.rb` so guests retain the existing navbar/footer while signed-in pages render the sidebar and omit the top bar, bell, and footer.
2. **Implement:** Update `app/views/layouts/application.html.erb`; create `app/views/application/_sidebar.html.erb` and `app/views/application/_sidebar_account_menu.html.erb`.
3. **Verify:** `bin/rails test test/integration/public_test.rb`

### Task 11 [Master]: Verify shell interaction and Turbo behavior

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `test/system/app_shell_system_test.rb`, `test/system/turbo_resilience_system_test.rb`, and `app/javascript/controllers/sidebar_controller.js`
**Prototype:** `.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp`

**In scope:**

- Replace old signed-in top-bar tests with sidebar navigation, active state, same-tab Admin, and absence of notifications/footer.
- Exercise the account menu expanded, collapsed, and inside the mobile drawer.
- Verify collapsed state survives Turbo navigation without showing stale active highlights.
- Retarget Turbo-resilience frame tests to a test-created remote frame rather than the retired notifications bell.
- Make strictly scoped caller/controller corrections if those tests expose cloning or state-restoration defects.

**NOT in scope:**

- Restoring the notifications bell.
- Making the entire sidebar `data-turbo-permanent`.
- Changing Turbo-resilience production behavior unrelated to the retired bell.

**Build order:**

1. **Test:** Rewrite `test/system/app_shell_system_test.rb` and the notification-coupled portions of `test/system/turbo_resilience_system_test.rb`.
2. **Implement:** Adjust `app/views/application/_sidebar.html.erb`, `app/views/application/_sidebar_account_menu.html.erb`, or `app/javascript/controllers/sidebar_controller.js` only where the new interaction tests require it.
3. **Verify:** Run `bin/rails test:system test/system/app_shell_system_test.rb`, then `bin/rails test:system test/system/turbo_resilience_system_test.rb` sequentially.

Run `review-changes-mini` exactly once for checkpoint 4 after Tasks 9–11.

### Task 12 [Master]: Replace settings navigation with link tabs

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `lib/jumpstart/app/views/application/_account_navbar.html.erb` and `lib/jumpstart/app/views/layouts/sidebar.html.erb`, then create app-owned overrides
**Prototype:** `.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp`

**In scope:**

- Override `_account_navbar` with `UiTabsComponent` link mode.
- Render Profile, Password, conditional Connected accounts/Billing, Family, API tokens, and optional Referrals.
- Map two-factor pages to Password and descendant pages to their correct tab.
- Override `layouts/sidebar` so tabs sit above content and scroll horizontally on narrow screens.

**NOT in scope:**

- Editing individual settings pages that already provide `content_for :sidebar`.
- Editing either vendored Jumpstart view.
- Using client-side tab panels.

**Build order:**

1. **Test:** Add `test/integration/settings_navigation_test.rb` covering links, conditions, active mappings, semantic anchors, horizontal overflow, and absence of tabpanel markup.
2. **Implement:** Create `app/views/application/_account_navbar.html.erb` and `app/views/layouts/sidebar.html.erb`.
3. **Verify:** `bin/rails test test/integration/settings_navigation_test.rb`

### Task 13 [Master]: Move impersonation into the shell

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `lib/jumpstart/app/helpers/flash_helper.rb` and `lib/jumpstart/app/controllers/madmin/user/impersonates_controller.rb`; reuse their routes without editing them

**In scope:**

- Render an expanded warning card above the account button with linked user name and Stop action.
- Add a warning ring and tooltip to the collapsed avatar.
- Fill the Sidebar mobile-indicator slot with the warning dot and show the expanded card in the drawer.
- Remove the full-width impersonation banner only from the signed-in application shell.
- Keep the existing banner in `minimal` layout.

**NOT in scope:**

- Changing impersonation authorization or routes.
- Hard-coded warning colors or edits to `FlashHelper`.

**Build order:**

1. **Test:** Extend `test/system/app_shell_system_test.rb` by impersonating through Madmin and asserting the expanded card/Stop action, collapsed ring/tooltip, mobile dot, and successful stop.
2. **Implement:** Create `app/views/application/_sidebar_impersonation.html.erb` and update `app/views/application/_sidebar.html.erb` plus the signed-in branch of `app/views/layouts/application.html.erb`.
3. **Verify:** `bin/rails test:system test/system/app_shell_system_test.rb`

Run `review-changes-mini` exactly once for checkpoint 5 after Tasks 12–13.

### Task 14 [Master]: Route flashes by layout context

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `app/views/application/_flash.html.erb`, `app/views/layouts/minimal.html.erb`, and `app/controllers/concerns/authentication.rb`

**In scope:**

- Normalize string and hash flashes into the existing toast bridge on ordinary application and non-Devise minimal pages.
- Add an inline mode that renders `AlertComponent` once for signed-out Devise pages.
- Place the inline alert inside the centered auth content wrapper.
- Preserve inline validation errors and the single global `UiToastComponent` host.
- Keep the minimal-layout impersonation banner.

**NOT in scope:**

- Changing how controllers or Devise set flash values.
- Turning checkout, agreements, or signup completion into inline-alert pages.
- Changing toast timing in this task.

**Build order:**

1. **Test:** Update `test/integration/inline_alert_consistency_test.rb` and `test/system/login_system_test.rb` for ordinary toast bridges, in-card Devise errors/notices, and no duplicate toast.
2. **Implement:** Update `app/views/application/_flash.html.erb` and `app/views/layouts/minimal.html.erb`.
3. **Verify:** Run `bin/rails test test/integration/inline_alert_consistency_test.rb`, then `bin/rails test:system test/system/login_system_test.rb`.

### Task 15 [Master]: Make error toasts persistent and accessible

**Skills:** `write-tests`, `style-ui`
**Reference:** Read `app/javascript/controllers/flash_toast_controller.js` and `app/javascript/controllers/ui_toast_controller.js`

**In scope:**

- Dispatch an explicit auto-dismiss policy from the Rails flash bridge.
- Keep alert/error toasts until the user closes them; retain auto-dismiss for notice/success.
- Give errors assertive `role="alert"` semantics and non-errors polite `role="status"` semantics.
- Replace the span-based close control with a labeled button.
- Verify Turbo visits do not duplicate or retain stale toasts.
- Update the family-invitation flow to expect a toast instead of an inline banner.

**NOT in scope:**

- A new toast component or another global host.
- Changes to unrelated Turbo-resilience notices.
- Unescaped custom HTML in toast content.

**Build order:**

1. **Test:** Add `test/system/flash_messages_system_test.rb` for short-duration notice dismissal, persistent/closable error behavior, live-region semantics, and Turbo cleanup; update `test/system/team_invitation_system_test.rb`.
2. **Implement:** Update `app/javascript/controllers/flash_toast_controller.js` and `app/javascript/controllers/ui_toast_controller.js`.
3. **Verify:** Run the two affected system-test files sequentially.

### Task 16 [Master]: Run final verification

**Skills:** `review-changes-mini`
**Reference:** Re-read the COV-84 acceptance criteria and inspect `git diff origin/main...`

**In scope:**

- Exercise Dashboard, Profile, Password, Billing, Family, and signed-in Pricing at 375×812, 768×1024, and 1440×900.
- Verify horizontal settings-tab scrolling, mobile drawer behavior, account menu in every sidebar state, correct highlights, no signed-in top bar/bell/footer, and no page overflow.
- Verify the signed-out navbar/footer and non-Devise minimal layouts remain unchanged.
- Run the complete Rails, system, lint, and diff gates sequentially.

**NOT in scope:**

- Visual redesign or unrelated cleanup.
- Product functionality for schedules, subjects, or students.
- Starting `/prompts:review-changes` or `/prompts:close-out`; the user invokes those separately.

**Build order:**

1. **Test:** Run focused component, helper, integration, and system tests for all changed areas.
2. **Implement:** Make only acceptance-blocking corrections, keeping any correction batch within the seven-file checkpoint limit.
3. **Verify:** Run, sequentially:
   - `bin/rails test`
   - `bin/rails test:system`
   - `bin/rubocop`
   - `git diff --check`
   - `git diff origin/main...`
   - `git status --short`

Run `review-changes-mini` exactly once for checkpoint 6 after Tasks 14–16 have all completed.

## Task Dependencies

- Tasks 1 and 2 are independent and may run in parallel.
- Task 3 depends on Task 2’s RED contract.
- Task 4 depends on Tasks 1 and 3; Task 5 depends on Task 4.
- Tasks 6–8 are sequential because each updates `config/routes.rb` and `test/integration/coming_soon_pages_test.rb`.
- Task 9 may begin after the component foundation, but Tasks 10–11 also require Tasks 6–8 so their route helpers exist.
- Task 10 depends on Tasks 1, 3, and 9; Task 11 depends on Task 10.
- Task 12 depends on Tasks 3, 9, and 10.
- Task 13 depends on Tasks 1 and 10–11.
- Task 14 depends on the finalized application shell; Task 15 depends on Task 14’s server-rendered bridge contract.
- Task 16 depends on every preceding task.
- Rails and system-test processes must remain sequential in this linked worktree.
