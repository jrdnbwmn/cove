> Ticket: COV-17
> Branch: jrdnbwmn/cov-17-review-components
> Plan created: docs/plans/component-system-audit-and-cleanup.md

# Feature: Component System Audit + Final Cleanup

## Problem

The Components project (COV-10 → COV-15) built a ViewComponent-based design
system and rebuilt the app shell, auth, and billing views onto it. COV-17 is
the wrap-up: confirm the system is complete and functioning, then do a final
hygiene pass — adopt components on the last stock views, turn off dark mode
(unwanted for this app), and retire legacy CSS left behind by the rebuilds.

## Approach

Half audit, half small cleanup. This doc records the audit verdict as the
project's source of truth, then scopes four light, no-migration cleanup
workstreams into a single branch/PR. No new features. No behavior change to
auth or billing.

## Audit verdict — design system is complete and functioning

Verified against the ticket's checklist on 2026-07-18:

| Part | Status |
| --- | --- |
| CSS tokens | `_tokens.css` — oklch, light + dark, `@theme inline`, single-place rebrand via `--primary` |
| Tailwind v4 | CSS-first, no `tailwind.config.js`, builds clean |
| ViewComponents | 24 components (+ slot sub-components) |
| Lookbook previews | 24 (1:1 with components), mounted at `/lookbook` (`Rails.env.local?`) |
| Component tests | 24; full suite **310 runs, 0 failures** |
| Kitchen sink | `/dev/kitchen_sink` (`Rails.env.local?`) |
| Catalog | `docs/COMPONENT_CATALOG.md` (quick-ref + per-component detail) |
| Arch diagram | `docs/architecture/component-map.mermaid` |

All six prior design docs closed with no unresolved open questions. Clean
landing. The cleanup below is polish, not remediation of anything broken.

## Prototype

None. No visual design changes — this is a wiring/cleanup pass over existing
views. The homepage keeps its current layout; only the button implementation
changes.

## Data Model

No model or schema changes. Notably **no migration**: dark-mode disable does
not drop a column (there is no `theme` column in `db/schema.rb`; the engine
`User::Theme` concern simply goes inert once views stop calling it).

## Screens / Flows

Behavioral outcomes only (no new screens):

- **Homepage (`public#index`):** same layout; the two CTA links render via
  `ButtonComponent` instead of legacy `btn` classes.
- **Whole app:** renders light-only. No dark styles ever apply; no theme
  toggle path. Users who previously had a dark preference see light.

## Scope

**In (four workstreams, one branch/PR):**

1. **Audit doc** — this file; the recorded project verdict + decisions.

2. **Homepage `ButtonComponent` swap** — override the stock Jumpstart
   `public/index.html.erb` into the app; replace `btn btn-primary` /
   `btn-secondary` links with `ButtonComponent`. Leave `public/about` and
   `dashboard/show` as typed content stubs (nothing real to componentize).

3. **Disable dark mode (Level 1)** — cut the wiring that applies `.dark`, so
   the app is permanently light-only:
   - `layouts/application.html.erb` — remove `dark:` from the `<html>`
     `class_names`; remove `theme` controller + `data-theme-preference-value`
     from `<body>`.
   - `application/_head.html.erb` — remove the pre-paint `<script>` (the
     `current_user&.system_theme?` block).
   - Delete `theme_controller.js` and unregister it.
   - `theme/_tokens.css` — remove the `.dark { … }` override block.
   - Delete `themes/dark.css` and its `@import`.
   - Strip `.dark` blocks from the 6 JSP CSS files that carry them
     (forms, notifications, braintree, lexxy, `rails_blocks/base.css`,
     + `application.css` reference).
   - Stop calling `theme` / `dark_theme?` / `system_theme?` in views.

4. **Retire legacy CSS + token hygiene** —
   - Delete orphaned `components/nav.css` and `components/top_nav.css` (and
     their `@import`s in `application.css`) — verified 0 usages of their
     classes; re-grep per class at execution before deleting.
   - Audit the 12 view files still using hardcoded `gray/neutral` classes;
     route genuine UI through tokens (`text-muted`, `bg-muted`, `border`,
     etc.).

**Deferred / out:**

- **Purging the 468 inert `dark:` classes** baked into the 24 component
  files (Level 2). Zero behavior gain over Level 1, high churn/risk across
  every component. Left in place; re-enabling dark mode later stays trivial.
- **Self-hosting the Inter font** (removing the `rsms.me` CDN `<link>` in
  `_head`). Jordan is changing the font later — leave the CDN link for now.
- **Rebuilding `public/about` and `dashboard/show`** as real designed pages —
  they are placeholder stubs to be designed with real content later.

## Guardrails

- **Nav CSS deletion is verify-then-delete.** If a per-class grep at
  execution finds any class still referenced, that class stays and we note
  it — do not chase it into a larger refactor.
- **Color audit excludes intentional demo colors.** The kitchen-sink page
  shows the raw palette on purpose; its hardcoded colors stay.
- **Scope guard.** Four workstreams in one ticket is acceptable because all
  are cleanup with no migrations. If the color audit starts sprawling at
  execution time, stop and split it into a follow-up rather than expand this
  ticket.

## Open Questions

None.

## More Info

- Dark-mode footprint measured: **687 `dark:` occurrences** total — 468 in
  48 component files, 54 in 14 view files, the rest in JS controllers/CSS.
  Level 1 touches only the ~8–12 wiring files above; the component classes
  are left inert.
- The homepage currently served at `public#index` is the Jumpstart engine
  stock view (`lib/jumpstart/app/views/public/index.html.erb`), not yet
  overridden into the app — hence the "override into the app first" step.
- Verification standard (non-negotiable): run `bin/rails test` and show
  output before claiming done; `git diff` to confirm changes. Jordan does
  the final visual QA pass in the browser (kitchen sink, Lookbook, auth,
  account, billing) before merge.
