# What's Next

## Work completed and current state

COV-13, “Rebuild the app shell with design-system components,” is active on
`feature/cov-13-replace-app-shell` (target: `origin/main`). Tasks 1–5 of 9
are complete and committed:

- `90cf21d feature: rebuild app shell navigation` — Task 1: app-level navbar
  shadow, token-styled left/right nav, and the shared shell system-test
  skeleton.
- `6c09098 feature: replace app shell menus` — Tasks 2–5: app-level
  `_account_menu`, `_user_menu`, `_dev_menu`, and `_notifications` shadows
  using `DropdownComponent`.

The menu work preserves account switching (including the `accounts` reconnect
action), every user-menu conditional and sign-out form, the development menu's
tooltip/non-Turbo links/desktop-only visibility, and the notifications
controller data, unread badge, lazy Turbo frame, and mark-read-on-open action.
The plan status is updated through Task 5.

The account-menu markup test assertions in
`test/integration/multitenancy_test.rb` now use the accessible Account Menu
button rather than the removed `.account-menu .name` classes. The shared
system test temporarily stubs `Jumpstart.config.account_types` for its
team-account case and `Rails.env.development?` for its development-menu case;
this exercises those intentionally gated branches without changing production
conditions. It also covers the admin-only user-menu link.

Verification completed:

- `mise exec -- bin/rails db:migrate:status` — all migrations up.
- `mise exec -- bin/rails test` — 280 runs, 611 assertions, 0 failures.
- Targeted shell system tests for account switching, user/admin menus,
  notifications, and the development menu — passing.
- `mise exec -- bin/rubocop -A test/system/app_shell_system_test.rb test/integration/multitenancy_test.rb` — no offenses.
- Review passed after fixing the stale multitenancy markup assertions and the
  unsupported `DropdownComponent` admin-link option.

The workspace is clean after the feature commit. The full
`app_shell_system_test.rb` intentionally remains red only for the flash-banner
assertion until Task 6 creates the app-level `_flash` shadow.

## Work Remaining

Continue the approved plan at
[replace-app-shell.md](../docs/plans/replace-app-shell.md), starting with
Task 6:

1. Task 6 (Master): create `app/views/application/_flash.html.erb` with
   `AlertComponent` for alert/notice banners while preserving the existing
   `#flash`, `#toasts`, and `ToastComponent` loop. Run the flash system case
   first (currently red), then green, review, and mark the plan.
2. Task 7 (Clone): create `app/views/application/_footer.html.erb`, keeping
   the existing routes, translation keys, and IA while applying token-based
   styles. Run the footer case, review, and mark the plan.
3. Task 8 (Master): trim only the enumerated shell rules from
   `app/assets/tailwind/components/top_nav.css` and `nav.css`; grep every
   candidate first and retain native, minimal, sidebar, and docs rules. Run
   the full app-shell system test after each deletion chunk.
4. Task 9 (Master): run full `bin/rails test` and `bin/rails test:system`,
   perform the required signed-in/signed-out mobile/desktop light/dark browser
   sweep, inspect `git diff --stat origin/main...HEAD`, and run
   `/update-catalog` only if `app/components/` changed (none have so far).

Do not edit `lib/jumpstart/app/views/application/`; app-level partials shadow
the engine. Keep both `dropdown` and `toggle` Stimulus controllers registered.
Do not alter theme plumbing, Devise, billing, Hotwire Native, minimal, or
sidebar surfaces.

Use `mise exec --` for Rails commands. For targeted system tests, pass the
file path positionally and use `-i`, for example:

```sh
mise exec -- bin/rails test:system test/system/app_shell_system_test.rb -i /flash/
```

## Dead Ends

- `mise exec -- bin/rails test:system TEST=test/system/app_shell_system_test.rb`
  fails with `InvalidTestError`; use the positional test file instead.
- `-n` works but emits a deprecation warning; use `-i` for name filtering.
- Capybara does not reliably resolve aria-label controls through
  `click_button`; use selectors such as
  `find("button[aria-label='User Menu']")`.
- The Task 1 test skeleton did not activate its team-account or development
  branches in the default test configuration. Keep the narrow test-only stubs
  now present in `test/system/app_shell_system_test.rb` rather than weakening
  the production render guards.
- `DropdownComponent#with_item_link` does not accept arbitrary `data:`
  options. Use `with_item_custom(unstyled: true)` plus a fully attributed
  `link_to` for non-Turbo menu links, as the dev/admin menu implementations do.

## Open Questions

None. The approved plan can proceed with Task 6.
