# What's Next

## Work completed and current state

Work is on `feature/cov-12-starter-components`, targeting `origin/main`.
The working tree was clean after the latest feature commit.

The current plan is [curated-rails-blocks-starter-set.md](../docs/plans/curated-rails-blocks-starter-set.md).
Its status table marks B0, B1, and B2 complete; B3 through B8 remain.

Completed and committed:

- `13d99cb feature: normalize button to ButtonComponent` (B0): moved the
  namespaced button and its preview/test to flat `ButtonComponent` paths,
  updated the kitchen sink, catalog, and component map, and recorded the
  eager Stimulus auto-scan plus `ui-*` collision convention in
  `app/javascript/controllers/index.js`.
- `e9803be docs: revise B1 around RB Forms::Component wrapper`: corrected the
  plan after CLI discovery showed `forms` is one wrapper, not separate input,
  textarea, label, and error components.
- `e0b758e feature: add form field component` (B1): installed Rails Blocks
  `forms`, renamed `Forms::Component` to flat `FormFieldComponent`, kept the
  bundled `nested_form_controller.js`, added previews/tests/kitchen-sink
  examples, and documented it in the catalog and map.
- `0e20945 feature: add checkbox, radio, switch, select, password components`
  (B2): installed and flattened the five Rails Blocks components; added their
  component tests, previews, kitchen-sink examples, catalog entries, and map
  nodes. `conditional-field`, `select`, and `password` controllers use their
  non-colliding default identifiers and are eager-auto-registered.

`SelectComponent` uses a self-hosted tom-select 2.6.2 bundle at
`vendor/javascript/tom-select.js`, pinned in `config/importmap.rb`; its
stylesheet is local at `app/assets/tailwind/components/tom_select.css` and
imported by `app/assets/tailwind/application.css`. There are no B2 CDN tags.
Both generated inline styles were removed to meet the project component rule.

Verification completed for B2:

- TDD RED: the five component tests failed with missing flat component classes;
  after installation/normalization they passed. The five preview tests then
  failed until their previews were added and passed afterwards.
- `mise exec -- bundle exec rubocop ...` on all B2 Ruby/test/preview files:
  15 files inspected, no offenses.
- `mise exec -- bin/rails test`: 247 runs, 552 assertions, 0 failures,
  0 errors, 0 skips.
- A local Rails server returned HTTP 200 for `/dev/kitchen_sink` and
  `/lookbook`; kitchen-sink HTML contains the local `tom-select` asset pin,
  `data-controller="select"`, and `data-controller="password"`.
- `git diff --check` passed before `0e20945` was committed.

## Work Remaining

Continue the remaining plan tasks strictly sequentially using the Standard
Batch Workflow. Begin with the normal execute-plan preflight (`git status`,
`mise exec -- bin/rails db:migrate:status`, `mise exec -- bin/rails test`, and
confirm the feature branch).

1. B3: install `alert`, `badge`, `loading_indicator`, and `skeleton` as flat
   ViewComponents. Dry-run each first with the exact ViewComponent and
   controller paths in the plan. Confirm whether `alert` creates a controller;
   rename it to `ui_alert_controller.js` and use `ui-alert` if it conflicts
   with `tailwindcss-stimulus-components`. Add tests before install, previews,
   Feedback kitchen-sink examples, catalog/map updates, full suite, review,
   status checkmark, and commit `feature: add alert, badge, loading indicator, skeleton components`.
2. B4: install `toast` and `tooltip`. Before installation, check whether a
   real `ToastComponent` exists. If it does, stop for Jordan's approval before
   using `UiToastComponent`. Rename controller identifiers to `ui-toast` and
   `ui-tooltip`; vendor motion locally and reuse the already-local floating UI.
3. B5: install `modal` and `dropdown`, with `ui-modal` and `ui-dropdown`
   controller names. Stop for Jordan's approval if a real `ModalComponent`
   means the Rails Blocks component needs a `Ui` prefix.
4. B6: install `navbar`, `breadcrumb`, `tabs`, `pagination`, and `sidebar`.
   Use `ui-tabs`; stop for approval if a real `TabsComponent` exists.
5. B7: install and flatten `card`, with its tests, preview, kitchen-sink
   example, catalog, and map.
6. B8: audit shell/Devise/account views and present the candidate Rails Blocks
   extras to Jordan. This is an explicit approval gate: do not install extras
   without it. After approval, install only the approved extras and document
   the standing on-demand policy.

## Dead Ends

- Do not repeat the original B1 discovery: `forms` is only a field-group
  wrapper plus the shared `form-control` CSS; it does not ship separate input,
  textarea, label, or error components.
- `bin/importmap pin tom-select --download` and the flags-first variant both
  fail in this Rails/importmap version. Plain `mise exec -- bin/importmap pin
  tom-select` downloads/pins the package. Its initial downloaded entry was not
  a self-contained ESM module, so B2 replaced the vendor file with the
  self-contained 2.6.2 ESM bundle while retaining the local importmap pin. Do
  not run `importmap pristine` unless you re-verify the bundle imports.
- Browser automation is unavailable in this workspace: the browser runtime
  initialized but exposed no browser backends. Do not substitute an unrelated
  browser tool. Use local server/curl plus component tests; a later session
  with a browser should visually check light/dark states and interactive
  behavior.
- The shared application head already contains external Inter font links at
  `app/views/application/_head.html.erb`. They predate this ticket and were not
  changed in B2, so a whole-app zero-network claim cannot be made without a
  separate scoped decision to self-host those fonts.

## Open Questions

- B4, B5, and B6 each require Jordan's approval if the specified existing
  component class (`ToastComponent`, `ModalComponent`, or `TabsComponent`) is
  real and Rails Blocks must use a `Ui`-prefixed class.
- B8 has an explicit approval gate after its shell-port audit.
- Interactive browser/network-panel verification remains unavailable until a
  browser is exposed to the workspace.
