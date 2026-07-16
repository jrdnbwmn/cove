# What's Next

## Work completed and current state

Work is on `feature/cov-12-starter-components`, targeting `origin/main`.
The working tree is clean; all work described below is committed.

The current plan is [curated-rails-blocks-starter-set.md](../docs/plans/curated-rails-blocks-starter-set.md).
Its status table marks B0 through B3 complete; B4 through B8 remain.

Completed and committed (most recent first):

- `6ab8a99 feature: add alert, badge, loading indicator, skeleton components`
  (B3): installed the four static Feedback components. All four ship with
  **zero JavaScript** in Rails Blocks' default — no Stimulus controller, no
  JS/CSS dep, no CDN link was generated at dry-run, so there was nothing to
  vendor or rename this batch (unlike B1/B2). Flattened to
  `AlertComponent`, `BadgeComponent`, `LoadingIndicatorComponent`,
  `SkeletonComponent`. Notable divergences from the RB defaults, each with an
  `# AIDEV-NOTE:`:
  - `LoadingIndicatorComponent`'s `:primary` color was hard-coded by RB to
    literal `red-600`/`red-500`; remapped to the shared `bg-primary`/
    `text-primary` design tokens, matching `ButtonComponent`'s `:primary`
    convention.
  - Removed two of three inline `style=""` attributes from
    `LoadingIndicatorComponent` (dot/bar `animation-delay`, which only has a
    handful of fixed values) in favor of static Tailwind arbitrary-value
    classes (e.g. `[animation-delay:150ms]`), per the project's
    no-inline-style rule. Kept one inline style for the `:progress` type's
    fill width, since it's an unbounded 0-100 runtime value with no static
    Tailwind class equivalent — documented in both the component and the
    catalog.
  - Documented (did not strip) a latent XSS surface: `AlertComponent`
    inherits RB's `.html_safe` on `description` (an intentional RB feature,
    to allow links/bold text). Added a security caveat in
    `docs/COMPONENT_CATALOG.md` warning it must only be given static,
    developer-authored text, never raw user input.
  - Added component tests (TDD red confirmed before install/normalize, green
    after), Lookbook previews, a Feedback kitchen-sink section, catalog
    entries, and mermaid map nodes for all four.
  - Verified: full `bin/rails test` (256 runs, 562 assertions, 0 failures),
    `bundle exec rubocop` clean after `-A` autocorrect (RB's generated
    indentation/quoting style), local server 200s on `/dev/kitchen_sink` and
    `/lookbook`, and confirmed zero new external network requests (the only
    `<head>` external links are the pre-existing Stripe script and Inter
    font, both out of scope — see Dead Ends).
- `572e614 docs: update session handoff` / `0e20945 feature: add checkbox,
  radio, switch, select, password components` (B2): installed and flattened
  the five Rails Blocks form components; vendored a self-hosted tom-select
  2.6.2 ESM bundle at `vendor/javascript/tom-select.js` (pinned in
  `config/importmap.rb`) with its stylesheet local at
  `app/assets/tailwind/components/tom_select.css`. `conditional-field`,
  `select`, and `password` controllers use their non-colliding default
  identifiers and are eager-auto-registered.
- `e0b758e feature: add form field component` (B1): installed Rails Blocks
  `forms`, renamed `Forms::Component` to flat `FormFieldComponent`, kept the
  bundled `nested_form_controller.js`.
- `13d99cb feature: normalize button to ButtonComponent` (B0): moved the
  namespaced button and its preview/test to flat `ButtonComponent` paths,
  recorded the eager Stimulus auto-scan plus `ui-*` collision convention in
  `app/javascript/controllers/index.js`.

## Work Remaining

Continue the remaining plan tasks strictly sequentially using the Standard
Batch Workflow in
[curated-rails-blocks-starter-set.md](../docs/plans/curated-rails-blocks-starter-set.md).
Begin with the normal execute-plan preflight (`git status`,
`mise exec -- bin/rails db:migrate:status`, `mise exec -- bin/rails test`,
and confirm the feature branch).

1. **B4 [next]:** install `toast` and `tooltip`. Before installation, check
   whether a real `ToastComponent` already exists in `app/components/` (vs.
   README lore) — if real, install RB as `UiToastComponent` and **stop for
   Jordan's approval** before proceeding; if only lore, use the plain flat
   name. Rename controller identifiers to `ui-toast` / `ui_toast_controller.js`
   and `ui-tooltip` / `ui_tooltip_controller.js` (Jumpstart's
   `notifications_controller.js` and `tooltip_controller.js` stay
   untouched). Vendor motion (toast) into `vendor/javascript/` + importmap;
   confirm floating-ui (tooltip) is already vendored and reuse it — don't
   re-add. Step 11 must browser-verify both Jumpstart's tooltip AND RB's
   `ui-tooltip` coexist without console/network errors. Commit
   `feature: add toast and tooltip components`.
2. B5: install `modal` and `dropdown`, with `ui-modal` and `ui-dropdown`
   controller names (both collide with tailwindcss-stimulus-components).
   Confirm question #1 for `ModalComponent` (plain vs. `UiModalComponent` +
   fallback approval, same pattern as B4).
3. B6: install `navbar`, `breadcrumb`, `tabs`, `pagination`, and `sidebar`.
   `ui-tabs` for the `tabs` collision; confirm question #1 for
   `TabsComponent`.
4. B7: install and flatten `card`, with its tests, preview, kitchen-sink
   example, catalog, and map.
5. B8: audit shell/Devise/account views and present the candidate Rails
   Blocks extras to Jordan. **Explicit approval gate** — do not install
   extras without it. After approval, install only the approved extras and
   document the standing on-demand policy in
   `docs/COMPONENT_CATALOG.md`.

## Dead Ends

- Do not repeat the original B1 discovery: `forms` is only a field-group
  wrapper plus the shared `form-control` CSS; it does not ship separate
  input, textarea, label, or error components.
- `bin/importmap pin tom-select --download` and the flags-first variant both
  fail in this Rails/importmap version. Plain `mise exec -- bin/importmap pin
  tom-select` downloads/pins the package, but its initial downloaded entry
  was not a self-contained ESM module — B2 replaced the vendor file with the
  self-contained 2.6.2 ESM bundle while retaining the local importmap pin.
  Do not run `importmap pristine` unless you re-verify the bundle imports.
- Browser automation is unavailable in this workspace: the browser runtime
  initialized but exposed no browser backends. Do not substitute an
  unrelated browser tool. Use local server/curl plus component tests; a
  later session with a browser should visually check light/dark states and
  interactive behavior (this matters more starting at B4/B5, which are
  interactive).
- The shared application head already contains external Inter font links at
  `app/views/application/_head.html.erb` and a Stripe script for billing.
  Both predate this ticket and were not changed in B0-B3, so a whole-app
  zero-network claim cannot be made without a separate scoped decision to
  self-host the fonts (Stripe's script is presumably required for its
  client-side SDK and likely out of scope entirely).
- B3's four components needed no Stimulus registration, no vendoring, and no
  CDN removal — don't assume every future batch is this light; B4 (toast,
  tooltip) resumes the interactive/vendoring pattern from B2.

## Open Questions

- B4, B5, and B6 each require Jordan's approval if the specified existing
  component class (`ToastComponent`, `ModalComponent`, or `TabsComponent`)
  is real and Rails Blocks must use a `Ui`-prefixed class. Check
  `app/components/` for each before installing.
- B8 has an explicit approval gate after its shell-port audit.
- Interactive browser/network-panel verification remains unavailable until
  a browser is exposed to the workspace — B4/B5's open/close, positioning,
  and dual-controller-coexistence checks currently rely on local
  server/curl + component tests only.
