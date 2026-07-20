> Ticket: COV-22
> Branch: jrdnbwmn/feature/cov-22-turbo-timeouts

# Plan: Turbo Timeout and Failure States

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Add pending-state behavior to `ButtonComponent` | Master | ✅ |
| 2 | Install server-rendered resilience templates in customer layouts | Master | ✅ |
| 3 | Handle frame network failures, missing frames, and retries | Master | ✅ |
| 4 | Add configurable deadlines for remote frames | Master | ✅ |
| 5 | Handle form deadlines and network failures | Master | ✅ |
| 6 | Replace the notifications frame's loading text | subagent | |
| 7 | Handle global failures and run regression verification | Master | |

## Prerequisites

- Design: [`docs/designs/turbo-timeout-and-failure-states.md`](../designs/turbo-timeout-and-failure-states.md)
- Prototype: None — use the existing `AlertComponent`, `ButtonComponent`, and `LoadingIndicatorComponent` designs without visual changes
- Feature branch exists: `jrdnbwmn/feature/cov-22-turbo-timeouts`
- Dependencies COV-18 and COV-21 are present on `origin/main`
- Run Rails commands through `mise exec --` so Ruby 4.0.5 is used

## Tasks

### Task 1 [Master]: Add pending-state behavior to ButtonComponent

**Skills:** write-tests, style-ui
**Reference:** Read [`app/components/button_component.rb`](../../app/components/button_component.rb), [`app/components/button_component.html.erb`](../../app/components/button_component.html.erb), [`app/assets/tailwind/components/buttons.css`](../../app/assets/tailwind/components/buttons.css), and [`test/components/button_component_test.rb`](../../test/components/button_component_test.rb)
**Prototype:** None — preserve the cataloged button appearance

**In scope:**

- Test submit-button markup for its enabled label and disabled spinner state.
- Use the existing `data[:disable_with]` value as the caller-supplied pending label.
- Fall back to localized **Working...** when no pending label is supplied.
- Render pending content with `when-enabled` / `when-disabled` so Turbo's native submitter disabling toggles the state without replacing component HTML.
- Preserve links, non-submit buttons, icons, explicitly disabled buttons, and the existing static `loading:` state.
- Add the approved Turbo-resilience strings under one namespace in `config/locales/en.yml`.

**NOT in scope:**

- Rewriting raw `button_to` callers.
- Adding a second button component or new CSS system.
- Changing button colors, spacing, variants, or loading animation.

**Build order:**

1. **Test:** Extend `test/components/button_component_test.rb` with custom-label, fallback-label, and non-submit regression cases.
2. **Implement:** Update `app/components/button_component.rb`, `app/components/button_component.html.erb`, and `config/locales/en.yml`.
3. **Verify:** `mise exec -- bin/rails test test/components/button_component_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 2 [Master]: Install resilience templates in customer layouts

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/layouts/application.html.erb`](../../app/views/layouts/application.html.erb), [`app/views/layouts/minimal.html.erb`](../../app/views/layouts/minimal.html.erb), and [`app/views/application/_flash.html.erb`](../../app/views/application/_flash.html.erb)
**Prototype:** None — compose existing catalog components

**In scope:**

- Create `app/views/application/_turbo_resilience_templates.html.erb`.
- Render inert templates for frame failure/retry, form timeout, form network failure, and global network failure.
- Build every notice with `AlertComponent`; build the frame retry with `ButtonComponent`.
- Mark dynamic notice wrappers with `role="alert"` and a resilience-specific selector.
- Attach `turbo-resilience` to `<body>` and render the templates in both customer-facing layouts.
- Add a system test proving the application and minimal layouts contain the controller and inert templates.

**NOT in scope:**

- Modifying Jumpstart engine layouts or the internal documentation layout.
- Adding a new ViewComponent.
- Hand-building design-system classes in JavaScript.
- Changing existing Rails flash rendering.

**Build order:**

1. **Test:** Create `test/system/turbo_resilience_system_test.rb` with layout-wiring assertions against the public application layout and a Devise minimal-layout page.
2. **Implement:** Add `app/views/application/_turbo_resilience_templates.html.erb` and update `app/views/layouts/application.html.erb` and `app/views/layouts/minimal.html.erb`.
3. **Verify:** `mise exec -- bin/rails test:system test/system/turbo_resilience_system_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 3 [Master]: Handle frame failures, missing frames, and retries

**Skills:** write-tests
**Reference:** Read [`app/javascript/controllers/notifications_controller.js`](../../app/javascript/controllers/notifications_controller.js), [`app/javascript/controllers/index.js`](../../app/javascript/controllers/index.js), and the frame flow in the design
**Prototype:** None — render the inert component templates from Task 2

**In scope:**

- Create `app/javascript/controllers/turbo_resilience_controller.js`; eager registration is automatic through the existing controller index.
- Add document-level Turbo listeners with symmetric cleanup on disconnect.
- Track active frame state without persisting it in the DOM or database.
- Handle `turbo:fetch-request-error` when its target is a Turbo Frame.
- Prevent Turbo's generic missing-frame output on `turbo:frame-missing`.
- Preserve only same-origin HTTP(S) frame URLs as retryable.
- Render the frame failure template and omit its retry action when no safe `src` exists.
- Retry in place without allowing repeated clicks while the request is pending.
- Restore the same error state after a repeated failure.
- Clear stale frame notices and request state after a successful frame load.
- Add browser-fetch helpers that can reject or return controlled frame responses without real network timing.

**NOT in scope:**

- Retrying forms or mutation requests.
- Treating valid HTTP responses as transport failures.
- Adding analytics, logging, or online/offline monitoring.

**Build order:**

1. **Test:** Add frame network-failure/retry and missing-frame suppression cases to `test/system/turbo_resilience_system_test.rb`; add reusable fetch stubs in `test/support/system/turbo_resilience.rb`.
2. **Implement:** Create `app/javascript/controllers/turbo_resilience_controller.js` with frame state, safe-URL validation, template cloning, failure rendering, cleanup, and retry behavior.
3. **Verify:** `mise exec -- bin/rails test:system test/system/turbo_resilience_system_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 4 [Master]: Add configurable remote-frame deadlines

**Skills:** write-tests
**Reference:** Read [`app/javascript/controllers/turbo_resilience_controller.js`](../../app/javascript/controllers/turbo_resilience_controller.js) from Task 3 and the design's timeout rules
**Prototype:** None

**In scope:**

- Start a deadline for remote frame GET requests on `turbo:before-fetch-request`.
- Default to 15,000 milliseconds.
- Accept a positive finite millisecond override from `data-turbo-resilience-timeout`.
- Treat the exact string `"false"` as deadline opt-out; invalid values fall back to 15 seconds.
- On timeout, preserve a safe retry URL, remove the frame `src` to cancel Turbo's pending fetch, and render the inline failure template.
- Clear and replace prior timers when the same frame starts another request.
- Clear all remaining timers when the controller disconnects.
- Test a short override, opt-out, timeout recovery, and a retry that fails again.

**NOT in scope:**

- A deadline for full-page navigation or standalone Turbo Stream requests.
- Automatic retry after timeout.
- Waiting 15 real seconds in the system suite.

**Build order:**

1. **Test:** Extend `test/system/turbo_resilience_system_test.rb` with browser-timed short-override and opt-out cases using a never-settling fetch stub.
2. **Implement:** Add frame deadline parsing, cancellation, cleanup, and repeated-failure state to `app/javascript/controllers/turbo_resilience_controller.js`.
3. **Verify:** `mise exec -- bin/rails test:system test/system/turbo_resilience_system_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 5 [Master]: Handle form deadlines and network failures

**Skills:** write-tests
**Reference:** Read [`app/views/devise/registrations/new.html.erb`](../../app/views/devise/registrations/new.html.erb), [`app/components/button_component.html.erb`](../../app/components/button_component.html.erb), and the form lifecycle in the design
**Prototype:** None — use the form notice templates from Task 2

**In scope:**

- Track Turbo form submissions from `turbo:submit-start` through `turbo:submit-end`.
- Apply the same default, override, opt-out, and invalid-value rules to forms.
- Call the active `formSubmission.stop()` when a deadline expires so Turbo restores the submitter.
- Insert the timeout notice immediately after the affected form.
- Show the distinct form-local network-failure notice for rejected fetches.
- Preserve the notice through the timeout/error-triggered `turbo:submit-end`, while normal completion removes stale resilience notices.
- Replace only the prior resilience notice belonging to that form.
- Test custom pending text, fallback pending text, control restoration, no automatic resubmission, and immediate network failure.
- Test that a resolved validation/HTTP response does not produce a resilience notice.

**NOT in scope:**

- Assuming a timed-out server mutation did not complete.
- Automatically submitting again.
- Changing Rails validation, redirect, or server-rendered error behavior.
- Adding form-specific business rules.

**Build order:**

1. **Test:** Extend `test/system/turbo_resilience_system_test.rb` with short-timeout, opt-out, immediate-failure, and ordinary-response form cases.
2. **Implement:** Add form submission state, timeout cancellation, transport-error handling, local notice replacement, and normal cleanup to `app/javascript/controllers/turbo_resilience_controller.js`.
3. **Verify:** `mise exec -- bin/rails test test/components/button_component_test.rb && mise exec -- bin/rails test:system test/system/turbo_resilience_system_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 6 [subagent]: Replace the notifications frame loading text

**Skills:** write-tests, style-ui
**Reference:** Read [`app/views/application/_notifications.html.erb`](../../app/views/application/_notifications.html.erb), [`app/components/loading_indicator_component.rb`](../../app/components/loading_indicator_component.rb), and [`test/system/app_shell_system_test.rb`](../../test/system/app_shell_system_test.rb)
**Prototype:** None — preserve the existing notifications dropdown layout

**In scope:**

- Replace the notifications frame's plain **Loading...** paragraph with `LoadingIndicatorComponent`.
- Add a localized notifications loading label.
- Preserve the frame ID, lazy loading, target, source URL, classes, and notifications target.
- Extend the existing app-shell system test to assert the catalog loading indicator is present before the remote frame resolves.

**NOT in scope:**

- Changing the notifications dropdown design or behavior.
- Editing the Jumpstart engine copy.
- Adding another loading component.
- Changing notification fetching or read-state logic.

**Build order:**

1. **Test:** Extend `test/system/app_shell_system_test.rb` to assert the initial notifications frame contains the loading indicator and localized label.
2. **Implement:** Update `app/views/application/_notifications.html.erb` and `config/locales/en.yml`.
3. **Verify:** `mise exec -- bin/rails test:system test/system/app_shell_system_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 7 [Master]: Handle global failures and verify regressions

**Skills:** write-tests, review-changes
**Reference:** Read [`app/views/application/_flash.html.erb`](../../app/views/application/_flash.html.erb), [`test/system/turbo_resilience_system_test.rb`](../../test/system/turbo_resilience_system_test.rb), and the global failure flow in the design
**Prototype:** None — use the global alert template from Task 2

**In scope:**

- Route non-frame, non-form `turbo:fetch-request-error` events to `#flash`.
- Cover failed full-page navigation and standalone Turbo Stream requests.
- Keep the current page usable and avoid automatic retries.
- Replace only the prior global resilience notice while preserving unrelated Rails flash alerts.
- Suppress duplicate notices from one failed interaction.
- Confirm successful frame/form interactions remove their stale resilience state.
- Confirm ordinary HTTP errors do not trigger transport-failure UI.
- Run component, focused system, complete Rails, and complete system suites.
- Inspect the final diff for debug hooks, test-only browser state, untranslated strings, and accidental changes outside the ticket.

**NOT in scope:**

- Global request deadlines.
- Generic retry controls for navigation or Turbo Streams.
- Connectivity banners, telemetry, or recovery on the browser `online` event.
- Refactoring unrelated Turbo, flash, or Stimulus code.

**Build order:**

1. **Test:** Add page-navigation failure, standalone-stream failure, Rails-flash preservation, notice replacement, success-cleanup, and HTTP-response regression cases to `test/system/turbo_resilience_system_test.rb`.
2. **Implement:** Complete global routing, deduplication, and cleanup in `app/javascript/controllers/turbo_resilience_controller.js`; remove all fetch stubs during test teardown.
3. **Verify:** Run:
   - `mise exec -- bin/rails test test/components/button_component_test.rb`
   - `mise exec -- bin/rails test:system test/system/turbo_resilience_system_test.rb test/system/app_shell_system_test.rb`
   - `mise exec -- bin/rails test`
   - `mise exec -- bin/rails test:system`
   - `git diff --check`
   - `git diff origin/main...HEAD`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

## Task Dependencies

- Task 2 depends on Task 1 for the localized messages and pending `ButtonComponent` markup.
- Task 3 depends on Task 2 for the controller attachment and inert templates.
- Task 4 depends on Task 3's frame state and retry foundation.
- Task 5 depends on Task 3's listener, state, and template-cloning foundation.
- Tasks 3–5 are sequential because they modify the same Stimulus controller and system-test file.
- Task 6 is independent and may run in parallel after Task 1.
- Task 7 depends on Tasks 3–6 and is the final integration and regression gate.
