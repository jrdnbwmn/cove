> Ticket: COV-21
> Branch: jrdnbwmn/cov-21-inline-error-flash-alertcomponent

# Plan: Inline error + flash message consistency (AlertComponent)

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Rewrite `_flash.html.erb` to map all four flash keys → AlertComponent variants; update system-test selectors | Master | ✅ |
| 2 | Add integration tests: flash key→variant mapping + form error summary | Master | ✅ |

## Prerequisites

- Design: `docs/designs/inline-error-and-flash-consistency.md`
- Prototype: None (visual design is AlertComponent's existing variants)
- Feature branch exists: `jrdnbwmn/cov-21-inline-error-flash-alertcomponent`

## Key facts gathered

- `app/views/application/_flash.html.erb` currently renders only `alert → :warning` and `notice → :info`, then a toasts block. It uses the `alert`/`notice` helper methods from `lib/jumpstart/app/helpers/flash_helper.rb`, which already strip out Hash-valued flashes (those go to `toasts`). There are **no** `success`/`error` helper methods — the rewrite reads `flash[key]` directly and guards on `is_a?(String) && present?` so hash flashes still fall through to the toast block.
- `AlertComponent` (`app/components/alert_component.rb`) variants → border classes: `:info` → `border-blue-200`, `:success` → `border-green-200`, `:error` → `border-red-200`, `:warning` → `border-amber-200`.
- `_error_messages.html.erb` already renders `AlertComponent(variant: :error)` — **no change**.
- `test/system/login_system_test.rb:58` — `assert_alert` helper asserts `.border-amber-200`; must become `.border-red-200`.
- `test/system/app_shell_system_test.rb:101` — asserts only `.border-blue-200` (notice → info), which is unchanged. Verify only.
- `devise/registrations/new.html.erb` renders `error_messages` — a signup POST with a blank email produces the error summary, a good concrete route for the error-summary test.

## Tasks

### Task 1 [Master]: Rewrite flash partial + fix system-test selectors

**Skills:** style-ui, write-tests
**Reference:** Read `app/components/alert_component.rb` (variant→border classes), `lib/jumpstart/app/helpers/flash_helper.rb` (hash-flash / toast fall-through), and current `app/views/application/_flash.html.erb`.

**In scope:**

- Rewrite `app/views/application/_flash.html.erb`:
  - Define the mapping inline: `{ notice: :info, success: :success, alert: :error, error: :error }`.
  - Iterate it in that order; for each key render `AlertComponent.new(title: flash[key], variant: variant)` **only when** `flash[key].is_a?(String) && flash[key].present?`.
  - Keep the `#flash` wrapper `<div id="flash" data-turbo-temporary>` and the existing `#toasts` block (hash flashes) untouched.
- Update `test/system/login_system_test.rb:58`: `.border-amber-200` → `.border-red-200` in the `assert_alert` helper.
- Verify `test/system/app_shell_system_test.rb:101` needs no change (it asserts `.border-blue-200`).

**NOT in scope:**

- Any change to `_error_messages.html.erb`, `ToastComponent`, `UiToastComponent`, or the `FlashHelper` methods.
- Adding `success`/`error` helper methods.

**Build order:**

1. **Test:** In `test/system/login_system_test.rb`, change `assert_alert` to assert `.border-red-200`. (Fails red until the partial changes `alert → :error`.)
2. **Implement:** Rewrite `_flash.html.erb` per the mapping above.
3. **Verify:** `bin/rails test:system test/system/login_system_test.rb` and `bin/rails test:system test/system/app_shell_system_test.rb -i` (confirm signed-out notice still green).
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 2 [Master]: Integration tests for flash mapping + error summary

**Skills:** write-tests
**Reference:** Read `test/integration/accounts_test.rb` for integration-test setup/login helpers; read the new `_flash.html.erb` from Task 1.

**In scope:** New file `test/integration/inline_alert_consistency_test.rb` with two tests:

- **Flash key → variant mapping.** Use a tiny in-test anonymous controller with `with_routing` (draw one route that sets `flash.now[param_key] = "msg"` and renders, exercising the app layout's `#flash` region). Assert each of the four keys renders the expected border class: `notice`→`.border-blue-200`, `success`→`.border-green-200`, `alert`→`.border-red-200`, `error`→`.border-red-200`. This avoids coupling to specific Devise strings/routes.
- **Form error summary.** POST to `user_registration_path` with an invalid (blank) email; assert the response body contains `.border-red-200` and the "N errors prevented…" title (`I18n.t("errors.messages.not_saved", ...)`) rendered by `_error_messages`.

**NOT in scope:**

- System tests (Task 1 covers those); toast-path tests; testing hash flashes.

**Build order:**

1. **Test:** Write both tests in `test/integration/inline_alert_consistency_test.rb`. If the anonymous-controller `with_routing` approach proves brittle in this checkout, fall back to driving a real flash-setting route — but prefer the anonymous controller per the design. Flag to Master if a workable seam can't be found in ~1 attempt.
2. **Implement:** No app code — tests should pass against Task 1's partial. If the mapping test fails, the bug is in Task 1's partial, not the test.
3. **Verify:** `bin/rails test test/integration/inline_alert_consistency_test.rb`, then full `bin/rails test`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

## Task Dependencies

- Task 2 depends on Task 1 (its mapping test asserts behavior the rewritten partial provides).
- No parallelism — two sequential Master tasks. The work is small (one partial, one selector tweak, one new test file).
