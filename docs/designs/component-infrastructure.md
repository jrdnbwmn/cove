# Feature: Component Infrastructure Plumbing (ViewComponent + Lookbook)

_Linear: COV-10 — [1] Component infrastructure plumbing (ViewComponent + Lookbook)_
_This design doc is the source of truth and replaces the Linear ticket for planning/implementation._

## Problem

The app has no design-system infrastructure — `app/components/` is empty except a
README. Before we can build real UI components (later tickets), we need the plumbing:
a component library (ViewComponent), a preview/dev surface (Lookbook + a kitchen-sink
page), a design-token location, and catalog/diagram scaffolds. This ticket installs
**only the plumbing** — no real, permanent components ship.

## Approach

Install `view_component` + `lookbook`, wire up preview paths, create a dev-only
kitchen-sink canvas and a dev-only Lookbook mount, establish an (essentially empty)
Tailwind v4 design-token file that's part of the build, and scaffold the catalog +
component-map docs as empty-but-templated files. Prove the whole pipeline end-to-end
with a **temporary** `ExampleComponent`, then delete it so the library ships empty.

Guiding constraints (from global + ticket rules):
- TDD — write tests first; run `bin/rails test` and show output before claiming done.
- Boring, obvious code. Stimulus only. Never create `tailwind.config.js`.
- Self-host assets (no CDN `<head>` links). Route accents through tokens.
- `# AIDEV-NOTE:` for non-obvious decisions. Don't refactor unrelated code.
- **Do NOT** install Rails Blocks or any UI component in this ticket.

## Acceptance Criteria

- `/lookbook` and `/dev/kitchen_sink` boot in **development** and are **NOT reachable
  in production** (guarded at both route and controller level).
- `app/components/` still contains no real components (only `README.md`).
- Catalog + component-map exist as empty-but-templated scaffolds; token file is
  imported into the Tailwind build; `bin/rails test` passes.
- The temporary `ExampleComponent` used to verify the pipeline is fully removed.

## Prototype

None. This is infrastructure plumbing; the kitchen-sink page is the canvas later
tickets fill, not a designed screen.

## Data Model

None. No models, migrations, or associations. Controllers are view-only.

## Ground Truth (verified 2026-07-14)

- Branch `feature/component-infrastructure` already checked out.
- `app/components/` contains only `README.md`.
- Tailwind v4 CSS-first via tailwindcss-rails. Source `app/assets/tailwind/application.css`
  uses an `@import` chain (themes → components). **No `tailwind.config.js`.**
  `app/assets/tailwind/theme/` does **not** exist yet.
- JS via Importmap (no Node). Stimulus registered in `app/javascript/controllers/index.js`.
- Routes use `draw :jumpstart`; app routes live in `config/routes.rb` + `config/routes/`.
- **Authentication is opt-in**, not global: `ApplicationController` includes an
  `Authentication` concern that only wires Devise plumbing (no global
  `before_action :authenticate_user!`). Individual controllers add the filter
  themselves. → A plain `ApplicationController` subclass is **auth-free by default**.
- `view_component` and `lookbook` are not yet in the Gemfile.

## Key Decisions

1. **Kitchen sink is auth-free** — achieved by simply *not* adding
   `before_action :authenticate_user!`. No `skip_before_action` needed, since auth is
   opt-in in this app. Matches Lookbook's auth-free behavior.
2. **Dev-only via two independent guards** (belt-and-suspenders), applied to both
   `/lookbook` and `/dev/kitchen_sink`:
   - **Route guard:** wrap the route definition in `if Rails.env.development?` so the
     route is never defined in production.
   - **Controller guard:** `Dev::KitchenSinkController` has a `before_action` that
     raises `ActionController::RoutingError` (→ 404) unless `Rails.env.development?`.
3. **Preview path:** both ViewComponent and Lookbook point at `test/components/previews`.
4. **Token file is essentially empty** — a placeholder `@theme` block + explanatory
   comment. Ticket 2 fills it. It must be `@import`ed into `application.css` so it's
   part of the build (and the build must still succeed).

## Screens / Flows

**`GET /dev/kitchen_sink` (development only)**
- `Dev::KitchenSinkController#show` renders `app/views/dev/kitchen_sink/show.html.erb`.
- Titled page with labeled, currently-empty category sections, each with a placeholder
  comment marking where later tickets add examples:
  **Buttons, Forms, Feedback, Overlays, Navigation, Data Display.**
- In production: 404 (route not defined + controller guard).

**`GET /lookbook` (development only)**
- Lookbook engine mounted in `config/routes.rb`, guarded by `Rails.env.development?`.
- Reads previews from `test/components/previews`.
- In production: not mounted → 404.

## Files (planned)

**Add / modify:**
- `Gemfile` — add `view_component`; add `lookbook` in the `:development` group. `bundle install`.
- `config/routes.rb` — dev-only Lookbook mount at `/lookbook` and
  `GET /dev/kitchen_sink` route, both under `if Rails.env.development?`.
- ViewComponent + Lookbook preview-path config (initializer / `config/application.rb`
  as appropriate) → `test/components/previews`.
- `app/controllers/dev/kitchen_sink_controller.rb` — `#show`, dev-only `before_action` guard.
- `app/views/dev/kitchen_sink/show.html.erb` — titled page, 6 empty category sections
  with placeholder comments.
- `test/components/previews/.keep` — created empty.
- `app/assets/tailwind/theme/_tokens.css` — placeholder `@theme` block + comment.
- `app/assets/tailwind/application.css` — `@import "./theme/_tokens.css";` added to the chain.
- `docs/COMPONENT_CATALOG.md` — header, empty **Quick Reference** table
  (columns: Component | Purpose | Key args | Preview), empty **Component Details**
  section, and a clearly-marked **Component Details template** matching the format the
  `update-catalog` / `create-component` commands expect.
- `docs/architecture/component-map.mermaid` — category groups from the 6 sections above,
  no components yet.

**Tests (write first, TDD):**
- Integration test: `/dev/kitchen_sink` returns `200` and renders the page title in dev.
- Guard test: request returns `404` when `Rails.env` reports non-development
  (stub `Rails.env` for the guard check — no full prod-env boot).
- Equivalent coverage for `/lookbook` reachability where practical.
- After the pipeline smoke test, ensure no test references the deleted `ExampleComponent`.

**Out-of-repo edit (approved by user):**
- `~/.claude/skills/style-ui.md` — fix **all** stale references to
  `app/assets/stylesheets/theme/_tokens.css` → `app/assets/tailwind/theme/_tokens.css`
  (4 occurrences: lines ~30, 81, 92, 126). User approved editing this file and chose
  "fix all references."

**Temporary (create → verify renders in `/lookbook` and `/dev/kitchen_sink` → delete):**
- `ExampleComponent` (component class + template), its Lookbook preview, and its
  kitchen-sink entry. Deleted before the ticket is considered done so the library ships empty.

## Scope

**In:**
- ViewComponent + Lookbook gems and config.
- Dev-only, auth-free kitchen-sink page with 6 empty category sections.
- Dev-only Lookbook mount pointed at `test/components/previews`.
- Empty-but-imported design-token file; successful Tailwind build.
- Catalog + component-map doc scaffolds.
- style-ui skill path fix (out-of-repo, approved).
- Temporary `ExampleComponent` pipeline smoke test, then removed.
- Tests proving dev-reachable / prod-unreachable, passing `bin/rails test`.

**Deferred (later tickets):**
- Any real, permanent components (Buttons, Forms, etc.).
- Filling in `_tokens.css` (Ticket 2).
- Installing Rails Blocks / any UI component.
- Populating the catalog and component-map with real entries.

## Testing Strategy (production-unreachability, in brief)

Tests run in the test environment; you can't cleanly "become production" mid-run
because Rails loads routes/config once at boot. So instead of booting prod, we test
the **guard mechanism** directly: (1) assert the page renders `200` in
dev-like test env; (2) assert the guard returns `404` when `Rails.env` reports a
non-development value (stubbed). This directly asserts the acceptance criterion
without a fragile full prod-env boot.

## Commit

Final commit (after tests pass + `git diff --stat`):
`feature: add ViewComponent + Lookbook component infrastructure`.

## Open Questions

None.

## More Info

Standing hygiene rules carried from the ticket for later component work (not all
exercised here, but recorded for continuity): self-host assets (vendor / importmap-pin,
no CDN `<head>` links); lazy-load Stimulus (register a controller only when its
component is installed and used); route primary accents through tokens
(`bg-primary` / `text-primary-foreground`, not hardcoded `bg-neutral-900`); never
`--force` over a Jumpstart controller without approval. Rails Blocks operations (future
tickets) go through the `rails-blocks-cli` skill, dry-run first, never `--force`; do
**not** use the Rails Blocks MCP (non-functional for this repo).
