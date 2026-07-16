# What's Next

## Work completed and current state

Work is on `feature/cov-12-starter-components`, targeting `origin/main`.
The working tree was clean before this handoff update. The active plan is
[curated-rails-blocks-starter-set.md](../docs/plans/curated-rails-blocks-starter-set.md).

Tasks B0 through B7 are complete and committed.

B6 added `NavbarComponent`, `BreadcrumbComponent`, `UiTabsComponent`,
`PaginationComponent`, and `SidebarComponent`, including their nested
subcomponents, tests, Lookbook previews, kitchen-sink examples, catalog
entries, and component-map nodes. It also added the local `navbar`, `sidebar`,
and `ui-tabs` Stimulus controllers. No third-party imports or importmap changes
were needed for B6.

`UiTabsComponent` is intentional: Jumpstart already has a real
`TabsComponent` in `lib/jumpstart/app/components/tabs_component.rb`, and Jordan
approved the collision-safe Rails Blocks fallback. Leave Jumpstart's
`TabsComponent` and `tabs` controller untouched. The Rails Blocks markup and
controller use only `ui-tabs` identifiers.

`PaginationComponent` expects a real `Pagy` object. Direct test/preview
construction needs a `Pagy::Request`; use the existing examples rather than
passing a bare `Pagy::Offset`. The kitchen sink uses the current request.

`SidebarComponent` intentionally reuses Jumpstart's existing `tooltip`
controller for collapsed-label UI; it does not collide with the new `sidebar`
controller. Generated icon arguments render with `html_safe`, so the catalog
limits them to developer-authored static SVG markup.

B7 added the flat `CardComponent`, including its nested image slot component,
component and preview tests, Lookbook previews, kitchen-sink examples, catalog
entry, and Data Display component-map node. `card` requires no Stimulus
controller, importmap pin, vendored asset, or CDN resource.

Earlier committed batches are B0 (button), B1 (form field), B2 (form controls
and self-hosted tom-select), B3 (static feedback), B4 (toast/tooltip), and B5
(modal/dropdown). All component classes include the required `# AIDEV-NOTE:`
normalization notes where relevant.

## Work Remaining

Continue strictly in order from the approved plan. Before resuming, run:

```sh
git status --porcelain
git branch --show-current
mise exec -- bin/rails db:migrate:status
mise exec -- bin/rails test
```

1. **B8 [next]:** Audit the existing shell, Devise, and account views. Present the
   candidate Rails Blocks extras and stop for Jordan's explicit approval before
   installing anything. Then document the ongoing on-demand install policy.

Do not begin B8 automatically after B7; it is an explicit approval gate.

## Verification

After B7, the following all passed:

- `mise exec -- bin/rails test` — 276 runs, 605 assertions, 0 failures.
- `mise exec -- bundle exec rubocop` — 417 files inspected, no offenses.
- A local Puma smoke check returned 200 for `/dev/kitchen_sink` (93,130 bytes)
  and `/lookbook` (122,769 bytes). The server was stopped cleanly afterward.

Browser automation is unavailable in this workspace. Do not substitute an
unrelated browser. Component tests and the local server/curl smoke check were
used instead; defer interactive visual checks to a browser-enabled session.

## Dead Ends

- `forms` is only a field-group wrapper plus the `form-control` CSS class; it
  does not provide separate input, textarea, label, or error components.
- Do not use `bin/importmap pin tom-select --download`; this importmap version
  rejects that flag. Do not run `importmap pristine` without re-verifying the
  self-contained tom-select bundle.
- The app head has pre-existing external Inter font links and Stripe's billing
  script. Verify that a batch introduces no new external resources rather than
  claiming the whole page has none.
- B4's dry run reported no Motion import even though the plan required
  vendoring it. Motion was locally pinned as required, but is not currently
  imported by `ui_toast_controller.js`.
- For B4 manual follow-up, verify toast creation/dismissal and coexistence of
  Jumpstart's `tooltip` with Rails Blocks' `ui-tooltip`. For B5, verify modal
  open/close and dropdown positioning. These checks require a browser-enabled
  session.

## Open Questions

- B8's candidate extras and any subsequent install require Jordan's approval
  after the audit.
