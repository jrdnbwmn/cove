> Ticket: COV-12
> Branch: feature/cov-12-starter-components

# Plan: Curated Rails Blocks starter set (self-hosted, lazy JS)

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| B0   | Normalize button → `ButtonComponent`; establish Stimulus/self-host/collision conventions | Master | ✅ |
| B1   | Forms A: `forms` field-group wrapper → `FormFieldComponent` + `form-control` class | Master | ✅ |
| B2   | Forms B: checkbox, radio, switch, select (vendor tom-select), password | Master | ✅ |
| B3   | Feedback static: alert, badge, loading_indicator, skeleton | Master | ✅ |
| B4   | Feedback interactive: toast (`ui-toast`, motion), tooltip (`ui-tooltip`) | Master | ✅ |
| B5   | Overlays: modal, dropdown | Master | ✅ |
| B6   | Navigation: navbar, breadcrumb, tabs, pagination, sidebar | Master | ✅ |
| B7   | Data Display: card | Master | ✅ |
| B8   | Shell-port extras audit + install (approval gate) + document on-demand policy | Master | ✅ |

## Prerequisites

- Design: `docs/designs/curated-rails-blocks-starter-set.md`
- Prototype: None (RB defaults + existing design tokens)
- Feature branch `feature/cov-12-starter-components` already exists (current branch).
- `rails-blocks` CLI present (`/Users/jordan/.local/share/mise/installs/ruby/latest/bin/rails-blocks`).
  Confirm Pro auth with `rails-blocks whoami` → `pro: true` before B0.
- Use the **`rails-blocks-cli` skill** for ALL Rails Blocks operations. Never the RB MCP.
  Always `--dry-run` first; never `--force`; install `--as view_component`.

## Stimulus registration decision (settled)

`app/javascript/controllers/index.js` uses
`eagerLoadControllersFrom("controllers", application)` — every `*_controller.js`
in `app/javascript/controllers/` is auto-registered by its filename identifier.
The design doc's "lazy, explicit registration" language technically conflicts with
this. **Decision: keep the eager auto-scan.** With import maps, a registered
controller's code is not downloaded until a matching `data-controller` element
appears in the DOM, so "eager" here only means "known to the app," not "running."
This already satisfies the design's real goals — components' code loads only when
used, and Jumpstart's existing controllers stay untouched. RB controllers get
`ui-*` filenames so they auto-register under collision-free identifiers. We do NOT
rip out `eagerLoadControllersFrom` (that would touch the file wiring up all
existing Jumpstart controllers for no real-world benefit). B0 records this as an
`# AIDEV-NOTE:` in `index.js`.

## Standard Batch Workflow (applies to every task B1–B8)

Each batch is one commit: `feature: add <components> components`.

1. **Discover/confirm names:** `rails-blocks list` / `search` / `docs <slug>` to
   confirm each fuzzy slug (show the mapping before installing).
2. **Dry-run each component:** `rails-blocks install <slug> --as view_component
   --path app/components --stimulus-path app/javascript/controllers --dry-run`.
   Report the files it would write, the Stimulus controllers, JS/CSS deps, and
   any CDN `<link>`/`<script>`.
3. **Install for real** (drop `--dry-run`; never `--force`).
4. **Self-host deps:** vendor every JS/CSS dep into `vendor/javascript/` and pin
   in `config/importmap.rb` (`bin/importmap pin --download` or manual). Vendor any
   CSS that ships as a CDN `<link>` into the asset pipeline. **ZERO `<head>` CDN
   links.** (floating-ui is already vendored+pinned — confirm, don't re-add.)
5. **Register Stimulus + apply collision rules** per B0's convention. Any RB
   controller whose identifier collides with an existing registration
   (`accounts, autogrow, bulk, clipboard, notifications, pricing, theme, tooltip,
   unfurl_link` from files; `alert, dropdown, modal, tabs, popover, toggle,
   slideover` from tailwindcss-stimulus-components) is renamed `ui-*`
   (`ui_x_controller.js` + `data-controller="ui-x"`). Jumpstart's stays. Never
   overwrite a Jumpstart controller without approval.
6. **Token-accent pass** (style-ui): primary accents → `bg-primary` /
   `text-primary-foreground`; true neutrals stay on the neutral scale. Verify
   light + dark.
7. **Normalize to flat shape:** `FooComponent` at `app/components/foo_component.rb`
   + `.html.erb`. One `# AIDEV-NOTE:` per convention divergence.
8. **Lookbook preview:** `test/components/previews/foo_component_preview.rb`
   (`FooComponentPreview`) — default + variants + edge/error state.
9. **Kitchen sink:** render each component under its category `<section>` in
   `app/views/dev/kitchen_sink/show.html.erb`, light + dark.
10. **Docs:** run `/update-catalog` and `/update-component-previews`; add/refresh
    the component's node in `docs/architecture/component-map.mermaid` under its
    category subgraph.
11. **Verify:** `bin/rails test` (show output). Boot the app, load `/lookbook` and
    `/dev/kitchen_sink`; confirm no importmap/console errors and **no external
    network requests** (browser-verified — Claude in Chrome network panel).
12. **Review:** run `/review-changes`, then commit the batch.

## Tasks

### Task B0 [Master]: Normalize button + establish conventions

**Skills:** style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Reference:** `app/components/buttons/component.rb`, `test/components/previews/buttons/component_preview.rb`, `app/views/dev/kitchen_sink/show.html.erb`, `docs/COMPONENT_CATALOG.md`, `docs/architecture/component-map.mermaid`, `app/javascript/controllers/index.js`

**In scope:**
- Rename `Buttons::Component` → `ButtonComponent`; move
  `app/components/buttons/component.{rb,html.erb}` →
  `app/components/button_component.{rb,html.erb}`; delete the `buttons/` folder.
- Move preview → `test/components/previews/button_component_preview.rb`
  (`ButtonComponentPreview`); update the kitchen-sink render, catalog entry, and
  the `buttons` subgraph node in `component-map.mermaid`.
- Record the settled Stimulus decision (keep eager auto-scan; `ui-*` for
  collisions) as a short `# AIDEV-NOTE:` in `index.js`; note it for later
  documentation in B8's policy section.
- Confirm floating-ui is already vendored/pinned; note tom-select (B2) and
  motion (B4) as the only outstanding vendor tasks.

**NOT in scope:**
- Installing any new RB component. Changing button behavior/args/variants.
- Removing/replacing `eagerLoadControllersFrom` (settled: keep it).
- Mapping Jumpstart's full `--radius` scale (pre-existing out-of-scope note).

**Build order:**
1. **Test:** update button component/preview tests to the new class name/path;
   confirm they reference `ButtonComponent`.
2. **Implement:** rename files/class, update kitchen sink, catalog, mermaid,
   index.js note.
3. **Verify:** `bin/rails test test/components/button_component_test.rb` (or the
   existing button test path), then full `bin/rails test`. Boot `/dev/kitchen_sink`.
4. **Review:** run `/review-changes`, then commit `feature: normalize button to ButtonComponent`.

### Task B1 [Master]: Forms A — the `forms` field-group wrapper

**Skills:** rails-blocks-cli, style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Slug:** `forms`

**Reality correction (confirmed at dry-run, 2026-07-16):** Rails Blocks has NO
separate input/textarea/label/error-help components — those slugs do not exist
(`rails-blocks search input|textarea|label|field` all return nothing). RB's
`forms` slug installs a **single field-group wrapper** `Forms::Component`
(label + `with_input` slot + helper/error text) plus a shared `.form-control`
CSS class applied to raw `<input>`/`<textarea>`/`<select>`. The `.form-control`
CSS is **already installed** at `app/assets/tailwind/rails_blocks/base.css`
(`.form-control`, `.form-control[disabled]`, `.form-control.error`) — nothing to
vendor. The install also writes `app/javascript/controllers/nested_form_controller.js`.

**In scope:**
- Install `forms`; normalize `Forms::Component` → flat **`FormFieldComponent`**
  at `app/components/form_field_component.{rb,html.erb}` (one `# AIDEV-NOTE:` on
  the divergence). Preserve its `with_input` slot and label/helper/error/
  required/disabled/size/variant options.
- Keep the bundled `nested_form_controller.js` as installed (no name collision;
  eager-load auto-registers it). No UX built around it this ticket.
- Preview + kitchen-sink Forms section demonstrating the wrapper across states —
  default, helper text, error, disabled, required, sizes (sm/md/lg), variants
  (default/floating/inline) — wrapping raw `<input>`, `<textarea>`, and
  `<select class="form-control">`. This is how input/textarea/label/error styling
  is demonstrated (via wrapper + `form-control`), documented as ONE catalog entry.
- Catalog, mermaid Forms subgraph node.

**NOT in scope:** checkbox/radio/switch/select/password (B2). Any form
*object*/model wiring. Building nested-form add/remove UX. Producing separate
Input/Textarea/Label components (they don't exist in RB).

**Collision to verify (CSS):** Jumpstart also defines `.form-control` in
`app/assets/tailwind/components/forms.css`; RB defines it in
`rails_blocks/base.css`. Confirm which wins in the compiled build and that RB's
field styling renders correctly in light + dark. If they conflict visibly,
surface it for approval before reconciling — do NOT silently delete Jumpstart's.

**Build order:** Follow the **Standard Batch Workflow**. Step 4: no JS/CSS to
vendor (form-control CSS already present; nested_form is a local controller with
no external dep) — confirm at dry-run. Step 5: verify `nested_form` doesn't
collide. Verify light+dark, error, and disabled states. Commit
`feature: add form field component`.

### Task B2 [Master]: Forms B — checkbox, radio, switch, select, password

**Skills:** rails-blocks-cli, style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Slugs:** `checkbox`, `radio`, `switch`, `select`, `password`

**In scope:** Install all five as flat ViewComponents. **Vendor tom-select**
(JS + its stylesheet) into `vendor/javascript/` + asset pipeline, pin in
importmap — zero CDN links. Previews, kitchen-sink, catalog, mermaid.

**NOT in scope:** Multi-select/tagging UX beyond RB defaults. Rewiring existing
Jumpstart form controllers.

**Build order:** Follow the **Standard Batch Workflow**. Extra attention at step
4: tom-select ships a CDN stylesheet — vendor it, do not `<link>` it. Confirm
`select`'s Stimulus identifier for collisions (rename `ui-*` if needed). Commit
`feature: add checkbox, radio, switch, select, password components`.

### Task B3 [Master]: Feedback static — alert, badge, loading_indicator, skeleton

**Skills:** rails-blocks-cli, style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Slugs:** `alert`, `badge`, `loading_indicator` (spinner), `skeleton`

**In scope:** Four flat ViewComponents (mostly static). Previews, kitchen-sink
Feedback section, catalog, mermaid.

**NOT in scope:** toast/tooltip (B4 — the interactive collision cases).

**Build order:** Follow the **Standard Batch Workflow**. Note: RB `alert` may
ship a controller colliding with the `alert` registration from
tailwindcss-stimulus-components — rename `ui-alert` if so. Commit
`feature: add alert, badge, loading indicator, skeleton components`.

### Task B4 [Master]: Feedback interactive — toast + tooltip (collision cases)

**Skills:** rails-blocks-cli, style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Slugs:** `toast`, `tooltip`

**In scope:**
- Install both; apply the recorded collision resolution: toast →
  `ui-toast` / `ui_toast_controller.js` (JSP `notifications_controller.js` stays);
  tooltip → `ui-tooltip` / `ui_tooltip_controller.js` (JSP `tooltip_controller.js`
  stays).
- **Vendor motion** (toast) into `vendor/javascript/` + importmap. Confirm
  floating-ui (tooltip) is already vendored — reuse, don't re-add.
- Confirm question #1: check whether a real `ToastComponent` exists in
  `app/components/` (vs README lore). If real → install RB as `UiToastComponent`
  and raise as a fallback-approval case; if only lore → plain flat name.

**NOT in scope:** Replacing Jumpstart's notifications feed with RB toast.

**Build order:** Follow the **Standard Batch Workflow**. Step 11 must
browser-verify BOTH behaviors coexist (Jumpstart tooltip AND `ui-tooltip`).
Commit `feature: add toast and tooltip components`.

### Task B5 [Master]: Overlays — modal, dropdown

**Skills:** rails-blocks-cli, style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Slugs:** `modal`, `dropdown`

**In scope:** Install both. Both have Stimulus identifiers colliding with
tailwindcss-stimulus-components (`modal`, `dropdown`) → rename `ui-modal` /
`ui-dropdown`. floating-ui already vendored — confirm, reuse. Confirm question
#1 for `ModalComponent` (plain vs `UiModalComponent` + fallback approval).
Previews, kitchen-sink Overlays section, catalog, mermaid.

**NOT in scope:** slideover (not in the curated set).

**Build order:** Follow the **Standard Batch Workflow**. Browser-verify open/close
+ positioning with no console/network errors. Commit
`feature: add modal and dropdown components`.

### Task B6 [Master]: Navigation — navbar, breadcrumb, tabs, pagination, sidebar

**Skills:** rails-blocks-cli, style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Slugs:** `navbar`, `breadcrumb`, `tabs`, `pagination`, `sidebar`

**In scope:** Five flat ViewComponents. `tabs` collides with the
tailwindcss-stimulus-components `tabs` registration → `ui-tabs`; confirm question
#1 for `TabsComponent` (plain vs `UiTabsComponent` + fallback approval).
Previews, kitchen-sink Navigation section, catalog, mermaid.

**NOT in scope:** Wiring navbar/sidebar into the real app shell (Ticket 4).

**Build order:** Follow the **Standard Batch Workflow**. Commit
`feature: add navbar, breadcrumb, tabs, pagination, sidebar components`.

### Task B7 [Master]: Data Display — card

**Skills:** rails-blocks-cli, style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Slug:** `card`

**In scope:** One flat `CardComponent`. Preview, kitchen-sink Data Display
section, catalog, mermaid.

**NOT in scope:** Any other data-display component.

**Build order:** Follow the **Standard Batch Workflow**. Commit
`feature: add card component`.

### Task B8 [Master]: Shell-port extras audit + on-demand policy

**Skills:** rails-blocks-cli (after approval), style-ui, update-catalog, update-component-previews, write-tests, review-changes
**Reference:** `app/views/layouts/` partials (`_head`, `_flash`, `_navbar`, `_footer` — confirm exact paths), Devise views under `app/views/devise/`, account views.

**In scope:**
- **Audit** the existing shell/skeleton (`_head/_flash/_navbar/_footer`) + Devise/
  account views; produce the list of additional RB components needed to eventually
  port them (e.g. avatar). **STOP and present the list for Jordan's approval**
  (open question #2) before installing anything.
- After approval, install the approved extras under the Standard Batch Workflow.
- Document the **standing on-demand install policy** in
  `docs/COMPONENT_CATALOG.md` (install one via `rails-blocks-cli` skill under the
  same hygiene rules, then `/update-catalog`; do NOT bulk-install the RB catalog).

**NOT in scope:** The shell/auth/billing rebuild (Ticket 4). A dedicated footer
component (no RB slug — composed in Ticket 4). Bulk-installing the rest of RB.
JSP feature components (notifications feed, account switcher, billing/pricing,
mentions, unfurl).

**Build order:**
1. Audit + write the extras list; **present for approval (gate).**
2. On approval, install per Standard Batch Workflow.
3. Document the on-demand policy in the catalog.
4. **Verify:** full `bin/rails test` (show output); browser-verify `/lookbook` +
   `/dev/kitchen_sink` have zero external network requests.
5. **Review:** `/review-changes`, then commit
   `feature: add shell-port extras and document on-demand policy`.

## Task Dependencies

- **B0 → everything.** B0 sets the button shape, the settled Stimulus registration
  approach, and the `ui-*` collision convention every later batch relies on.
- **B1–B8 run strictly sequentially, all on Master.** They are not parallelizable:
  every batch edits the same shared-infra files — `app/javascript/controllers/
  index.js`, `config/importmap.rb`, `app/views/dev/kitchen_sink/show.html.erb`,
  `docs/COMPONENT_CATALOG.md`, `docs/architecture/component-map.mermaid` — so
  parallel clones would collide, and the design mandates one PR with one commit
  per batch. This is why no task is assigned to a Clone.
- **B4/B5/B6 carry the question-#1 checks** (`ToastComponent`/`ModalComponent`/
  `TabsComponent` existence → plain vs `Ui`-prefixed + fallback approval).
- **B8 has an approval gate** after the audit (question #2) before any install.

## Open Risks (surface, don't silently decide)

1. **Broader collision surface than the design's table:** `alert`, `dropdown`,
   `modal`, `tabs` also collide via tailwindcss-stimulus-components. The `ui-*`
   rule covers them; confirm each at dry-run.
2. **Fallback-approval cases** (any real JSP `ToastComponent`/`ModalComponent`/
   `TabsComponent`) require Jordan's manual approval before installing RB under a
   `Ui`-prefixed class.
