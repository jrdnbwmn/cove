> Ticket: COV-12
> Branch: feature/cov-12-starter-components
> Plan created: docs/plans/curated-rails-blocks-starter-set.md

# Feature: Curated Rails Blocks starter set (self-hosted, lazy JS)

## Problem
The walking skeleton has no shared UI vocabulary — `app/components/` holds only a
button. To build the shell, auth, and billing surfaces on a consistent design
system, we need a curated set of base ViewComponents installed from Rails Blocks
Pro, self-hosted (no CDN), with lazy Stimulus that never clobbers Jumpstart's
existing controllers. This ticket also establishes on-demand install as the
standing pattern for every component we add later.

## Approach
Install a curated set of 20 Rails Blocks Pro components as ViewComponents via the
`rails-blocks-cli` skill (never the MCP), in batches, under strict hygiene rules:
self-host every JS/CSS dependency, register Stimulus lazily, route primary accents
through design tokens, and namespace any controller that collides with a Jumpstart
one (`ui-*`) rather than overwriting it. After the curated set, audit the existing
shell/skeleton and install the additional RB components needed to eventually port
it onto Rails Blocks (vocabulary only — the shell rebuild itself is Ticket 4).

**Rails Blocks is the default.** Every curated component maps 1:1 to an RB Pro
slug, so no Jumpstart-component fallbacks are anticipated. Jumpstart is used only
when RB genuinely has no equivalent, and every such fallback requires manual
approval.

### Naming convention (decided)
Flat class/file naming, matching the `/update-component-previews`,
`/update-catalog`, and `/create-component` skills and the ticket text:

- Component: `AlertComponent` → `app/components/alert_component.rb` + `.html.erb`
- Preview: `test/components/previews/alert_component_preview.rb` → `AlertComponentPreview`
- The **6 categories are grouping only** — they appear as subgraphs in
  `component-map.mermaid` and `<section>`s in the kitchen sink, **not** as Ruby
  namespaces (no `Feedback::Alert`).

Because Ticket 2 shipped the button as `Buttons::Component` (namespaced folder),
**B0 normalizes it** to `ButtonComponent` at `app/components/button_component.rb`,
updating its preview, catalog entry, kitchen-sink render, and mermaid node. Approved
deviation from "don't refactor unrelated code" — required for consistency.

### Collision resolution (RB-first, coexist, never overwrite)
Default: install RB's component **and** its Stimulus controller namespaced `ui-*`
so it coexists with — never overwrites — Jumpstart's. Jumpstart controllers stay
registered for existing JSP features.

| Case | Jumpstart has | Resolution |
| --- | --- | --- |
| tooltip | `tooltip_controller.js` | RB → `data-controller="ui-tooltip"` / `ui_tooltip_controller.js`. JSP's stays. |
| toast | `notifications_controller.js` | RB → `ui-toast` / `ui_toast_controller.js`. JSP's stays. |
| modal / tabs / toast (class names) | README claims JSP built-ins `ModalComponent`, `TabsComponent`, `ToastComponent` | Verify at B4/B5 whether they actually exist in `app/components/`. If real → install RB under `Ui`-prefixed class (`UiModalComponent`) and bring as a fallback-approval case. If only README lore → RB takes the plain flat name. |

Never `--force` over a Jumpstart controller without approval.

### Self-hosting (zero CDN)
Vendor every JS dep into `vendor/javascript/` and pin via importmap
(`bin/importmap pin --download` or manual `vendor/` + `config/importmap.rb`). Any
CSS that ships as a CDN `<link>` (e.g. tom-select's stylesheet) is vendored into
the asset pipeline, never added as a `<head>` CDN link. Known deps (confirmed
per-component at dry-run): **tom-select** (select), **floating-ui** (dropdown,
tooltip, modal positioning), **motion** (toast).

### Lazy Stimulus
Register each new controller explicitly, only because its component ships in this
ticket. Enumerate existing Jumpstart registrations in `index.js` first and preserve
every one — no controller registered speculatively.

## Acceptance Criteria
- Every curated component (+ shell-port extras) exists as a flat ViewComponent,
  themed via tokens, correct in light + dark.
- ZERO CDN `<head>` links; all assets self-hosted — **no external network requests
  on `/lookbook`** (browser-verified).
- Stimulus is lazy; no Jumpstart controller overwritten; every collision
  (`ui-tooltip`, `ui-toast`) has a recorded resolution and both behaviors work.
- Primary accents use `bg-primary` / `text-primary-foreground`; true neutrals stay
  on the neutral scale.
- Every component appears in the catalog, mermaid map, `/lookbook`, and
  `/dev/kitchen_sink`; interactive ones work in the browser.
- On-demand policy documented in `COMPONENT_CATALOG.md`; `bin/rails test` passes
  (output shown).
- One PR on `feature/cov-12-starter-components`; one commit per batch.

## Prototype
None. Visual design comes from Rails Blocks defaults + the app's existing design
tokens; no separate prototype file.

## Data Model
No database models. The "data model" here is the component taxonomy — 6 categories,
used only as grouping in `component-map.mermaid` and the kitchen sink:

| Category | Components |
| --- | --- |
| Buttons | button *(normalize existing → `ButtonComponent`)* |
| Forms | input, textarea, label, error/help field *(the `forms` bundle)*, checkbox, radio, switch, select, password |
| Feedback | alert, badge, loading indicator, skeleton, toast, tooltip |
| Overlays | modal, dropdown |
| Navigation | navbar, breadcrumb, tabs, pagination, sidebar |
| Data Display | card |

**Fuzzy names resolved at install** (show mapping before installing): `forms` →
a **single field-group wrapper** `Forms::Component` (normalized to
`FormFieldComponent`) + the shared `.form-control` CSS class on raw inputs — RB
has NO separate input/textarea/label/error-help components (confirmed at dry-run
2026-07-16; `.form-control` CSS already installed at
`app/assets/tailwind/rails_blocks/base.css`); `loading indicator` →
`loading_indicator` (spinner). Confirmed via `rails-blocks list/search/docs`.

**RB Pro slug coverage:** all 20 map 1:1 (`alert, badge, breadcrumb, card,
checkbox, dropdown, forms, loading_indicator, modal, navbar, password, pagination,
radio, select, sidebar, skeleton, switch, tabs, toast, tooltip`). No Jumpstart
fallbacks anticipated.

## Screens / Flows
No user-facing flows. Verification surfaces:

- `/lookbook` — every component's preview (default + variants + edge/error state).
- `/dev/kitchen_sink` — every component rendered under its category section, light
  + dark, no CDN requests.

Per-batch workflow (each ends in one commit `feature: add <components> components`):
dry-run each component → show files/controllers/JS deps/CDN links → install for
real → vendor/pin deps → register controllers lazily + apply collision rules →
token-accent pass (verify light + dark) → normalize to flat shape (one
`# AIDEV-NOTE:` per convention divergence) → Lookbook preview + kitchen-sink entry
→ `/update-catalog` + `/update-component-previews` → `bin/rails test` (show output)
→ boot + check no importmap/console/CDN errors → commit.

## Scope
**In:**
- **B0** — Normalize button → `ButtonComponent`.
- **B1** — Forms A: the `forms` field bundle (input, textarea, label, error/help).
- **B2** — Forms B: checkbox, radio, switch, select *(vendor tom-select)*, password.
- **B3** — Feedback static: alert, badge, loading indicator, skeleton.
- **B4** — Feedback interactive: toast *(`ui-toast`, motion)*, tooltip
  *(`ui-tooltip`, floating-ui)* — the two collision cases, isolated.
- **B5** — Overlays: modal, dropdown *(floating-ui)*.
- **B6** — Navigation: navbar, breadcrumb, tabs, pagination, sidebar.
- **B7** — Data Display: card.
- **B8** — Shell-port extras: audit `_head/_flash/_navbar/_footer` + Devise/account
  views; present the required RB list for approval; install (e.g. avatar) under the
  same rules.
- On-demand install policy documented in `COMPONENT_CATALOG.md`.

**Deferred:**
- The actual shell/auth/billing rebuild onto these components (Ticket 4).
- Any RB component outside the curated set + shell-port extras — install on demand
  when a feature needs it; do NOT bulk-install the rest of the RB catalog.
- JSP feature components (notifications feed, account switcher, billing/pricing UI,
  mentions, unfurl previews) — stay Jumpstart; not generic primitives.
- A dedicated footer component — no RB slug; composed from primitives in Ticket 4.
- Mapping Jumpstart's full `--radius` scale (pre-existing out-of-scope note on the
  button).

## Open Questions
None. Two items to confirm during implementation (not blockers):
1. B4/B5 — whether `ModalComponent`/`TabsComponent`/`ToastComponent` JSP built-ins
   actually exist in `app/components/` (drives plain vs `Ui`-prefixed name).
2. B8 — final shell-port extras list, surfaced for approval after the audit.

## More Info
**Standing on-demand policy** (to document in `COMPONENT_CATALOG.md`): when a
feature or the shell/auth/billing rebuild needs a component not in the catalog,
install just that one via the `rails-blocks-cli` skill
(`rails-blocks install <name> --as view_component --path app/components
--stimulus-path app/javascript/controllers`) under the same hygiene rules, then run
`/update-catalog`. Do NOT bulk-install the rest of the Rails Blocks catalog. Matches
the `style-ui` "base component missing → add it" rule.

**Tooling:** rails-blocks CLI v0.1.4, authenticated Pro (`rails-blocks whoami` →
`pro: true`). Use the `rails-blocks-cli` skill for ALL Rails Blocks operations
(dry-run first, never `--force`, ViewComponent since the app uses it). Do NOT use
the Rails Blocks MCP — it is misconfigured for this repo.

**Environment:** Tailwind v4 CSS-first via `@theme` (never create
`tailwind.config.js`); tokens in `app/assets/tailwind/theme/_tokens.css`; JS via
importmap (no Node); Stimulus registered in `app/javascript/controllers/index.js`.
Existing Jumpstart controllers to preserve: accounts, autogrow, bulk, clipboard,
notifications, pricing, theme, tooltip, unfurl_link (+ braintree/bridge/paddle/
stripe).
