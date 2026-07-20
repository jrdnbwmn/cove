> Ticket: COV-27
> Branch: jrdnbwmn/cov-27-icon-set
> Plan created: docs/plans/icon-set.md

# Feature: Icon set for the design system (rails_icons + Lucide)

## Problem
Icons are hand-pasted as raw `<svg>` markup scattered across ~33 component and
view files, with no consistent set or sizing convention. The design system needs
a single, consistent way to render an icon — `icon "inbox"` — so future work
(error-page rebuilds, empty states) draws from one library instead of one-off SVGs.

## Approach
Add the `rails_icons` gem and configure **Lucide** as the default library.
`rails_icons` renders **inline SVG** server-side via an `icon` view helper (no
JS, no icon font) — icons inherit `currentColor` and are sized with utility
classes, so they fit the app's existing neutral/token conventions and work with
Propshaft + Import Maps + Tailwind v4 unchanged.

Scope for this ticket is the **foundation + proof of the pattern**, plus one real
swap (`AlertComponent`) and an audit doc that backlogs the full app-wide
migration. The blanket replacement of all remaining hand-pasted SVGs is a
deliberate, visually-risky effort deferred to its own ticket(s).

Terminology: Lucide here is **inline SVG**, not a font family. There is nothing
to "switch to" at the CSS level — color/size behave like an icon font
(`icon "inbox", class: "size-5"`) but each icon is real SVG markup.

## Acceptance Criteria
- `rails_icons` installed and configured with **Lucide as the default library**
  (`config.default_library = "lucide"`); full Lucide set synced into
  `app/assets/svg/icons/lucide/`.
- An icon renders via the `icon` helper both in a **plain view** (dev kitchen
  sink) and **inside a ViewComponent** (its own template calls `icon`).
- `icon("inbox")` demonstrably passes into `EmptyStateComponent`'s icon slot
  (via a preview) — the component itself is untouched.
- `AlertComponent`'s hand-written variant SVGs are replaced with `icon` helper
  calls (accepted visual change to Lucide shapes).
- Usage documented in `docs/COMPONENT_CATALOG.md`.
- Icon inventory doc produced listing every remaining hand-pasted SVG location
  with a suggested Lucide mapping (backlog for the follow-up migration ticket).
- `bin/rails test` green; no visual changes to screens other than Alert.

## Prototype
None. No visual redesign in this ticket beyond the accepted `AlertComponent`
icon swap; layout and treatment stay as-is.

## Data Model
None. This is a presentation/dependency change only — no models, migrations, or
schema changes.

## Screens / Flows
No user-facing flow changes. Demonstration surfaces only:
- **Dev kitchen sink** (`app/views/dev/kitchen_sink/show.html.erb`) — an
  `icon "inbox"` example proving the helper in a plain view.
- **Lookbook preview** — a preview showing `icon` rendered from within a
  ViewComponent template, and `icon("inbox")` passed into
  `EmptyStateComponent`'s icon slot.
- **AlertComponent** — its five variant icons (success/error/warning/info/neutral)
  now render through `icon` instead of `tag.svg` builders. This is the one
  intended visual change; Lucide icons differ in shape from the current custom
  Nucleo-style icons.

## Scope
**In:**
1. Add `rails_icons` gem (approved) and run the install generator with Lucide
   (full sync into `app/assets/svg/icons/lucide/`). Set Lucide as
   `default_library` in `config/initializers/rails_icons.rb`.
2. Make the `icon` helper callable **inside ViewComponents** — include
   `RailsIcons::Helpers::IconHelper` into the component base (there is no
   `ApplicationComponent`; components inherit `ViewComponent::Base` directly, so
   include the module where needed / at the base). This avoids the known Lookbook
   gotcha where `helpers.*` is not reliably exposed in preview rendering.
3. Swap `AlertComponent`'s `success_icon`/`error_icon`/`warning_icon`/`info_icon`
   (and the `icon_svg` dispatch) to `icon` helper calls with Lucide names,
   keeping `@custom_icon` override behavior intact.
4. Prove the pattern: kitchen-sink helper call, a Lookbook preview, and the
   `EmptyStateComponent` slot demo.
5. Document usage in `docs/COMPONENT_CATALOG.md` (Icons section): calling the
   helper, sizing, `stroke_width`, and passing an icon into a component slot.
6. Produce the icon inventory doc (see Open Questions / follow-up) auditing all
   remaining hand-pasted SVG locations with suggested Lucide mappings.
7. Tests: a component/helper test proving an icon renders; keep suite green.

**Deferred (separate ticket):**
- App-wide replacement of the remaining hand-pasted SVGs — ~10 other design-system
  components and ~20 app views (billing, accounts, navbar, notifications, etc.),
  executed screen-by-screen with visual review. Backlogged by the inventory doc.
- Heroicons as a secondary library — not installed now; it is a one-command add
  (`rails generate rails_icons:install --libraries=heroicons`) documented for later.
- SVGs injected via JS controllers / CSS (`select_controller.js`,
  `forms.css`, etc.) — different mechanism, out of scope.

## Open Questions
None blocking. The full-swap follow-up ticket is best written *after* this
ticket's inventory doc exists, since that doc is its file-by-file backlog.

## More Info
Implementation notes for `/write-plan`:
- Install command: `rails generate rails_icons:install --library=lucide`
  (downloads the full Lucide set; use no `--skip-sync`).
- Run all Rails/bin commands through `mise exec --` in this workspace.
- `AlertComponent`'s current icons are custom Nucleo-style (18×18, stroke-width
  1.5); the Lucide swap is an accepted visual change, not a regression.
- Existing Lookbook previews live in `test/components/previews/`.
- Lucide sync lands ~1,600 SVG files under `app/assets/svg/icons/lucide/`; treat
  the folder as vendored (a `.gitattributes` `linguist-vendored` / diff-suppress
  note is a nice-to-have so it doesn't dominate diffs).
