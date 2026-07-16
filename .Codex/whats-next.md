# What's Next

## Work completed and current state

Work is on `feature/cov-12-starter-components`, targeting `origin/main`.
The working tree is clean at this handoff. The active plan is
[curated-rails-blocks-starter-set.md](../docs/plans/curated-rails-blocks-starter-set.md).

Tasks B0 through B5 are complete and committed:

- `02e63fe feature: add modal and dropdown components` (B5) added
  `UiModalComponent` because Jumpstart already defines
  `ModalComponent`, plus `DropdownComponent` with Rails Blocks' internal item
  subcomponents. The generated controllers are collision-safe:
  `ui-modal`, `ui-dropdown-popover`, `ui-menu`, and
  `ui-searchable-dropdown`. Existing Jumpstart controllers remain untouched.
  Floating UI was already vendored and pinned, so B5 added no external
  dependency. Component tests, Lookbook previews, light/dark Overlays
  kitchen-sink examples, catalog entries, and component-map nodes were added.

- `7f9fcaf feature: add toast and tooltip components` (B4) added the
  Rails Blocks `UiToastComponent` and `TooltipComponent`, plus collision-free
  `ui-toast` and `ui-tooltip` Stimulus controllers. It locally vendored Motion
  12.42.2 and reused the existing local Floating UI packages. The catalog
  explicitly requires `UiToastComponent` for all new product toast work;
  Jumpstart's `ToastComponent` remains untouched for its existing behavior.
  Plain toast/tooltip text is escaped. The toast API's custom HTML option must
  receive only static, developer-authored content. Component tests, Lookbook
  previews, Feedback kitchen-sink examples, and component-map entries were
  added.
- `6ab8a99 feature: add alert, badge, loading indicator, skeleton components`
  (B3) added the four static Feedback components.
- `0e20945 feature: add checkbox, radio, switch, select, password components`
  (B2) added the remaining form components and locally vendored tom-select.
- `e0b758e feature: add form field component` (B1) added the flat
  `FormFieldComponent` wrapper and retained `nested_form_controller.js`.
- `13d99cb feature: normalize button to ButtonComponent` (B0) established the
  flat component convention and the collision-safe `ui-*` controller rule.

Latest B5 verification:

- `mise exec -- bin/rails test` — 264 runs, 583 assertions, 0 failures.
- `mise exec -- bundle exec rubocop` — clean.
- `mise exec -- bin/importmap json` — valid import map.
- Local server smoke check: `/dev/kitchen_sink` and `/lookbook` both returned
  200. The kitchen sink rendered `ui-modal`, `ui-dropdown-popover`, and
  `ui-menu`.

## Work Remaining

Continue strictly in order from the approved plan. Begin with normal
preflight: `git status --porcelain`, `mise exec -- bin/rails db:migrate:status`,
`mise exec -- bin/rails test`, and confirm the feature branch.

1. **B6 [next]:** Install `navbar`, `breadcrumb`, `tabs`, `pagination`, and `sidebar`.
   Use `ui-tabs` for the controller collision. Check for a real
   `TabsComponent`; request approval before using `UiTabsComponent` if needed.
2. **B7:** Install and flatten `card`, then add tests, preview, kitchen-sink,
   catalog, and map entries.
3. **B8:** Audit the existing shell, Devise, and account views. Present the
   candidate Rails Blocks extras and stop for Jordan's approval before
   installing anything. Then document the ongoing on-demand install policy.

For every batch, follow the plan's Standard Batch Workflow: Rails Blocks CLI
discovery/docs, dry run, TDD, install, self-host dependencies, collision/token
pass, flat normalization with `# AIDEV-NOTE:`, previews, kitchen sink,
catalog/map, verification, review, and one batch commit.

## Dead Ends

- `forms` is only a field-group wrapper plus the `form-control` CSS class; it
  does not provide separate input, textarea, label, or error components.
- Do not use `bin/importmap pin tom-select --download`; this importmap version
  rejects that flag. Do not run `importmap pristine` without re-verifying the
  self-contained tom-select bundle.
- Browser automation has no backend in this workspace. Do not substitute an
  unrelated browser tool. Use component tests plus a local server/curl smoke
  check, and leave visual interaction/network-panel verification for a session
  with a browser.
- The app head has pre-existing external Inter font links and Stripe's billing
  script. Do not claim the whole page makes zero external requests; only verify
  that a batch introduces none.
- The B4 dry run reported no Motion import even though the plan required
  vendoring it. Motion was still locally pinned as required, but it is not
  currently imported by `ui_toast_controller.js`.

## Open Questions

- B6 requires a fallback-approval check if Jumpstart has a real
  `TabsComponent` class.
- B8 has an explicit approval gate after its audit.
- A later browser-enabled session should manually verify interactive B4
  behavior (toast creation/dismissal and both the Jumpstart `tooltip` and Rails
  Blocks `ui-tooltip` hover/click) and B5 behavior (modal open/close and
  dropdown positioning).
