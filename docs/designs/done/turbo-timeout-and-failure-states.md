> Plan created: docs/plans/turbo-timeout-and-failure-states.md

> Ticket: COV-22
> Branch: jrdnbwmn/feature/cov-22-turbo-timeouts

# Feature: Timeout and slow-response states for Turbo interactions

## Problem

Turbo requests currently have no intentional app-level recovery when a network
request fails, a remote frame does not contain its expected content, or a
request remains pending indefinitely. Users can be left with a blank frame, a
silent navigation failure, or a submit control that never recovers.

## Approach

Add one global `turbo-resilience` Stimulus controller to the customer-facing
application shell. It listens to Turbo's existing fetch, frame, and form
lifecycle events and chooses the error surface from the event target:

- remote Turbo Frame failures stay inside the affected frame;
- form failures and timeouts render immediately after the affected form; and
- page-navigation or standalone Turbo Stream network failures render in the
  existing global `#flash` region.

Remote frame GET requests and Turbo form submissions receive a 15-second
client-side deadline by default. Individual frames or forms may override the
deadline with `data-turbo-resilience-timeout="<milliseconds>"` or opt out with
`data-turbo-resilience-timeout="false"`. Opting out disables only the deadline;
genuine network failures are still reported.

When a request exceeds its deadline, stop waiting for it, restore the pending
control, and show the appropriate error state. A failed frame with a safe
`src` gets an explicit retry that reloads that GET request. Form submissions
are never retried automatically because stopping the browser request cannot
guarantee that the server stopped processing it.

Reuse the existing design-system primitives rather than introducing another
component:

- `AlertComponent` supplies every failure message;
- `ButtonComponent` supplies the frame retry action and the submit control;
- `LoadingIndicatorComponent` replaces plain frame-loading text; and
- `ButtonComponent`'s existing spinner treatment and the app's
  `when-enabled` / `when-disabled` CSS supply the live submit-pending state.

Error markup must be server-rendered from the existing components and made
available to the controller as inert templates. Do not duplicate component
classes or hand-build the design system in JavaScript.

## Acceptance Criteria

- A remote Turbo Frame that fails at the network level, exceeds 15 seconds, or
  receives a response without its expected frame shows the designed inline
  failure state instead of blank or generic "Content missing" output.
- A failed frame with a safe `src` can be retried in place.
- A Turbo form still pending after 15 seconds stops waiting, restores its
  submit control, and displays the approved cautionary message beside the
  form without resubmitting automatically.
- Immediate form network failures recover the control and show a form-local
  error.
- Page-navigation and standalone Turbo Stream network failures leave the
  current page usable and show a consistent error in `#flash`.
- Ordinary validation responses, redirects, and intentional server-rendered
  HTTP errors retain their existing Rails/Turbo behavior.
- Timeout values can be overridden or disabled per frame/form.
- Simulated slow and failed requests are exercised in system tests.
- `bin/rails test`, including the relevant system tests, is green.

## Prototype

None. The visual design is locked by the existing `AlertComponent`,
`ButtonComponent`, and `LoadingIndicatorComponent` catalog entries. This
ticket composes those primitives into behavioral states without redesigning
them.

## Data Model

None. There are no migrations, Rails model changes, persisted retries, queues,
or analytics.

The controller keeps temporary browser-only state for each active form or
frame: the timeout handle, the active Turbo submission or fetch cancellation
state, the affected element, and whether a resilience notice has already been
shown. That state is discarded when the interaction finishes or the controller
disconnects.

## Screens / Flows

### Successful interaction

Turbo interactions work as they do today. A submit control enters its
loading/disabled state. A successful or intentionally handled response clears
the deadline and removes any stale resilience notice without showing new UI.

### Frame loading, failure, and retry

1. A remote frame shows `LoadingIndicatorComponent` while its GET request is
   pending.
2. A network failure, 15-second timeout, or missing expected frame replaces the
   frame contents with an error `AlertComponent`:
   - Title: **We couldn't load this content**
   - Description: **Check your connection, then try again.**
3. When the frame has a safe `src`, a secondary `ButtonComponent` labeled
   **Try again** reloads it in place.
4. The retry cannot be triggered repeatedly while the new request is pending.
   A repeated failure restores the same error state.
5. A frame created by a form submission without a `src` receives the error
   state without an automatic retry action.

### Form pending, timeout, and network failure

1. Turbo disables the submit control. `ButtonComponent` shows its spinner and
   the caller's pending label when provided, falling back to **Working...**.
2. If the submission is still pending after 15 seconds, the controller stops
   waiting and Turbo restores the original control state.
3. An error `AlertComponent` is inserted immediately after the form:
   - Title: **This request is taking longer than expected**
   - Description: **It may still have completed. Check the result before trying
     again.**
4. An immediate network failure uses the same placement with:
   - Title: **We couldn't complete this request**
   - Description: **Check your connection and verify the result before trying
     again.**
5. The user decides whether to submit again; the app does not repeat the
   request.

### Page-navigation or standalone stream network failure

1. The current page remains visible and usable.
2. An error `AlertComponent` appears in the existing global `#flash` region:
   - Title: **We lost the connection**
   - Description: **Check your connection and try again.**
3. The user retries the original navigation or action manually. No generic
   retry button is shown because the failed request may have mutated data.

### Accessibility and repeated failures

Dynamic notices are announced with `role="alert"` without changing the
semantics of every existing `AlertComponent`. They do not steal keyboard focus
or force-scroll the page. A new resilience failure replaces the previous
resilience notice for that same form, frame, or global region; unrelated Rails
flash messages remain intact.

## Scope

**In:**

- A global Stimulus controller registered through the existing eager-loading
  setup and attached to customer-facing layouts that render `#flash`.
- Handling for Turbo fetch errors, missing-frame responses, remote-frame
  deadlines, form deadlines, and normal Turbo completion cleanup.
- A 15-second default with per-element override and opt-out attributes.
- Server-rendered inert templates composed from `AlertComponent` and
  `ButtonComponent` for controller-driven error states.
- Consistent pending markup for `ButtonComponent` submitters using its existing
  spinner treatment and pending labels.
- `LoadingIndicatorComponent` in the notifications remote frame's initial
  loading state; the notifications frame is the app's only current live remote
  `src` frame.
- Localized user-facing strings for the pending and failure messages.
- Deterministic system tests that stub browser fetch behavior to simulate a
  rejected request and a never-settling request. Tests use a short per-element
  timeout override rather than sleeping for 15 seconds.
- Coverage for frame failure/retry, missing-frame suppression, submit timeout
  recovery, form network failure, and global navigation/stream failure.

**Deferred:**

- Automatic form or mutation retries.
- Persisted retry queues or background synchronization.
- Staged "still working" notices before the final deadline.
- Online/offline banners, connectivity monitoring, or recovery on the browser
  `online` event.
- Failure analytics, telemetry, or reporting.
- Retry policies based on HTTP method, endpoint, model, or business domain.
- Changes to ordinary validation, redirect, or server-rendered 4xx/5xx flows.
- A new error-state ViewComponent or another JavaScript framework.

## Open Questions

None.

## More Info

- Dependencies COV-18 and COV-21 are already present on `origin/main`.
  COV-21 standardized string flashes and validation summaries on
  `AlertComponent`.
- The installed Turbo Rails version is 2.0.23. Its relevant public lifecycle
  events are `turbo:before-fetch-request`, `turbo:fetch-request-error`,
  `turbo:frame-missing`, `turbo:submit-start`, and `turbo:submit-end`.
- Turbo already disables and restores a submitter when a request starts and
  finishes. The missing behavior is a client deadline for a request that never
  settles and consistent UI for transport-level failure.
- A rejected fetch is different from an HTTP error response. This design
  handles transport errors globally but leaves valid HTTP responses to the
  existing Rails/Turbo response flow. A response without the frame Turbo needs
  is still treated as a frame failure because it cannot be rendered correctly.
- The app currently has one live remote `src` frame: the lazy notifications
  frame in the application shell. `PaginationComponent` supports targeting a
  frame, but its current app callers do not provide a frame ID.
- `#flash` exists in both the main application and minimal layouts. Jumpstart's
  internal documentation layout is not part of the customer-facing behavior.
