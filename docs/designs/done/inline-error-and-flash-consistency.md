> Ticket: COV-21
> Branch: jrdnbwmn/cov-21-inline-error-flash-alertcomponent
> Plan created: docs/plans/inline-error-and-flash-consistency.md

# Feature: Inline error + flash message consistency (AlertComponent)

## Problem

Flash messages and in-form validation summaries need a single visual language so every feature slice gets consistent inline feedback for free. The `_flash.html.erb` partial only handles two of the four Rails flash keys (`notice`, `alert`) and has no central mapping; `_error_messages.html.erb` is already on `AlertComponent` but the ticket description predates that change.

## Approach

Route every Rails string flash through `AlertComponent` from one place — a small key → variant mapping in `_flash.html.erb`. Do not introduce a helper method; there is exactly one caller. Leave `_error_messages.html.erb` as-is (already migrated). Leave `ToastComponent` / hash-flash rendering untouched — no controller in the app uses that path today, and unifying the two toast systems is a separate concern that deserves its own ticket.

The mapping:

| Flash key | AlertComponent variant | Color |
|-----------|-----------------------|-------|
| `notice`  | `:info`               | blue  |
| `success` | `:success`            | green |
| `alert`   | `:error`              | red   |
| `error`   | `:error`              | red   |

**Why `alert → :error` (not `:warning`):** JSP and Devise both set `flash[:alert]` on hard failures — Devise auth failures ("Invalid email or password"), rescued exceptions in JSP checkout/subscription controllers (`flash[:alert] = e.message`), sudo failures, etc. These are errors, not warnings.

## Acceptance Criteria

- Form errors and flashes share one visual language via `AlertComponent`.
- All four Rails string flash keys (`notice`, `success`, `alert`, `error`) render through `AlertComponent` with the mapping above.
- The mapping lives in exactly one place; adding a new key is a one-line change.
- `bin/rails test` green.

## Prototype

None. Visual design is `AlertComponent`'s existing variants (see `app/views/dev/kitchen_sink/show.html.erb`).

## Data Model

None.

## Screens / Flows

**Flash banner (app shell):** `#flash` region at the top of `application.html.erb` (and `minimal.html.erb`) renders any set flash keys as `AlertComponent`s. Iterated in a deterministic order (`notice, success, alert, error`) so multiple simultaneous flashes stack predictably.

**Form validation summary:** unchanged. `_error_messages.html.erb` renders "N errors prevented this…" as an `AlertComponent(variant: :error)` with the `errors.full_messages` list in the description slot. Any form partial that already does `render "error_messages", resource: form.object` continues to work.

**Toasts (out of scope):** hash-based flashes still route to `ToastComponent` in `_flash.html.erb`. No caller in the app uses this path today; JSP docs teach it. Leaving it alone preserves the escape hatch without unifying two toast systems in this ticket.

## Scope

**In:**

- Rewrite `app/views/application/_flash.html.erb` to iterate a `{notice: :info, success: :success, alert: :error, error: :error}` mapping, guarding on `is_a?(String) && present?` so hash flashes fall through to the toast block.
- Update two existing system tests whose selectors depend on the `alert → :warning` (amber) mapping:
  - `test/system/login_system_test.rb:58` — `.border-amber-200` → `.border-red-200`
  - `test/system/app_shell_system_test.rb:101` — (verify; only `.border-blue-200` is asserted there, which stays)
- Add an integration test: a validation-failing form submission renders the error summary via `AlertComponent` (assert on `.border-red-200` + the "N errors prevented…" title).
- Add an integration test that exercises each of the four flash keys and asserts the expected border class. Use a tiny in-test anonymous controller so this doesn't couple to specific Devise strings or app routes.

**Deferred:**

- Unifying `ToastComponent` (JSP, hash flashes) and `UiToastComponent` (Rails Blocks, Stimulus-driven) — separate architectural cleanup.
- Migrating any hash-flash callers (there are none in the app today; JSP docs page only).
- Any change to `_error_messages.html.erb` — it's already on `AlertComponent`.

## Open Questions

None.

## More Info

**Prior work already merged** (from COV-13 shell rebuild and earlier):

- `_error_messages.html.erb` already renders via `AlertComponent(variant: :error)` with `errors.full_messages` as `<li>`s in the description. The ticket description was written before this landed.
- `_flash.html.erb` already routes `alert` → `:warning` and `notice` → `:info` through `AlertComponent`. This change extends the mapping to all four keys and switches `alert` to `:error`.

**Files touched:**

- `app/views/application/_flash.html.erb` (rewrite)
- `test/system/login_system_test.rb` (selector update)
- `test/system/app_shell_system_test.rb` (verify — likely no change needed)
- `test/integration/…_test.rb` (new integration tests for error summary + flash mapping)
