# Plan: Component Infrastructure Plumbing (ViewComponent + Lookbook)

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Install gems + ViewComponent/Lookbook preview-path config | Master | ✓ |
| 2 | Dev-only routes, `Dev::KitchenSinkController`, kitchen-sink view + tests | Master | ✓ |
| 3 | Empty design-token file, imported into Tailwind build | Clone | ✓ |
| 4 | Catalog + component-map doc scaffolds | Clone | ✓ |
| 5 | Fix stale `_tokens.css` paths in style-ui skill (out-of-repo) | Clone | ✓ |
| 6 | `ExampleComponent` end-to-end smoke test, then delete | Master | ✓ |

## Prerequisites

- Design: `docs/designs/component-infrastructure.md`
- Prototype: None (infrastructure only)
- Feature branch: `feature/component-infrastructure` — already checked out

## Guard Decision (approved)

The design specified `if Rails.env.development?` for both guards, but tests run in the
`test` environment — a route wrapped in `if Rails.env.development?` would not exist during
tests, so the "returns 200" integration test could never pass.

**Approved approach:** guard on `Rails.env.local?` (true in dev **and** test, false in
production) for both the route block and the controller `before_action`. This satisfies the
real acceptance criterion (unreachable in production) while letting the integration test hit
`200`. The guard test stubs `Rails.env.local?` → `false` to simulate prod and asserts `404`.

## Tasks

### Task 1 [Master]: Install gems + configure preview paths

**Skills:** none (dependency plumbing)

**In scope:**

- `Gemfile`: add `view_component` (default group); add `lookbook` inside the existing
  `group :development` (line ~61). Run `bundle install`.
- Configure ViewComponent + Lookbook preview path → `test/components/previews` (in
  `config/application.rb`, since ViewComponent config must load at boot).
- Create `test/components/previews/.keep`.

**NOT in scope:**

- Routes, controllers, views (Task 2). Any component (Task 6).

**Build order:**

1. **Implement:** edit `Gemfile`; `bundle install`; add preview-path config to
   `config/application.rb`; create `test/components/previews/.keep`.
2. **Verify:** `bin/rails runner "puts ViewComponent::Base.config.preview_paths"` shows the
   previews path; `bin/rails runner "puts Lookbook"` loads without error.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 2 [Master]: Dev-only routes, controller, kitchen-sink view + tests

**Skills:** write-tests
**Reference:** Read `app/controllers/application_controller.rb` (auth is opt-in — a plain
subclass is auth-free; add **no** `authenticate_user!`); `config/routes.rb` for routing style.

**In scope:**

- `config/routes.rb`: inside an `if Rails.env.local?` block — mount Lookbook at `/lookbook`
  and add `get "dev/kitchen_sink", to: "dev/kitchen_sink#show"`.
- `app/controllers/dev/kitchen_sink_controller.rb`: `#show`; `before_action` that does
  `head :not_found unless Rails.env.local?` (belt-and-suspenders guard). `# AIDEV-NOTE:`
  explaining the dev-only guard.
- `app/views/dev/kitchen_sink/show.html.erb`: titled page + 6 empty labeled sections
  (Buttons, Forms, Feedback, Overlays, Navigation, Data Display), each with a placeholder
  comment marking where later tickets add examples.
- Tests (write first).

**NOT in scope:**

- Any real/example component or content inside the sections (Task 6 temporarily; later
  tickets permanently). Tokens, docs.

**Build order:**

1. **Test:** `test/integration/dev/kitchen_sink_test.rb` — (a) `get "/dev/kitchen_sink"` →
   `200` and body includes the page title + all 6 section labels; (b) guard: stub
   `Rails.env.local?` → `false`, assert response is `404`. Add a `/lookbook` reachability
   assertion (`200`) where practical.
2. **Implement:** routes, controller, view.
3. **Verify:** `bin/rails test test/integration/dev/kitchen_sink_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 3 [Clone]: Empty design-token file in the Tailwind build

**Skills:** style-ui
**Reference:** Read `app/assets/tailwind/application.css` (existing `@import` chain). Note the
token file goes in `theme/` (singular) — distinct from the existing `themes/` (plural,
dark/light).

**In scope:**

- Create `app/assets/tailwind/theme/_tokens.css`: a placeholder `@theme { }` block + a comment
  explaining Ticket 2 fills it.
- Add `@import "./theme/_tokens.css";` to `application.css` (place with the theme imports,
  before components).

**NOT in scope:**

- Any real token values (Ticket 2). Touching `themes/` (plural).

**Build order:**

1. **Implement:** create `_tokens.css`; add the `@import` line.
2. **Verify:** `bin/rails tailwindcss:build` completes successfully.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 4 [Clone]: Catalog + component-map scaffolds

**In scope:**

- `docs/COMPONENT_CATALOG.md`: header; empty **Quick Reference** table (columns:
  Component | Purpose | Key args | Preview); empty **Component Details** section; a
  clearly-marked **Component Details template** matching the format `update-catalog` /
  `create-component` expect.
- `docs/architecture/component-map.mermaid`: the 6 category groups (Buttons, Forms, Feedback,
  Overlays, Navigation, Data Display), no components yet.

**NOT in scope:**

- Any real catalog/map entries.

**Build order:**

1. **Implement:** create both files.
2. **Verify:** Mermaid block parses (valid ```mermaid fence); table renders.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 5 [Clone]: Fix stale token paths in style-ui skill (out-of-repo, approved)

**In scope:**

- `~/.claude/skills/style-ui.md`: replace **all**
  `app/assets/stylesheets/theme/_tokens.css` → `app/assets/tailwind/theme/_tokens.css`
  (~4 occurrences, lines ~30, 81, 92, 126).

**NOT in scope:**

- Any other edits to the skill.

**Build order:**

1. **Implement:** `grep -n "stylesheets/theme/_tokens.css" ~/.claude/skills/style-ui.md` then
   replace each.
2. **Verify:** `grep -rn "stylesheets/theme/_tokens.css" ~/.claude/skills/style-ui.md` returns
   nothing.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.
   (Note: out-of-repo file won't appear in the repo diff — report the grep result instead.)

### Task 6 [Master]: `ExampleComponent` end-to-end smoke test, then delete

**Skills:** write-tests

**In scope:**

- Create temporary `ExampleComponent` (class + template), a Lookbook preview in
  `test/components/previews`, and a temporary kitchen-sink entry.
- Manually verify it renders at `/lookbook` and `/dev/kitchen_sink` (via `bin/dev`).
- **Delete** all three so `app/components/` holds only `README.md`.
- Confirm no test references `ExampleComponent` after deletion.

**NOT in scope:**

- Keeping any component. Any permanent component.

**Build order:**

1. **Implement:** create `ExampleComponent`, preview, kitchen-sink entry.
2. **Verify (manual):** boot `bin/dev`; confirm rendering at both URLs.
3. **Implement:** delete the component, preview, and kitchen-sink entry.
4. **Verify:** `grep -rn "ExampleComponent" app test` returns nothing; `bin/rails test`
   passes; `ls app/components/` shows only `README.md`.
5. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.
6. **Final commit** (Master, after full suite passes + `git diff --stat`):
   `feature: add ViewComponent + Lookbook component infrastructure`.

## Task Dependencies

- **Task 1** first — everything else assumes the gems/config exist.
- **Task 2** depends on Task 1 (needs Lookbook + preview path).
- **Tasks 3, 4, 5** are independent — can run in parallel with each other and alongside
  Tasks 1–2.
- **Task 6** depends on Tasks 1 + 2 (needs preview path, Lookbook mount, and kitchen-sink
  page). Runs last; Master does the final commit here.
