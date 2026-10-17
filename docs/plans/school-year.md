> Ticket: COV-124
> Branch: feature/cov-124-school-year

# Plan: School year — Year and time off

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add schema and database constraints | Master | ✅ |
| 2 | 1 | 1 | Add the family clock | Master | ✅ |
| 3 | 1 | 2 | Add SchoolYear and fixtures | Master | |
| 4 | 1 | 2 | Add time-off rules and fixtures | Master | |
| 5 | 1 | 3 | Protect past dates and weekday history | Master | |
| 6 | 1 | 3 | Implement school-day counting | subagent | |
| 7 | 1 | 4 | Implement default years | Master | |
| 8 | 1 | 4 | Provision and backfill family years | Master | |
| 9 | 2 | 5 | Normalize signup time zones | Master | |
| 10 | 2 | 5 | Capture the browser time zone | subagent | |
| 11 | 2 | 6 | Apply the family zone to requests | Master | |
| 12 | 2 | 6 | Add Family settings time zone | Master | |
| 13 | 3 | 7 | Build ToggleChipComponent | Master | |
| 14 | 3 | 7 | Register and preview toggle chips | Master | |
| 15 | 3 | 8 | Add Planner routes and Schedule tab | Master | |
| 16 | 3 | 8 | Rename sidebar navigation | Master | |
| 17 | 3 | 9 | Add Edit year endpoints and form | Master | |
| 18 | 3 | 9 | Add school-year summary states | subagent | |
| 19 | 3 | 10 | Add time-off rows and empty state | subagent | |
| 20 | 3 | 10 | Add family-scoped time-off endpoints | Master | |
| 21 | 3 | 11 | Complete time-off modal interactions | subagent | |
| 22 | 3 | 11 | Implement transactional replacement | subagent | |
| 23 | 3 | 12 | Add overlap resolution in the modal | Master | |
| 24 | 3 | 12 | Support server-backed toast actions | Master | |
| 25 | 3 | 13 | Add deletion and Undo | Master | |
| 26 | 3 | 13 | Add the end-date preview endpoint | Master | |
| 27 | 3 | 14 | Connect preview loading and verify Edit year | subagent | |
| 28 | 3 | 14 | Remove retired Schedules files | Master | |
| 29 | 4 | 15 | Update product rules and glossary | Master | |
| 30 | 4 | 15 | Run final acceptance and visual checks | Master | |

## Prerequisites

- **Design:** [docs/designs/school-year.md](../designs/school-year.md). This workspace's design matches the supplied source in `cov-124-school-year`, with the approved clarifications recorded here and in the local design.
- **Prototype:** None. Follow the design's layout, hierarchy, components, and supplied copy.
- **Branch:** `feature/cov-124-school-year` already exists and is checked out. Compare against `origin/main`.
- **Confirmed decisions:**
  - First-year Starts remains editable after the year begins, allowing only an earlier date. Later-year Starts is locked.
  - Replace is available only when **every** overlapping entry starts in the future. If any has started, delete nothing and offer an Edit link within the same modal.
- **Calculated totals:** Default years contain 193 days for 2026–27, 194 for 2027–28, and 190 for 2028–29. Summary examples must use computed values.
- **Existing components:** Reuse `PageHeaderComponent`, link-mode underline `UiTabsComponent`, `UiModalComponent`, `FormFieldComponent`, `ButtonComponent`, `SelectComponent`, `AlertComponent`, `SkeletonComponent`, and `EmptyStateComponent`. Keep the single global `UiToastComponent` host.
- **Execution conventions:** Every behavior change follows test → implementation → verification. Use existing fixtures and account/sign-in helpers. Each task changes at most four files; verify and report progress after each task.
- Before Rails commands, prepend `/Users/jordan/.local/share/mise/shims` to `PATH` and confirm Ruby 4.0.5.
- Run Rails test processes sequentially. Use `bin/rails test test/system/...` for specific system files.
- **Deployable phases:**
  1. Tasks 1–8: data foundation, automatic provisioning, and backfill.
  2. Tasks 9–12: browser capture and family time-zone settings.
  3. Tasks 13–28: complete Planner interface and interactions.
  4. Tasks 29–30: documentation and final acceptance.

## Tasks

### Task 1 [Master]: Add schema and database constraints

**Skills:** safe-migration, write-tests
**Reference:** `db/schema.rb`, `test/migrations/add_complimentary_premium_to_accounts_test.rb`

**In scope:** Two generated migrations, `db/schema.rb`, and `test/migrations/school_year_schema_test.rb`.
**NOT in scope:** Models, callbacks, or data backfill.

**Build order:**

1. **Test:** Assert column types/defaults/nullability, required indexed foreign keys, the unique active-year partial index, year/break date checks, and allowed break sources.
2. **Implement:** Generate `AddTimeZoneToAccounts` and `CreateSchoolYearsAndBreaks`. Add every field in the design, including nullable `school_starts_at`; add no exclusion constraint or repeating-group field.
3. **Verify:** Run `db:migrate`, `db:rollback:primary STEP=2`, `db:migrate`, then `bin/rails test test/migrations/school_year_schema_test.rb`. Inspect schema changes and remove only confirmed generated noise from the three auxiliary schema dumps.

### Task 2 [Master]: Add the family clock

**Skills:** write-tests
**Reference:** `app/models/account.rb`, `test/models/account_test.rb`

**In scope:** `accounts.time_zone` validation and `Account#today`.
**NOT in scope:** Request-zone changes or browser capture.

**Build order:**

1. **Test:** Cover the Mountain fallback, valid Rails zone names, unknown/blank zones, 12:59am versus 1:00am, DST boundaries, and zones on opposite sides of a date boundary.
2. **Implement:** Update `app/models/account.rb` with the exact clock formula from the design.
3. **Verify:** `bin/rails test test/models/account_test.rb`.

Run **review-changes-mini for checkpoint 1, tasks 1–2**, exactly once after both tasks finish. For any parallel checkpoint batch, the master runs the review after the entire batch returns.

### Task 3 [Master]: Add SchoolYear and fixtures

**Skills:** write-tests
**Reference:** `app/models/course.rb`, `test/fixtures/courses.yml`

**In scope:** `app/models/school_year.rb`, `app/models/account.rb`, `test/fixtures/school_years.yml`, and `test/models/school_year_test.rb`.
**NOT in scope:** Weekday history, counting, or default generation.

**Build order:**

1. **Test:** Cover family ownership, active-year lookup/uniqueness, required dates, date ordering, the 12-month limit including leap-year boundaries, and nonempty weekdays restricted to 0–6.
2. **Implement:** Add `Account#school_year`, dependent associations, active status rules, and baseline validations. Create literal, label-linked fixtures for active fixture families.
3. **Verify:** `bin/rails test test/models/school_year_test.rb test/models/account_test.rb`.

### Task 4 [Master]: Add time-off rules and fixtures

**Skills:** write-tests
**Reference:** `app/models/course.rb`, `test/models/course_test.rb`

**In scope:** `app/models/break.rb`, `app/models/school_year.rb`, `test/fixtures/breaks.yml`, and `test/models/break_test.rb`.
**NOT in scope:** Replace, Undo, or repeating time off.

**Build order:**

1. **Test:** Cover one-day entries, required names/dates, year bounds, inclusive overlaps, editing without overlapping oneself, valid sources, and chronological ordering.
2. **Implement:** Enforce new-start restrictions and started-entry edit/delete protections. Reuse an overlap query for later replacement. Allow dependent family deletion to remove protected historical entries.
3. **Verify:** `bin/rails test test/models/break_test.rb test/models/school_year_test.rb`; include family deletion and ended-year mutation coverage.

Run **review-changes-mini for checkpoint 2, tasks 3–4**, following the checkpoint rule above.

### Task 5 [Master]: Protect past dates and weekday history

**Skills:** write-tests
**Reference:** `app/models/school_year.rb`, `test/models/school_year_test.rb`

**In scope:** School-year edit restrictions and persisted weekday history.
**NOT in scope:** Day counting or attendance.

**Build order:**

1. **Test:** Cover pre-start edits, first-year earlier Starts, forbidden later Starts, locked later-year Starts, end-before-today, end-before-time-off, and immutable ended years.
2. **Implement:** Record previous weekdays through yesterday when appropriate. A second change today must preserve the original past setting and replace only today's current setting. Invalid saves must not accumulate history.
3. **Verify:** `bin/rails test test/models/school_year_test.rb`.

### Task 6 [subagent]: Implement school-day counting

**Skills:** write-tests
**Reference:** `app/models/school_year.rb`, the modular concern convention in `lib/jumpstart/app/models/account/billing.rb`

**In scope:** `app/models/school_year/counting.rb`, its inclusion in `school_year.rb`, and `test/models/school_year/counting_test.rb`.
**NOT in scope:** Stored daily records, forecasts, or attendance.

**Build order:**

1. **Test:** Use hand-countable ranges to cover boundaries, historical weekdays, time off, leap days, today exclusion from “so far,” before-Cove days, zero remaining days, and extension previews.
2. **Implement:** All counting APIs from the design. Load time off once per calculation; use `account.today` throughout.
3. **Verify:** `bin/rails test test/models/school_year/counting_test.rb test/models/school_year_test.rb`. Prove weekday changes preserve past counts and `so_far_count + to_go_count == school_days_count`.

Run **review-changes-mini for checkpoint 3, tasks 5–6**, following the checkpoint rule above.

### Task 7 [Master]: Implement default years

**Skills:** write-tests
**Reference:** `app/models/school_year.rb`, design section `SchoolYear::Defaults`

**In scope:** `app/models/school_year/defaults.rb`, its inclusion in `school_year.rb`, and `test/models/school_year/defaults_test.rb`.
**NOT in scope:** Family callbacks or migration execution.

**Build order:**

1. **Test:** Cover the three supplied default date ranges and calculated totals; January signup; summer; before-start and last-day signup; weekends; Thanksgiving; and an in-progress Winter break.
2. **Implement:** `SchoolYear.create_default_for!(account)`, default time off, and the first school day for `tracked_from`. Resolve January against the school year that began in the previous calendar year.
3. **Verify:** `bin/rails test test/models/school_year/defaults_test.rb test/models/school_year/counting_test.rb`.

### Task 8 [Master]: Provision and backfill family years

**Skills:** safe-migration, write-tests
**Reference:** `app/models/user.rb`, `lib/jumpstart/app/models/user/accounts.rb`, `test/models/user_test.rb`

**In scope:** `app/models/user.rb`, `test/models/user_test.rb`, a generated `BackfillSchoolYears` migration, and `test/migrations/backfill_school_years_test.rb`.
**NOT in scope:** Creating a year when accepting an invitation or when reading Planner.

**Build order:**

1. **Test:** Cover atomic family/year/break creation, copying the first parent's zone, fallback, repeated calls, invitation signup, rollback on failure, archived-family exclusion, and backfill reruns.
2. **Implement:** Wrap default-family creation and default-year creation in one transaction. Backfill active families without a year using the same defaults method. Preserve created records on backfill rollback, with an explanatory `AIDEV-NOTE`.
3. **Verify:** Run migrate → primary rollback → migrate, then `bin/rails test test/models/user_test.rb test/migrations/backfill_school_years_test.rb`; run the non-system suite before completing phase 1.

Run **review-changes-mini for checkpoint 4, tasks 7–8**, following the checkpoint rule above.

### Task 9 [Master]: Normalize signup time zones

**Skills:** write-tests
**Reference:** `app/controllers/users/registrations_controller.rb`, `app/controllers/concerns/authentication.rb`

**In scope:** Those two controllers and `test/controllers/users/registrations_controller_test.rb`.
**NOT in scope:** Parent profile settings or changes to OAuth flows.

**Build order:**

1. **Test:** Post valid browser IANA zones, unknown values, and missing values. Assert normalized user values and the resulting family zone; invitation signup must retain the destination family's zone.
2. **Implement:** Permit the signup field and normalize it before the User creation callback runs. Unmappable input becomes blank, allowing the family fallback.
3. **Verify:** `bin/rails test test/controllers/users/registrations_controller_test.rb`.

### Task 10 [subagent]: Capture the browser time zone

**Skills:** write-tests, style-ui
**Reference:** `app/views/devise/registrations/new.html.erb`, existing Stimulus controllers
**Prototype:** None
**Primary tasks:** Parent signs up; browser zone is saved silently.

**In scope:** `app/javascript/controllers/browser_time_zone_controller.js`, the signup view, and `test/system/signup_time_zone_system_test.rb`.
**NOT in scope:** Visible inputs, prompts, or signup redesign.

**Build order:**

1. **Test:** Assert the hidden field receives the browser zone, remains harmless when detection fails, and reconnects safely under Turbo.
2. **Implement:** Populate the hidden field using `Intl.DateTimeFormat().resolvedOptions().timeZone`.
3. **Verify:** `bin/rails test test/system/signup_time_zone_system_test.rb`, then task 9's registration tests.

Run **review-changes-mini for checkpoint 5, tasks 9–10**, following the checkpoint rule above.

### Task 11 [Master]: Apply the family zone to requests

**Skills:** write-tests
**Reference:** `app/models/current.rb`, `app/controllers/concerns/set_current_request_details.rb`

**In scope:** `app/models/current.rb`, `test/models/current_test.rb`, and affected zone expectations in `test/integration/subscription_plan_changes_test.rb`.
**NOT in scope:** Membership resolution or account-cookie switching.

**Build order:**

1. **Test:** Cover family-zone precedence for two parents with different zones, assignment order, account changes, signed-out fallback, and reset between requests.
2. **Implement:** Set `Time.zone` from `Current.account` whenever a family exists. Preserve existing non-family behavior.
3. **Verify:** `bin/rails test test/models/current_test.rb test/helpers/current_helper_test.rb test/integration/subscription_plan_changes_test.rb`.

### Task 12 [Master]: Add Family settings time zone

**Skills:** write-tests, style-ui
**Reference:** `app/views/accounts/_form.html.erb`, `app/components/select_component.rb`
**Prototype:** None
**Primary tasks:** Change the family time zone for everyone in the family.

**In scope:** `app/controllers/accounts_controller.rb`, `app/views/accounts/_form.html.erb`, `test/integration/accounts_edit_test.rb`, and `test/system/account_system_test.rb`.
**NOT in scope:** Parent-specific zone controls.

**Build order:**

1. **Test:** Cover either parent saving, rejected unknown zones, retained invalid input, foreign-family protection, and US-first options without duplicates.
2. **Implement:** Permit `time_zone`; use `SelectComponent` with the design's label/help text and inline error. Keep the dropdown inside the dialog.
3. **Verify:** Run the two test files sequentially, then the non-system suite before completing phase 2.

Run **review-changes-mini for checkpoint 6, tasks 11–12**, following the checkpoint rule above.

### Task 13 [Master]: Build ToggleChipComponent

**Skills:** create-component, rails-blocks-cli, style-ui, write-tests
**Reference:** `app/components/checkbox_component.rb`; RailsBlocks custom-checkbox source named in the design
**Prototype:** None
**Primary tasks:** Select school weekdays using accessible toggle chips.

**In scope:** `app/components/toggle_chip_component.rb`, its ERB template, and `test/components/toggle_chip_component_test.rb`.
**NOT in scope:** JavaScript toggling or a new checkbox framework.

**Build order:**

1. **Test:** Cover native checkbox semantics, label association, name/value, checked/disabled/error states, and forwarded data attributes.
2. **Implement:** Begin `/create-component`, checking app and engine collisions first. Adapt RailsBlocks custom checkboxes using `sr-only`, visible keyboard focus, and brand tokens.
3. **Verify:** `bin/rails test test/components/toggle_chip_component_test.rb`. Complete component registration in task 14 before declaring the component complete.

### Task 14 [Master]: Register and preview toggle chips

**Skills:** create-component, style-ui
**Reference:** `test/components/previews/checkbox_component_preview.rb`, `docs/COMPONENT_CATALOG.md`
**Prototype:** None
**Primary tasks:** Inspect weekday toggle states and keyboard interaction.

**In scope:** `docs/COMPONENT_CATALOG.md`, `test/components/previews/toggle_chip_component_preview.rb`, and `app/views/dev/kitchen_sink/show.html.erb`.
**NOT in scope:** Regenerating unrelated catalog entries or previews.

**Build order:**

1. **Test:** Use task 13's component coverage as the automated gate.
2. **Implement:** Complete `/create-component` registration, including selected/unselected/disabled/error previews and a wrapping fieldset example. Update the kitchen-sink sidebar example to Planner.
3. **Verify:** Rerun component tests; inspect Lookbook and kitchen sink at phone/desktop widths and with keyboard-only input.

Run **review-changes-mini for checkpoint 7, tasks 13–14**, following the checkpoint rule above.

### Task 15 [Master]: Add Planner routes and Schedule tab

**Skills:** write-tests, style-ui
**Reference:** `config/routes.rb`, `app/views/schedules/index.html.erb`, `test/integration/coming_soon_pages_test.rb`
**Prototype:** None
**Primary tasks:** Navigate between Schedule and School year.

**In scope:** `config/routes.rb`, `app/controllers/planners_controller.rb`, `app/views/planners/show.html.erb`, and the existing coming-soon integration test.
**NOT in scope:** Schedule planning functionality.

**Build order:**

1. **Test:** Cover authentication, Planner rendering, real tab URLs, preserved placeholder content, and a permanent `/schedules` → `/planner` redirect.
2. **Implement:** Add singular Planner/School year routes and nested time-off routes. Use `PageHeaderComponent` without actions and underline link tabs.
3. **Verify:** `bin/rails test test/integration/coming_soon_pages_test.rb`.

### Task 16 [Master]: Rename sidebar navigation

**Skills:** write-tests, style-ui
**Reference:** `app/views/application/_sidebar.html.erb`, `app/helpers/application_helper.rb`
**Prototype:** None
**Primary tasks:** Reach Planner and keep it highlighted on both tabs.

**In scope:** Those two files, `test/helpers/application_helper_test.rb`, and `test/system/app_shell_system_test.rb`.
**NOT in scope:** Other sidebar or shell changes.

**Build order:**

1. **Test:** Replace Schedules expectations; cover both Planner paths, descendant boundaries, mobile navigation, and collapsed-sidebar Turbo navigation.
2. **Implement:** Rename the item and helper to Planner and point them at `/planner`.
3. **Verify:** Run the helper and app-shell system tests sequentially.

Run **review-changes-mini for checkpoint 8, tasks 15–16**, following the checkpoint rule above.

### Task 17 [Master]: Add Edit year endpoints and form

**Skills:** write-tests, style-ui
**Reference:** `app/controllers/courses_controller.rb`, `app/views/courses/edit.html.erb`
**Prototype:** None
**Primary tasks:** 1. Change the end date. 2. Change school weekdays. 3. Change the start date.

**In scope:** `app/controllers/school_years_controller.rb`, `app/views/school_years/edit.html.erb`, `app/views/school_years/_form.html.erb`, and `test/integration/school_years_test.rb`.
**NOT in scope:** Extension preview or year-planning actions.

**Build order:**

1. **Test:** Cover both parents, authentication, scoped lookup, forged protected fields, valid edits, retained invalid values, and rejected ended-year edits.
2. **Implement:** Thin show/edit/update actions and a `modal-lazy-content` form. Use native dates, fieldset/legend toggle chips, explicit empty-weekday submission, and the confirmed Starts rules.
3. **Verify:** `bin/rails test test/integration/school_years_test.rb` for edit/update cases; valid saves redirect to the School year tab with “Saved.”

### Task 18 [subagent]: Add school-year summary states

**Skills:** write-tests, style-ui
**Reference:** `app/helpers/application_helper.rb`, `app/views/courses/index.html.erb`
**Prototype:** None
**Primary tasks:** 1. See how many school days are done and to go. 2. Add time off. 3. Edit the year.

**In scope:** `app/helpers/school_years_helper.rb`, `test/helpers/school_years_helper_test.rb`, `app/views/school_years/show.html.erb`, and `app/views/planners/_header.html.erb`.
**NOT in scope:** Attendance, calendar display, or next-year controls.

**Build order:**

1. **Test:** Cover contiguous/noncontiguous weekday labels and running, upcoming, ended, and before-Cove summary text using fixed dates and real counting.
2. **Implement:** Reuse `friendly_date_range`; render calculated totals and exact ended-state copy. Place secondary actions inside the tab, stacked full-width on phones; hide them when ended.
3. **Verify:** `bin/rails test test/helpers/school_years_helper_test.rb test/integration/school_years_test.rb`.

Run **review-changes-mini for checkpoint 9, tasks 17–18**, following the checkpoint rule above.

### Task 19 [subagent]: Add time-off rows and empty state

**Skills:** write-tests, style-ui
**Reference:** `app/views/courses/_course_row.html.erb`
**Prototype:** None
**Primary tasks:** 1. See how many school days are done and to go. 2. Add time off. 3. Edit the year.

**In scope:** `app/views/school_years/_break.html.erb`, the School year show view, `test/integration/school_years_test.rb`, and the Planner show view.
**NOT in scope:** Per-row menus, pagination, or repeating groups.

**Build order:**

1. **Test:** Cover ordered/date-formatted rows, escaped names, editable current/future rows, plain past rows, ended-year behavior, empty state, and conditional inline Add.
2. **Implement:** Match the existing row pattern and lazy edit-modal interaction. Reuse the shared Planner header on both tabs and add the inline restore-error region needed by Undo.
3. **Verify:** `bin/rails test test/integration/school_years_test.rb test/integration/coming_soon_pages_test.rb`.

### Task 20 [Master]: Add family-scoped time-off endpoints

**Skills:** write-tests, style-ui
**Reference:** `app/controllers/courses_controller.rb`, existing lazy-modal forms
**Prototype:** None
**Primary tasks:** 1. Name it and pick dates. 2. Resolve an overlap. 3. Delete it.

**In scope:** `app/controllers/school_years/breaks_controller.rb`, its `new.html.erb` wrapper and `_form.html.erb`, and `test/integration/school_years/breaks_test.rb`.
**NOT in scope:** Replacement or Undo.

**Build order:**

1. **Test:** Cover scoped CRUD, authentication, either parent, ordinary `source: added`, protected fields, missing dates, year bounds, overlaps, and started/ended protections.
2. **Implement:** Thin RESTful actions, shared add/edit form rendering, 422 responses with entered values, and redirect-after-success with the specified toasts.
3. **Verify:** `bin/rails test test/integration/school_years/breaks_test.rb test/models/break_test.rb`.

Run **review-changes-mini for checkpoint 10, tasks 19–20**, following the checkpoint rule above.

### Task 21 [subagent]: Complete time-off modal interactions

**Skills:** write-tests, style-ui
**Reference:** `app/javascript/controllers/`, `test/system/courses_system_test.rb`
**Prototype:** None
**Primary tasks:** 1. Name it and pick dates. 2. Resolve an overlap. 3. Delete it.

**In scope:** The time-off form/wrapper, `app/javascript/controllers/time_off_dates_controller.js`, and `test/system/time_off_system_test.rb`.
**NOT in scope:** Overlap replacement or toast Undo.

**Build order:**

1. **Test:** Cover default dates, moving End when Start passes it, preserving a later End, inline errors, unsaved-change handling, and underway-entry controls.
2. **Implement:** Match the supplied modal copy and responsive form layout. Disable underway Start, show its help text, and hide Delete.
3. **Verify:** `bin/rails test test/system/time_off_system_test.rb`; use navigation waits before querying replaced DOM.

### Task 22 [subagent]: Implement transactional replacement

**Skills:** write-tests
**Reference:** `app/services/family_invitation_acceptance.rb`, `app/models/break.rb`

**In scope:** `app/services/replace_time_off.rb` and `test/services/replace_time_off_test.rb`.
**NOT in scope:** Repeating groups, exclusion constraints, or deleting started entries.

**Build order:**

1. **Test:** Cover one/multiple future overlaps, create/edit, self-exclusion, invalid replacement rollback, newly introduced conflicts, and mixed started/future overlaps.
2. **Implement:** One keyword-based `call` operation returning a result. Re-query overlaps from the year, destroy eligible entries and save the replacement atomically; any started conflict leaves all records intact.
3. **Verify:** `bin/rails test test/services/replace_time_off_test.rb test/models/break_test.rb`.

Run **review-changes-mini for checkpoint 11, tasks 21–22**, following the checkpoint rule above.

### Task 23 [Master]: Add overlap resolution in the modal

**Skills:** write-tests, style-ui
**Reference:** `app/components/alert_component.rb`, the time-off form
**Prototype:** None
**Primary tasks:** 1. Name it and pick dates. 2. Resolve an overlap. 3. Delete it.

**In scope:** The Breaks controller/form and their integration/system tests.
**NOT in scope:** Nested modals or trusting submitted overlap IDs.

**Build order:**

1. **Test:** Cover warning names/dates, singular/plural Replace labels, retained input, Cancel, stale conflicts, and the confirmed started-entry behavior.
2. **Implement:** Render an inline warning listing every overlap. Invoke the replacement service only for explicit Replace; started conflicts offer same-modal Edit links. Escape all user-provided names.
3. **Verify:** Run the time-off integration and system tests sequentially.

### Task 24 [Master]: Support server-backed toast actions

**Skills:** write-tests, style-ui
**Reference:** `app/views/application/_flash.html.erb`, `app/javascript/controllers/flash_toast_controller.js`, existing `ui_toast_controller.js` action callbacks
**Prototype:** None
**Primary tasks:** Use Undo from a routine confirmation.

**In scope:** The flash partial/bridge and `test/system/flash_messages_system_test.rb`.
**NOT in scope:** A second toast host, custom toast HTML, or redesigning the toast controller.

**Build order:**

1. **Test:** Cover a serialized server action submitting once with CSRF and Turbo, escaped text/values, unchanged ordinary flashes, and cleanup across Turbo navigation.
2. **Implement:** Convert server action data into the existing client callback API and a standard form submission.
3. **Verify:** `bin/rails test test/system/flash_messages_system_test.rb`.

Run **review-changes-mini for checkpoint 12, tasks 23–24**, following the checkpoint rule above.

### Task 25 [Master]: Add deletion and Undo

**Skills:** write-tests, style-ui
**Reference:** The Breaks controller, flash bridge, and School year restore-error region
**Prototype:** None
**Primary tasks:** Delete time off and restore it with Undo.

**In scope:** The Breaks controller/form and their integration/system tests.
**NOT in scope:** Soft deletion or restoring an entry that no longer validates.

**Build order:**

1. **Test:** Cover hard deletion, successful restoration with the original source, overlap after deletion, start passing before Undo, foreign-family/tampered payloads, and duplicate submissions.
2. **Implement:** Flash “Time off removed” with Undo. Sign the saved attributes with the family/year identity; POST restoration through create and re-run normal validation. Show the specified failure message inline on School year.
3. **Verify:** Run time-off integration/system tests and flash system tests sequentially.

### Task 26 [Master]: Add the end-date preview endpoint

**Skills:** write-tests, style-ui
**Reference:** `SchoolYear::Counting`, existing Turbo Frame responses
**Prototype:** None
**Primary tasks:** Change the end date and see how many school days it adds.

**In scope:** `config/routes.rb`, `app/controllers/school_years/end_date_previews_controller.rb`, its `show.html.erb`, and `test/integration/school_years/end_date_previews_test.rb`.
**NOT in scope:** Forecast finish dates or saving changes during preview.

**Build order:**

1. **Test:** Cover family scoping, no mutation, singular/plural additions, unchanged/earlier dates, malformed input, and bounded valid date ranges.
2. **Implement:** A RESTful GET show endpoint returning the matching Turbo Frame and using `added_days_if_ended_on`.
3. **Verify:** `bin/rails test test/integration/school_years/end_date_previews_test.rb`.

Run **review-changes-mini for checkpoint 13, tasks 25–26**, following the checkpoint rule above.

### Task 27 [subagent]: Connect preview loading and verify Edit year

**Skills:** write-tests, style-ui
**Reference:** `SkeletonComponent`, existing lazy Turbo Frames
**Prototype:** None
**Primary tasks:** 1. Change the end date. 2. Change school weekdays. 3. Change the start date.

**In scope:** `app/javascript/controllers/school_year_preview_controller.js`, the year form, and `test/system/school_year_system_test.rb`.
**NOT in scope:** Client-side counting or automatic saving.

**Build order:**

1. **Test:** Cover date-change requests, visible loading skeleton with a delayed response, latest-input results, empty preview for earlier dates, keyboard weekday toggles, locked Starts, and inline validation.
2. **Implement:** Update the preview frame URL when Ends changes and show a one-line skeleton while busy. Preserve the form and its unsaved-change behavior.
3. **Verify:** `bin/rails test test/system/school_year_system_test.rb`; assert saved edits update the summary and preserve past counts.

### Task 28 [Master]: Remove retired Schedules files

**Skills:** write-tests
**Reference:** `app/controllers/schedules_controller.rb`, `app/views/schedules/index.html.erb`, `config/locales/en.yml`

**In scope:** Those retired controller/view files and their obsolete locale block.
**NOT in scope:** Marketing uses of “schedules” or Stripe subscription schedules.

**Build order:**

1. **Test:** Confirm existing redirect, Planner, helper, and shell tests describe the replacement behavior.
2. **Implement:** Remove the unreachable controller/view and unused placeholder translations. Search for stale route/helper references.
3. **Verify:** Run coming-soon, School year, and helper tests, then app-shell system tests sequentially.

Run **review-changes-mini for checkpoint 14, tasks 27–28**, following the checkpoint rule above.

### Task 29 [Master]: Update product rules and glossary

**Skills:** None
**Reference:** `AGENTS.md`, `docs/product/product-brief.md`, approved design

**In scope:** Project glossary/clock guidance and the built School year product section.
**NOT in scope:** Global Claude configuration, generated architecture/catalog refreshes, or deferred features.

**Build order:**

1. **Test:** Compare the documentation claims with the implemented behavior and acceptance coverage.
2. **Implement:** Update Planner terminology, Break → time off, the family clock, defaults/signup rules, historical protections, ended-year behavior, time zones, and Free availability.
3. **Verify:** Review the exact documentation diff and run `git diff --check`.

### Task 30 [Master]: Run final acceptance and visual checks

**Skills:** write-tests, style-ui
**Reference:** Design acceptance criteria, `test/system/school_year_system_test.rb`, `test/system/time_off_system_test.rb`

**In scope:** Final acceptance coverage in those two system files and screenshots under `.context/`.
**NOT in scope:** Unrelated refactoring, PR creation, or deployment.

**Build order:**

1. **Test:** Ensure coverage for two-parent shared dates, zone changes, first-year earlier Starts, preserved historical counts, zero remaining days, ended years, replacement rollback, Undo failures, and unchanged Free/Premium access.
2. **Implement:** Add any missing acceptance assertions. Inspect phone and desktop layouts, keyboard focus, chips, native dates, modal scrolling, skeleton loading, long names, and inline errors. Fix only issues within this plan.
3. **Verify:** Run, sequentially:
   - `PARALLEL_WORKERS=4 bin/rails test`
   - `PARALLEL_WORKERS=4 bin/rails test:system`
   - `bin/rails tailwindcss:build`
   - `bin/rubocop`
   - `git diff --check`
   - `git diff origin/main...HEAD` and `git diff`

Record actual output, inspect the screenshots, and report any remaining limitation.

Run **review-changes-mini for checkpoint 15, tasks 29–30**, following the checkpoint rule above. Stop and name `/review-changes` as the next command; do not invoke it automatically.

## Task Dependencies

- Tasks 1–8 form the sequential foundation: schema → clock → models → history/counting → defaults → provisioning/backfill.
- Tasks 9–10 can run in parallel after task 8; they touch different files. Task 10's independent check verifies capture rather than server normalization.
- Task 11 precedes task 12.
- Tasks 13–14 complete `/create-component` before any year form uses toggle chips.
- Tasks 15–16 precede Planner UI acceptance.
- Task 17 establishes year endpoints/form; task 18 supplies the summary page; task 19 adds rows and consolidates the shared header.
- Task 20 establishes time-off endpoints/forms.
- Tasks 21–22 can run in parallel after task 20; their files do not overlap.
- Task 23 depends on tasks 21–22.
- Task 24 can run alongside task 23; task 25 requires both.
- Task 26 requires counting and year endpoints; task 27 requires task 26.
- Task 28 follows completed Planner navigation and forms.
- Tasks 29–30 finish the implementation. Run checkpoint reviews once per group after all grouped tasks finish.
