# What's Next

## Work completed and current state

COV-15, “Rebuild account + billing (Pay) views with design-system components,”
is active on `feature/cov-15-rebuild-billing-views` (target: `origin/main`).
Tasks 1–3 of 14 are complete, reviewed, and committed. The worktree is clean.

- `79e9d3f feature: add billing plan card component` — Task 1: added the
  composed `PlanCardComponent`, Lookbook previews, component tests, catalog
  entry, and composition-map relationship. The component supports caller block
  content and an explicit `with_actions` slot. Its contact-price key is
  `billing.subscriptions.plan.contact_us_price`.
- `df1d5d0 feature: rebuild password and API token forms` — Task 2: app-level
  shadows for account password editing and API-token form/new/edit. Password
  fields preserve `user[...]` names and autocomplete values; the API token
  form preserves `api_token[name]`, autofocus, and create/update/cancel routes.
- `567f1ad feature: rebuild API token display views` — Task 3: app-level token
  index/show shadows using `TableComponent`, `BadgeComponent`, and
  `ButtonComponent`. Clipboard attributes remain `clipboard tooltip`,
  `tooltip_content_value`, and `clipboard_text`; the revoke link retains Turbo
  delete/confirm data.

Verification after Task 3:

- `mise exec -- bin/rails test` — 288 runs, 629 assertions, 0 failures.
- `mise exec -- bin/rubocop` — 432 files inspected, no offenses.
- `git diff --check` passed.

The approved plan is [docs/plans/rebuild-billing-views.md](../docs/plans/rebuild-billing-views.md).
The saved design is [docs/designs/rebuild-billing-views.md](../docs/designs/rebuild-billing-views.md).

## Work Remaining

Resume at Task 4 (Master), then follow the plan in order:

1. Create `app/views/accounts/_form.html.erb`, `new.html.erb`, and `edit.html.erb` as app-level shadows. Use `FormFieldComponent` for name/domain/subdomain/avatar and `ButtonComponent` for submit/cancel. Preserve all field names, `autofocus`, the file accept list, `account_avatar`, and the exact `Jumpstart::Multitenancy.domain?` / `.subdomain?` guards. Preserve edit’s conditional `button_to` delete and transfer partial. Verify with `mise exec -- bin/rails test test/controllers/accounts_controller_test.rb`, review, then mark Task 4 done.
2. After Task 4, delegate Tasks 5–7 as the plan marks them Clone. Task 6 has a mandatory stop condition: `CheckboxComponent` has no hidden `"0"` companion, so confirm role checkbox params round-trip unchanged before implementation; ask the user if they do not.
3. Continue Tasks 8–13 in dependency order. Task 8 establishes the `PlanCardComponent` call shape for Task 11. Task 9 requires the app-level Stripe form shadow to be byte-identical to the engine source.
4. Run Task 14 last: selector migration, integration/system coverage, full Rails + system-test gate, and browser verification.

Global plan constraints: create only app-level shadows; do not edit
`lib/jumpstart/`; run all Rails/bin commands with `mise exec --`; preserve
routes, params, `Current.meta_tags`, sidebar content, Pundit/config guards,
Turbo confirmation data, Stimulus attributes, and Pagy conditions exactly.
Use `FormFieldComponent#with_input` to retain raw field options. `PasswordComponent`
must receive explicit `name`, `autocomplete`, `placeholder`, and error values.

## Dead Ends

- `mise exec -- bin/rubocop <erb files>` parses ERB as Ruby and emits syntax
  errors. Run the normal project-wide `mise exec -- bin/rubocop` command,
  which is configured to inspect supported files, plus Rails tests and
  `git diff --check`.
- A direct `ApplicationController.render` smoke test needs `locals:` for a
  partial local (not `assigns:`). Rendering full authenticated templates this
  way is not useful because the layout expects session/Warden state.
- In this checkout, always use `mise exec --`; system Ruby/Bundler does not
  boot the project correctly.

## Open Questions

None. The approved plan can proceed at Task 4.
