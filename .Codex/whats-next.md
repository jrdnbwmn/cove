# What's Next

## Work completed and current state

Work is on `feature/cov-12-starter-components`, targeting `origin/main`.
The working tree was clean when this handoff was written. The active plan is
[curated-rails-blocks-starter-set.md](../docs/plans/curated-rails-blocks-starter-set.md).

Tasks B0 through B4 are complete and committed:

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

Latest B4 verification:

- `mise exec -- bin/rails test` — 260 runs, 570 assertions, 0 failures.
- `mise exec -- bundle exec rubocop` — clean.
- `mise exec -- bin/importmap json` — valid import map.
- Local server smoke check: `/dev/kitchen_sink` and `/lookbook` both returned
  200. The kitchen sink rendered `tooltip`, `ui-tooltip`, and `ui-toast`.

## Work Remaining

Continue strictly in order from the approved plan. Begin with normal
preflight: `git status --porcelain`, `mise exec -- bin/rails db:migrate:status`,
`mise exec -- bin/rails test`, and confirm the feature branch.

1. **B5 [next]:** Install Rails Blocks `modal` and `dropdown`. Both controller
   names collide, so use `ui-modal` and `ui-dropdown`; keep existing Jumpstart
   controllers intact. Check for a real `ModalComponent` before flattening. If
   it exists, pause for Jordan's approval to use `UiModalComponent`.
2. **B6:** Install `navbar`, `breadcrumb`, `tabs`, `pagination`, and `sidebar`.
   Use `ui-tabs` for the controller collision. Check for a real
   `TabsComponent`; request approval before using `UiTabsComponent` if needed.
3. **B7:** Install and flatten `card`, then add tests, preview, kitchen-sink,
   catalog, and map entries.
4. **B8:** Audit the existing shell, Devise, and account views. Present the
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

- B5 and B6 require a fallback-approval check if Jumpstart has real
  `ModalComponent` or `TabsComponent` classes.
- B8 has an explicit approval gate after its audit.
- A later browser-enabled session should manually verify interactive B4
  behavior: toast creation/dismissal and both the Jumpstart `tooltip` and
  Rails Blocks `ui-tooltip` hover/click behavior.
