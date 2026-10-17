> Ticket: COV-125
> Branch: feature/cov-125-school-year-start-time-and-dev-tools

# Plan: School year — Start time and dev tools

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Build the start-time endpoint and modal | Master | ✅ |
| 2 | 1 | 1 | Add the action to both Planner tabs | Master | ✅ |
| 3 | 1 | 2 | Verify start-time behavior and update header guidance | subagent | ✅ |
| 4 | 2 | 3 | Implement the development clock and family-clock fallback | Master | ✅ |
| 5 | 2 | 4 | Build the development clock page and guards | Master | ✅ |
| 6 | 2 | 5 | Create the dev clock strip component | Master | ✅ |
| 7 | 2 | 6 | Mount the strip and verify clock flows | subagent | ✅ |
| 8 | 3 | 7 | Share existing default school-year calendar rules | Master | ✅ |
| 9 | 3 | 7 | Add the three seed families | subagent | ✅ |
| 10 | 3 | 7 | Complete final validation | Master | ✅ |

Phase 1 delivers Shape of the day. Phase 2 delivers the development clock. Phase 3 delivers the seed scenarios. Each phase can ship independently after its checkpoints pass.

## Prerequisites

- Design: [`docs/designs/school-year-start-time-and-dev-tools.md`](../designs/school-year-start-time-and-dev-tools.md). The local copy matches the supplied design, with the approved first-day seed decision recorded.
- Prototype: None.
- Feature branch exists: `feature/cov-125-school-year-start-time-and-dev-tools`.
- Incorporate the approved seed decision: use the most recent August-start year; omit the extra past time-off entry only on its first day.
- Existing components: `PageHeaderComponent`, `FormFieldComponent`, `ButtonComponent`, and `UiModalComponent` through `application/lazy_modal`.
- The catalog has no suitable dev clock strip. Task 6 is the required `/create-component` prerequisite.
- Before Rails commands, prepend `/Users/jordan/.local/share/mise/shims` to `PATH` and confirm Ruby `4.0.5`.
- Follow TDD for new behavior, use existing fixtures, and keep Rails test processes sequential. Tests must use temporary clock files and preserve any real development override.
- No migrations, new gems, or branch changes.

## Tasks

### Task 1 [Master]: Build the start-time endpoint and modal

**Skills:** write-tests, style-ui

**Reference:** `app/controllers/school_years_controller.rb`, `app/controllers/concerns/current_school_year.rb`, `app/controllers/concerns/referrer_path.rb`, `app/views/school_years/_form.html.erb`

**Prototype:** None — follow the approved design and existing Edit year modal.

**Primary tasks:** 1. Set or change the start time. 2. Clear it.

**In scope:**

- Four files: `config/routes.rb`, new `app/controllers/school_years/shape_of_days_controller.rb`, new `app/views/school_years/shape_of_days/edit.html.erb`, and new `test/integration/school_years/shape_of_days_test.rb`.
- Singular `/planner/school_year/shape_of_day`, supporting `edit` and `update`.
- Include `CurrentSchoolYear`; apply `forbid_ended_year` to both actions. Permit only `school_starts_at`.
- Return successful saves to the originating Planner tab using `ReferrerPath` and an exact allowlist of the two tab paths; default to School year.
- Render the complete form inside `modal-lazy-content`, using `FormFieldComponent`, `form.time_field`, and existing Cancel/Save buttons.

**NOT in scope:** Year dates, weekdays, time periods, estimated-time displays, or Premium gating.

**Build order:**

1. **Test:** Cover authentication, either parent, family isolation, setting/changing/clearing, tampered time casting to `nil`, and ignored ownership/date/weekday parameters. Assert 403 for ended-year GET and PATCH, including a year ending after the modal was opened. Exercise an actual validation failure and assert this modal re-renders with inline errors and status 422.
2. **Implement:** Add the route, controller, and template. Preserve exact copy: “Shape of the day”, “School usually starts at”, “Optional. Cove uses this to estimate times on your day.”, and “Saved.” Use the existing phone button order and a sans serif modal heading.
3. **Verify:** `bin/rails test test/integration/school_years/shape_of_days_test.rb`.

### Task 2 [Master]: Add the action to both Planner tabs

**Skills:** write-tests, style-ui

**Reference:** `app/views/planners/_header.html.erb`, `app/controllers/planners_controller.rb`, `app/components/page_header_component.html.erb`, `SchoolYearsController#set_layout`

**Prototype:** None.

**Primary tasks:** 1. Open Shape of the day.

**In scope:**

- Three files: `app/controllers/planners_controller.rb`, `app/views/planners/_header.html.erb`, and Task 1’s integration test.
- Load the current family’s year on Schedule through `CurrentSchoolYear`.
- Add the secondary-styled “Shape of the day” lazy-modal trigger to `PageHeaderComponent`’s `primary_action` slot; hide it for ended years.
- Preserve the full Schedule page and toast host when a modal save redirects with a Turbo Frame header.

**NOT in scope:** Schedule content, tab-specific actions, or general changes to `PageHeaderComponent`.

**Build order:**

1. **Test:** Assert both tabs expose the same action for active years and hide it for ended years. Cover successful returns to each tab, untrusted/malformed referrer fallback, and complete destination layouts with their toast host.
2. **Implement:** Update the shared header and Planner controller, following School year’s existing frame-redirect layout handling.
3. **Verify:** `bin/rails test test/integration/school_years/shape_of_days_test.rb test/integration/school_years_test.rb`.
4. Run **review-changes-mini for Checkpoint 1, Tasks 1–2**, exactly once after both tasks finish. For a parallel batch, the master runs it after the entire batch returns.

### Task 3 [subagent]: Verify start-time behavior and update header guidance

**Skills:** write-tests, style-ui

**Reference:** `test/system/school_year_system_test.rb`, `test/models/school_year_test.rb`, `docs/product/ux-notes.md`

**Prototype:** None.

**Primary tasks:** 1. Open Shape of the day. 2. Set or change the start time. 3. Clear it.

**In scope:**

- Three files: new `test/system/shape_of_day_system_test.rb`, `test/models/school_year_test.rb`, and `docs/product/ux-notes.md`.
- Browser coverage for both tabs, prefilled values, save/clear, modal closure, “Saved.” toast, cancellation, and existing unsaved-change protection.
- Regression coverage that family-zone changes preserve the stored wall-clock hour/minute and ended years refuse start-time changes.
- Apply precisely the two approved Header edits about single-item menus and phone actions.

**NOT in scope:** Changing the shared header component’s overflow behavior, other product-doc edits, or new start-time validation.

**Build order:**

1. **Test:** Add browser coverage at desktop and 390px phone widths. Assert the visible labeled header button, accessible field, and phone Save-above-Cancel order. Add model regression assertions for casting, ended-year protection, and zone changes.
2. **Implement:** Make the two UX Notes edits. Reuse existing UI behavior; report any unexpected regression before expanding scope.
3. **Verify:** Sequentially run `bin/rails test test/models/school_year_test.rb` and `bin/rails test test/system/shape_of_day_system_test.rb`.
4. Master runs **review-changes-mini for Checkpoint 2, Task 3**, exactly once after the task returns, or after the entire parallel batch returns if applicable.

### Task 4 [Master]: Implement the development clock and family-clock fallback

**Skills:** write-tests

**Reference:** `app/models/account.rb`, `test/models/account_test.rb`


**In scope:**

- Four files: new `app/models/dev_clock.rb`, new `test/models/dev_clock_test.rb`, `app/models/account.rb`, and `test/models/account_test.rb`.
- `DevClock.today`, `.set(date)`, and `.clear`, backed by `tmp/dev_today`.
- Read overrides only in development; missing, unreadable, and invalid files return `nil`.
- Extract the current family-clock calculation into `Account#real_today`; make `today` return `DevClock.today || real_today`. The dev page can then show real today without duplicating the calculation.

**NOT in scope:** Changing system time, timestamp generation, other date callers, or the existing 1am/DST semantics.

**Build order:**

1. **Test:** Use temporary files to cover persistence, replacement, clearing an absent file, junk/unreadable input, and no reads outside development. Assert every family shares an override, it does not tick, and clearing restores zone-specific behavior. Retain the existing 1am and DST checks.
2. **Implement:** Write ISO dates, read afresh rather than memoizing, and handle read/parsing failures. Keep test files isolated from `tmp/dev_today`.
3. **Verify:** `bin/rails test test/models/dev_clock_test.rb test/models/account_test.rb`.
4. Run **review-changes-mini for Checkpoint 3, Task 4**, exactly once; the master handles it after all tasks return if executed in a parallel batch.

### Task 5 [Master]: Build the development clock page and guards

**Skills:** write-tests, style-ui

**Reference:** `config/routes.rb`, `app/controllers/dev/typography_controller.rb`, `app/views/dev/typography/show.html.erb`

**Prototype:** None — plain dev-tools page.

**Primary tasks:** 1. Set a pretend date. 2. Clear it.

**In scope:**

- Four files: `config/routes.rb`, new `app/controllers/dev/clocks_controller.rb`, new `app/views/dev/clocks/show.html.erb`, and new `test/integration/dev/clocks_test.rb`.
- Singular `/dev/clock` with `show`, `update`, and `destroy`, registered only inside `Rails.env.local?`.
- Controller returns 404 outside development, before authentication; development requests require sign-in to identify the family.
- Show real family today, current override, a labeled date field, Set, and conditional Clear.
- Set returns to the clock page. Clear returns to the same-origin referring page, falling back to the clock page.

**NOT in scope:** Session-based clocks, per-family overrides, navigation additions, or production access.

**Build order:**

1. **Test:** Cover the development flow, invalid/empty dates preserving the existing override, real-date display while overridden, same-origin Clear returns, and rejected external returns. Independently test route exclusion outside local environments and controller 404s in test, staging, and production. Use isolated route sets for route-construction checks.
2. **Implement:** Use Rails form helpers, `FormFieldComponent`, and `ButtonComponent`. Format dates as `17 Oct 2026`. Include exactly: “Every family's today uses this date until you clear it.” and “Edits made while pretending stay when you clear it. Reseed if data looks odd.”
3. **Verify:** `bin/rails test test/integration/dev/clocks_test.rb`.
4. Run **review-changes-mini for Checkpoint 4, Task 5**, exactly once; the master handles it after all tasks return if executed in a parallel batch.

### Task 6 [Master]: Run /create-component to add DevClockStripComponent

**Skills:** create-component, write-tests, style-ui

**Reference:** `docs/COMPONENT_CATALOG.md`, `test/components/alert_component_test.rb`, `test/components/previews/alert_component_preview.rb`

**Prototype:** None — slim strip specified in the design.

**Primary tasks:** Change or clear the pretend date from a signed-in page.

**In scope:**

- Four component files: `app/components/dev_clock_strip_component.rb`, its `.html.erb` template, `test/components/dev_clock_strip_component_test.rb`, and `test/components/previews/dev_clock_strip_component_preview.rb`.
- Follow `/create-component`, including its RailsBlocks check and app/engine name-collision checks.
- Render only in development with an active override.
- Display “Dev clock: pretending it's 14 Oct 2026 · Change · Clear”; link Change to `/dev/clock` and submit Clear through a real form.

**NOT in scope:** Mounting the component, adding Stimulus, or adapting the generic alert into a new product-wide variant.

**Build order:**

1. **Test:** Assert conditional rendering, exact date/text, Change destination, and Clear’s DELETE form.
2. **Implement:** Build a compact, wrapping strip with existing design tokens and `ButtonComponent`. Provide preview state without writing the real override file.
3. **Verify:** `bin/rails test test/components/dev_clock_strip_component_test.rb`.
4. Run **review-changes-mini for Checkpoint 5, Task 6**, exactly once; the master handles it after all tasks return if executed in a parallel batch.

### Task 7 [subagent]: Mount the strip and verify clock flows

**Skills:** write-tests, style-ui

**Reference:** `app/views/layouts/application.html.erb`, `app/views/application/_sidebar.html.erb`, `test/integration/layouts_test.rb`, `test/application_system_test_case.rb`

**Prototype:** None.

**Primary tasks:** 1. Set a pretend date. 2. Clear it.

**In scope:**

- Three files: `app/views/layouts/application.html.erb`, new `test/integration/dev_clock_strip_test.rb`, and new `test/system/dev_clock_system_test.rb`.
- Render the strip once at the top of signed-in pages.
- Fit it into the fixed shell’s height using normal flex layout, preserving content/header spacing and avoiding an outer scrollbar.
- Verify that setting/clearing the override updates school-year counts, ended-year actions, and past-day rules through `Account#today`.

**NOT in scope:** Navigation redesign, clock UI for signed-out pages, or changes to school-day calculations.

**Build order:**

1. **Test:** Cover no strip without an override, no strip outside development, links across signed-in pages, and Clear returning to the current page. Exercise set/change/clear in the browser on desktop and phone widths, including a date that ends the year.
2. **Implement:** Mount the component in the application layout; keep its height in the shell’s normal layout flow. Restore temporary clock state and environment stubs after every test.
3. **Verify:** Sequentially run `bin/rails test test/integration/dev_clock_strip_test.rb` and `bin/rails test test/system/dev_clock_system_test.rb`.
4. Master runs **review-changes-mini for Checkpoint 6, Task 7**, exactly once after the task returns, or after the entire parallel batch returns if applicable.

### Task 8 [Master]: Share existing default school-year calendar rules

**Skills:** write-tests

**Reference:** `app/models/school_year/defaults.rb`, `test/models/school_year/defaults_test.rb`


**In scope:**

- Two files: the existing Defaults concern and its tests.
- Expose the existing `default_starts_on` and `default_ends_on` class helpers.
- Extract the two holiday definitions into `default_breaks_for(calendar_year)` for reuse by signup and seeds.
- Preserve signup’s existing date selection, summer advancement, holiday filtering/clipping, and tracking behavior.

**NOT in scope:** New default rules, changing signup behavior, or weakening historical-data protection.

**Build order:**

1. **Test:** Assert the shared default dates and holiday definitions, including winter crossing the year boundary. Preserve coverage for mid-year signup, summer, and the default end date.
2. **Implement:** Make only the narrow extraction; continue applying signup’s existing clipping in `create_default_breaks`.
3. **Verify:** `bin/rails test test/models/school_year/defaults_test.rb test/models/school_year_test.rb`.

### Task 9 [subagent]: Add the three seed families

**Skills:** write-tests

**Reference:** `db/seeds.rb`, `test/config/seeds_test.rb`, `app/models/user.rb`, `app/models/school_year/defaults.rb`


**In scope:**

- Two files: `db/seeds.rb` and `test/config/seeds_test.rb`.
- Inside the existing local-environment guard, add `new@cove.test`, `midyear@cove.test`, and `away@cove.test`, password `password`, each with its own named family.
- Preserve signup’s automatically created year for New Family.
- Initialize Mid-year/Away with the most recent August-start year, full default time off, and one non-overlapping past entry. On the exact first day, omit that extra entry as approved.
- Initialize scenarios transactionally only for newly created users or missing years; existing years remain unchanged on reseeding.

**NOT in scope:** Last-seen/activity tracking, Welcome Back behavior, modifying existing demo scenarios, or running `db:reset`.

**Build order:**

1. **Test:** Freeze representative autumn, spring, summer, and exact-August-start dates. Assert credentials, separate families, default dates/time off, the first-day exception, no duplicates, and unchanged existing years after reseeding with a different override. Extend staging/production no-demo-data checks.
2. **Implement:** Base dates on each family’s `Account#today` and Task 8’s shared calendar helpers. Account for signup already provisioning a year. Use direct writes only for initializing historical seed data, including coherent tracking fields; document why validations are bypassed.
3. **Verify:** `bin/rails test test/config/seeds_test.rb test/models/school_year/defaults_test.rb`.

### Task 10 [Master]: Complete final validation

**Skills:** write-tests, style-ui

**Reference:** `.github/workflows/ci.yml`, `test/application_system_test_case.rb`, approved design

**Prototype:** None.

**Primary tasks:** Open Shape of the day; set, change, and clear the start time; set and clear a pretend date.

**In scope:** Validate all three phases, capture visual evidence, and review the complete diff against `origin/main`.

**NOT in scope:** Further features, broad cleanup, merging, deployment, or automatically invoking `/review-changes`.

**Build order:**

1. **Test:** Re-run the focused tests together, then sequentially run:
   - `bin/rails test`
   - `bin/rails test:system`
   - `bin/rubocop`
   - `bin/erb_lint --lint-all -f compact`
2. **Implement:** No planned feature changes. Resolve failures within scope using TDD; report unrelated blockers. Run development `bin/rails db:seed` twice and confirm the three scenarios remain unchanged, preserving any existing clock override.
3. **Verify:** Rebuild Tailwind before visual inspection. Capture desktop and phone screenshots under `.context/` for both Planner tabs, the modal, the clock page, and the active strip. Inspect for overflow, button visibility, focus, and shell scrolling. Run `git diff origin/main...`, inspect uncommitted changes, and run `git diff --check`.
4. Run **review-changes-mini for Checkpoint 7, Tasks 8–10**, exactly once after all three finish. For a parallel batch, the master runs it after the entire batch returns.

## Task Dependencies

- Task 2 depends on Task 1; Task 3 depends on Task 2.
- Task 4 has no implementation dependency on Phase 1. Tasks 3–4 may overlap file work after Task 2, with Rails test runs serialized.
- Task 5 depends on Task 4.
- Task 6 depends on Task 5’s route and Task 4’s clock API.
- Task 7 depends on Tasks 5–6.
- Task 8 can be developed independently of the UI tasks; complete it before delegating Task 9.
- Task 9 depends on Tasks 4 and 8. Tasks 7 and 9 may overlap file work once their prerequisites pass; tests remain sequential.
- Task 10 depends on all preceding tasks.
- Subagents do not commit. The master coordinates verification and checkpoint reviews.

## Execution notes

- Approved prerequisite: disable time-zone conversion for `SchoolYear#school_starts_at`, with a regression test preserving its wall-clock hour after family-zone changes.

- Task 6 followed create-component: checked RailsBlocks banner docs/examples and dry run, adapted its message/action row without its optional JS, and added the required catalog and kitchen-sink examples.

- Task 7 uses the existing SidebarComponent `min_height_class: "min-h-0"` option so the strip and sidebar fit within the fixed shell. Clear-return regression also preserves the full verified origin for double-slash paths.

## Final validation

- Focused tests: 148 runs, 1,165 assertions, no failures or errors.
- Full Rails suite and final checkpoint review: 1,543 runs, 8,994 assertions, no failures or errors.
- Full system suite: 164 runs, 1,031 assertions, no failures or errors.
- RuboCop: 699 files inspected, no offenses. ERB lint: 365 files, no errors.
- Development `bin/rails db:seed` ran twice. All three scenarios' year/time-off attributes were unchanged on the second run; the existing clock-file state was preserved.
- Rebuilt Tailwind and inspected desktop/390px evidence under `.context/shape-of-day-*.png` and `.context/dev-clock*.png`: visible actions, field focus, phone button order, and shell scrolling verified.
- Reviewed committed and uncommitted changes against `origin/main`; `git diff --check` clean. Checkpoints 1–7 reviewed and committed.
- Existing shared lazy-modal limitation observed: after Discard, the database is unchanged, but reopening the same cached modal before navigation retains its unsaved field value. Shared modal behavior remains outside this plan's scope.
