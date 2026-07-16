# What's Next

## Work completed and current state

Work is on `feature/cov-12-starter-components`, targeting `origin/main`.
The working tree was clean after the last feature commit.

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

The current plan is [curated-rails-blocks-starter-set.md](../docs/plans/curated-rails-blocks-starter-set.md).
Its status table marks B0 and B1 complete; B2 through B8 remain.

Verification completed for B1:

- `mise exec -- bin/rails test` passed: 237 runs, 537 assertions.
- `mise exec -- bundle exec rubocop -A` on the B1 Ruby/test files passed.
- A local Rails server returned HTTP 200 for `/dev/kitchen_sink` and
  `/lookbook`; kitchen-sink HTML contains the input, textarea, select, helper,
  error, disabled, required, size, and dark-mode examples.
- `app/assets/builds/tailwind.css` confirms Jumpstart's `.form-control` rules
  are emitted first and Rails Blocks' later rules take precedence. No existing
  CSS was deleted or changed.

## Work Remaining

Execute the remaining tasks sequentially, following the Standard Batch Workflow
in the plan. Each task must dry-run with `rails-blocks install ... --as
view_component --path app/components --stimulus-path app/javascript/controllers
--dry-run`, be test-first, update previews/kitchen sink/catalog/map, run the
full suite, review, update the status table, and commit one batch.

1. B2: install `checkbox`, `radio`, `switch`, `select`, and `password`.
   Vendor tom-select JavaScript and stylesheet locally, pin it in
   `config/importmap.rb`, remove/avoid every CDN link, and check the select
   controller for collisions.
2. B3: install and flatten `alert`, `badge`, `loading_indicator`, and
   `skeleton`; rename any generated `alert` controller to `ui-alert` if the
   dry run confirms it collides.
3. B4: install toast and tooltip. Before installing, check for existing real
   `ToastComponent`; a real component requires user approval for the
   `UiToastComponent` fallback. Rename controllers to `ui-toast` and
   `ui-tooltip`, vendor motion, and reuse the already-vendored floating-ui.
4. B5: install modal and dropdown. Check for an existing real
   `ModalComponent`; approval is required for a `UiModalComponent` fallback.
   Rename controllers to `ui-modal` and `ui-dropdown`.
5. B6: install navbar, breadcrumb, tabs, pagination, and sidebar. Check for a
   real `TabsComponent` before using a `UiTabsComponent` fallback; rename the
   controller to `ui-tabs`.
6. B7: install and flatten card.
7. B8: audit the shell, Devise, and account views. Stop and present the extra
   Rails Blocks component list for Jordan's approval before installing any of
   them. Then document the on-demand-install policy.

Known shared dependencies and conventions:

- Floating UI is already local and pinned in `config/importmap.rb` and
  `vendor/javascript/`; do not add it again.
- Keep `eagerLoadControllersFrom("controllers", application)`; controllers
  auto-register by filename. Rename collisions to `ui_*_controller.js` and use
  `data-controller="ui-*"` in templates.
- Use design-token utilities; do not introduce arbitrary Tailwind values.
- Use `mise exec --` for Rails/RuboCop commands.

## Dead Ends

- The original B1 assumption was invalid: `rails-blocks install forms` writes
  only `Forms::Component` and `nested_form_controller.js`, not four field
  primitives. The corrected plan is committed as `e9803be`; do not repeat the
  old discovery.
- Browser automation could not be used in this workspace: the browser runtime
  initialized, but `agent.browsers.list()` returned `[]`. Do not substitute an
  unrelated browser tool. Local server/curl and compiled-CSS checks were used
  instead. A later session with an available browser should still visually
  inspect light/dark states and the interactive B4/B5 behaviors.
- Lookbook's index returned HTTP 200 but its application showed the normal
  blank-slate page. Component preview tests (`render_preview`) passed; use
  those tests rather than assuming the index lists previews.

## Open Questions

- B4, B5, and B6 each require Jordan's approval if the specified existing
  component class (`ToastComponent`, `ModalComponent`, or `TabsComponent`) is
  real and Rails Blocks must use a `Ui`-prefixed class.
- B8 has an explicit approval gate after its shell-port audit.
- Interactive browser/network-panel verification remains unavailable until a
  browser is exposed to the workspace.
