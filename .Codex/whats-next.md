# What's Next

## Work completed and current state

COV-13, “Rebuild the app shell with design-system components,” is active on
`feature/cov-13-replace-app-shell` (target: `origin/main`). Task 1 of 9 is
complete and committed as `90cf21d feature: rebuild app shell navigation`.

Task 1 added the app-level navbar shadow at
`app/views/application/_navbar.html.erb`, restyled the existing
`_left_nav` and `_right_nav` app shadows using design tokens and
`ButtonComponent`, and added the full behavior skeleton in
`test/system/app_shell_system_test.rb`. The plan status is updated in
`docs/plans/replace-app-shell.md`.

Verification already completed:

- `mise exec -- bin/rails db:migrate:status` — all migrations up.
- `mise exec -- bin/rails test` — 280 runs, 611 assertions, 0 failures.
- `mise exec -- bin/rails test:system test/system/app_shell_system_test.rb -i '/signed out|mobile/'` — 2 runs, 8 assertions, 0 failures.
- `mise exec -- bin/rubocop -A test/system/app_shell_system_test.rb` — no offenses.
- Task 1 review passed; no secrets, debug code, or scope violations found.

The targeted system tests use `mise exec --`. Rails does not accept the plan’s
`test:system TEST=...` form in this checkout; pass the file path directly.
This Rails version advises `-i` rather than `-n` for test-name filtering.

## Work Remaining

Continue the approved plan at [replace-app-shell.md](../docs/plans/replace-app-shell.md),
starting with Task 2. Tasks 2, 3, 4, and 7 are marked Clone and may be
delegated after Task 1; Tasks 5 and 6 remain Master. Respect the plan order:

1. Task 2: create `app/views/application/_account_menu.html.erb` with
   `DropdownComponent`; preserve `switch_account_button` and the `accounts`
   controller reconnect action. Use the existing account case in
   `test/system/app_shell_system_test.rb`, then review and mark the plan.
2. Task 3: create `_user_menu.html.erb` with `DropdownComponent`, preserving
   every conditional and sign-out behavior.
3. Task 4: create `_dev_menu.html.erb` with `DropdownComponent`, tooltip
   controller, and desktop-only behavior.
4. Task 5: create `_notifications.html.erb` with `DropdownComponent` while
   keeping the outer `notifications` controller, unread data values, lazy Turbo
   frame, badge, and mark-read action unchanged.
5. Task 6: create `_flash.html.erb` with `AlertComponent` banners but retain
   the existing `ToastComponent` loop.
6. Task 7: create `_footer.html.erb` as an app-level token-styled shadow.
7. Task 8: remove only the now-orphaned shell CSS specified in the plan from
   `app/assets/tailwind/components/top_nav.css` and `nav.css`; do not touch
   native, minimal, sidebar, or docs styles.
8. Task 9: run the full Rails and system suites, complete the browser sweep,
   review the final diff, and only update the catalog if an app component file
   changed.

Do not edit `lib/jumpstart/app/views/application/`; app-level partials shadow
the engine. Keep both `dropdown` and `toggle` Stimulus controllers registered.
Do not change theme plumbing, Hotwire Native/minimal/sidebar surfaces, Devise,
or billing behavior.

The shared system test intentionally has menu and flash assertions that cannot
pass until Tasks 2–7 create their app-level shadows. Run each task’s targeted
test before its implementation (RED) and again after (GREEN), then run
`review-changes` before marking its plan row complete.

## Dead Ends

- `mise exec -- bin/rails test:system TEST=test/system/app_shell_system_test.rb`
  fails in this project with `InvalidTestError`; use the test file as a
  positional argument instead.
- `-n` still works but emits a deprecation warning; use `-i` for test-name
  filtering.
- This Capybara version does not resolve aria-labels reliably through
  `click_button`. The shared test uses CSS selectors such as
  `find("button[aria-label='User Menu']")`; preserve that approach when working
  with shell controls.

## Open Questions

None. The next session can continue the approved plan at Task 2.
