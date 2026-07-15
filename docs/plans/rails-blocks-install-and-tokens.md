> Ticket: COV-11
> Branch: feature/cov-11-rails-blocks-install

# Plan: Install Rails Blocks Pro + default design tokens

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Default token layer (`_tokens.css`) | Master | ✅ |
| 2 | Foundational Rails Blocks base CSS + `application.css` wiring | Master | ✅ |
| 3 | Install `buttons` ViewComponent, wire to tokens, component test | Master | ✅ |
| 4 | Lookbook preview + kitchen-sink smoke-test entry | Master | ✅ |
| 5 | `# AIDEV-NOTE` markers on Jumpstart CSS files that clash with new tokens | Clone | ✅ |
| 6 | Catalog/preview sync, full test suite, final commit | Master | ✅ |

## Prerequisites

- Design: `docs/designs/rails-blocks-install-and-tokens.md`
- Prototype: None (infrastructure only; default neutral/monochrome RB look, placeholder)
- Feature branch: `feature/cov-11-rails-blocks-install` — already checked out
- Verified during planning: `rails-blocks doctor` runs clean (registry + API + token all
  present); `rails-blocks whoami` → `"pro": true`. Re-verify at the start of Task 1 in case
  auth state changed; if `pro` is not `true`, STOP and tell Jordan — do not reinstall/re-login.

## Resolved Decisions (approved)

These were pinned down during planning to remove ambiguity for execution:

1. **`buttons` is the free component to install**, not `button` — confirmed via
   `rails-blocks list` (`buttons - Buttons`, no `(pro)` tag) and
   `rails-blocks search button`. `--as view_component --dry-run` writes exactly
   `app/components/buttons/component.rb` and `app/components/buttons/component.html.erb`.
   No Stimulus controller is required (`required_stimulus_controllers: []` in the registry) —
   nothing to register.
2. **Default (untouched) colors to replace**, per `rails-blocks docs buttons` → Color Scheme
   Reference, Primary/Basic variant: light `bg-neutral-800 text-white`, dark
   `bg-white text-neutral-800`. These get replaced with `bg-primary text-primary-foreground`
   (a single class pair works for both modes since `--primary`/`--primary-foreground` flip
   under `.dark`).
3. **Foundational base CSS scope** (source: https://railsblocks.com/docs/installation, the
   Rails Blocks Pro CSS base installation guide). Include only:
   - `kbd` element styling
   - `.label` / `label` text formatting
   - `.form-input[disabled]`, `.form-control` base styling
   - custom search-input clear-button SVG styling
   - `select:not([multiple])`, `select[multiple]`, `[type="checkbox"]`, `[type="radio"]`
     appearance customization
   - `.small-scrollbar`, `.scrollbar-hide`, `.scroll-fade-x`, `.scroll-fade-y`,
     `.scroll-fade-both` utilities
   - `.toast-item` positioning + its animation custom props
   - the `.dark`-prefixed variants of all of the above

   Explicitly EXCLUDE (these ride in with their components in Ticket 3): all CDN `<head>`
   `<script>`/`<link>` tags (Shoelace, Tom Select, Air Datepicker, PhotoSwipe), and the custom
   CSS blocks scoped to those libraries (`.ts-control`/`.ts-dropdown`/`.ts-wrapper` for Tom
   Select, `--adp-*` for Air Datepicker, Shoelace color-picker theming, PhotoSwipe CSS).
4. **`base.css` import layer**: `@import "./rails_blocks/base.css" layer(components);`,
   placed as the last entry in the existing `@import "./components/...")` block (i.e. right
   after `braintree.css`, before the unlayered `lexxy.css` import) — matches how Jumpstart's
   own form/toast/scroll-area-adjacent component CSS is already layered, and keeps it visually
   grouped with the rest of the component imports.
5. **Radius wiring**: `--radius` alone doesn't affect Jumpstart's `--radius-lg`-based rounding
   (`buttons.css`'s `.btn` uses `border-radius: var(--radius-lg)`, a separate Tailwind scale
   var we are not touching). The smoke-test button demonstrates the token directly via
   `rounded-[var(--radius)]` on the installed RB component, not by remapping the Tailwind
   radius scale. Record this as an `# AIDEV-NOTE` at the edit site — full radius-scale mapping
   is out of scope here.
6. **`controllers/index.js`**: already satisfies the RB guide (`eagerLoadControllersFrom` +
   explicit `tailwindcss-stimulus-components` registrations) and needs no change — confirmed,
   not a task.
7. **AIDEV-NOTE marker files** (Task 5): `grep -rl -- "--bg-primary\|--text-on-primary\|--border-primary\|--text-primary\b" app/assets/tailwind/components/` returns exactly:
   `alert.css`, `buttons.css`, `docs.css`, `forms.css`, `lexxy.css`, `nav.css`,
   `notifications.css`, `pagination.css`, `pills.css`, `tabs.css`, `top_nav.css`,
   `typography.css`, `wells.css` (13 files). These use Jumpstart's own `--bg-primary`/
   `--text-on-primary` family, which Tickets 4–6 will migrate onto the new tokens.

## Tasks

### Task 1 [Master]: Default token layer (`_tokens.css`)

**Skills:** style-ui
**Reference:** Read `app/assets/tailwind/theme/_tokens.css` (current placeholder:
`/* Ticket 2 will define the shared design tokens in this layer. */ @theme { }`) and
`app/assets/tailwind/application.css` (note `_tokens.css` is imported unlayered, after the
layered `themes/dark.css`/`themes/light.css` — this is what makes the override work; do not
change that import).

**In scope:**

- Replace the placeholder contents of `app/assets/tailwind/theme/_tokens.css` with three
  blocks, using the exact values from the design doc: a `:root { }` block (raw light values:
  `--background`, `--foreground`, `--primary`, `--primary-foreground`, `--muted`,
  `--muted-foreground`, `--border`, `--ring`, `--radius`), a `.dark { }` block (raw dark
  overrides, using the `.dark` class selector — not `[data-theme]`), and an
  `@theme inline { }` block mapping raw → Tailwind tokens (`--color-background`,
  `--color-foreground`, `--color-primary`, `--color-primary-foreground`, `--color-muted`,
  `--color-muted-foreground`, `--color-border`, `--color-ring`, `--radius`).
- Add a one-line `# AIDEV-NOTE` above the `@theme inline` block: rebranding = edit
  `--primary` / `--primary-foreground` here only.

**NOT in scope:**

- `application.css` edits (Task 2). `rails_blocks/base.css` (Task 2). Any component (Tasks
  3–4). Migrating Jumpstart's own component CSS (Task 5 only marks, doesn't migrate).

**Build order:**

1. **Implement:** re-verify `rails-blocks doctor` / `rails-blocks whoami` (`pro: true`); if
   not, stop and report. Then write `_tokens.css`.
2. **Verify:** `bin/rails tailwindcss:build` completes successfully.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 2 [Master]: Foundational Rails Blocks base CSS + `application.css` wiring

**Skills:** style-ui
**Reference:** Read `app/assets/tailwind/application.css` in full (top `@theme` block, import
order). Source content from https://railsblocks.com/docs/installation — see "Resolved
Decisions" #3–#4 above for exactly what to include/exclude and how to wire the import.

**In scope:**

- Create `app/assets/tailwind/rails_blocks/base.css` containing only the foundational CSS
  listed in Resolved Decisions #3 (resets, form/input theming, scrollbar + scroll-fade
  utilities, toast-item positioning/animation vars, and their `.dark` variants). No CDN
  links. No third-party widget CSS (Tom Select / Air Datepicker / Shoelace / PhotoSwipe).
- Edit `app/assets/tailwind/application.css`:
  1. Remove the `--color-primary: var(--bg-primary);` line from the top `@theme { }` block
     (now owned by `_tokens.css`'s `@theme inline`).
  2. Add `@import "./rails_blocks/base.css" layer(components);` as the last import in the
     `@import "./components/...")` block, immediately after `braintree.css` and before the
     unlayered `lexxy.css` import.
- Add a one-line `# AIDEV-NOTE` in `base.css` (top of file) recording the hygiene rule: self-host
  only, foundational base CSS, no CDN links, no widget CSS — those come in per-component in
  Ticket 3.

**NOT in scope:**

- Any third-party widget CSS or CDN `<head>` links. Any per-component Stimulus registration.
  The button component itself (Task 3).

**Build order:**

1. **Implement:** create `rails_blocks/base.css`; edit `application.css` (both edits).
2. **Verify:** `bin/rails tailwindcss:build` completes successfully. `grep -rn "cdn.jsdelivr\|jsdelivr.net" app/assets app/views/layouts` returns nothing new (no CDN links were added).
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 3 [Master]: Install `buttons` ViewComponent, wire to tokens, component test

**Skills:** rails-blocks-cli, style-ui, write-tests
**Reference:** `rails-blocks docs buttons` for the Color Scheme Reference and Options
Reference. See Resolved Decisions #1–#2, #5 above.

**In scope:**

- `rails-blocks install buttons --as view_component --dry-run` — confirm it would write only
  `app/components/buttons/component.rb` and `app/components/buttons/component.html.erb`. Show
  this to Jordan and get approval before writing.
- `rails-blocks install buttons --as view_component` (real install, no `--force`).
- Edit the installed component's primary/default variant: replace the hardcoded
  `bg-neutral-800 text-white` (light) / `bg-white text-neutral-800` (dark) class pair with
  `bg-primary text-primary-foreground`, and replace its border-radius class with
  `rounded-[var(--radius)]`. Add an `# AIDEV-NOTE` at this edit site per Resolved Decision #5
  (why only this token is wired, not the full `--radius-lg` scale).
- Write `test/components/buttons/component_test.rb` (`class Buttons::ComponentTest <
  ViewComponent::TestCase`), test-first: `render_inline(Buttons::Component.new(text: "Click
  me"))` then assert the rendered button carries `bg-primary`, `text-primary-foreground`, and
  `rounded-[var(--radius)]` classes.

**NOT in scope:**

- Lookbook preview, kitchen-sink entry (Task 4). Non-primary variants (secondary/outline/
  ghost/destructive) — leave their hardcoded classes as-is; only the primary/accent variant is
  the smoke test.

**Build order:**

1. **Test:** write `test/components/buttons/component_test.rb` first — it will fail (component
   doesn't exist yet / doesn't use token classes yet).
2. **Implement:** dry-run → approval → real install → edit classes per above.
3. **Verify:** `bin/rails test test/components/buttons/component_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 4 [Master]: Lookbook preview + kitchen-sink smoke-test entry

**Skills:** style-ui
**Reference:** `app/views/dev/kitchen_sink/show.html.erb` (Buttons `<section>` currently holds
`<%# TODO: replace with button component examples %>`). `config/application.rb:27` sets
`config.view_component.previews.paths = ["test/components/previews"]`.

**In scope:**

- Create `test/components/previews/buttons/component_preview.rb`
  (`class Buttons::ComponentPreview < ViewComponent::Preview`) with a `default` scenario
  rendering `Buttons::Component.new(text: "Primary Button")`.
- Replace the TODO comment in the Buttons `<section>` of
  `app/views/dev/kitchen_sink/show.html.erb` with the rendered button, plus a second instance
  wrapped in a `<div class="dark">` so both modes are visible on the page without a JS toggle.
- Manually verify (`bin/dev`): visit `/lookbook` and confirm the button preview renders in our
  palette; visit `/dev/kitchen_sink` and confirm both the light and `.dark`-wrapped buttons
  show `bg-primary`/`text-primary-foreground` and the token radius, correctly in each mode.

**NOT in scope:**

- Catalog/component-map updates (Task 6 runs those commands). Any other kitchen-sink section.

**Build order:**

1. **Implement:** create the preview file; edit the kitchen-sink view.
2. **Verify:** `bin/rails test test/integration/dev/kitchen_sink_test.rb`; manual browser check
   per above.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 5 [Clone]: `# AIDEV-NOTE` markers on Jumpstart CSS files that clash with new tokens

**In scope:**

- In each of the 13 files listed in Resolved Decisions #7
  (`alert.css`, `buttons.css`, `docs.css`, `forms.css`, `lexxy.css`, `nav.css`,
  `notifications.css`, `pagination.css`, `pills.css`, `tabs.css`, `top_nav.css`,
  `typography.css`, `wells.css`, all under `app/assets/tailwind/components/`), add one
  `# AIDEV-NOTE` comment near the top of the file: this file reads Jumpstart's own
  `--bg-primary`/`--text-on-primary` token family, which COV-4–6 will migrate onto the new
  `_tokens.css` palette — do not remove or change the CSS itself, comment only.
- Use the CSS comment syntax `/* AIDEV-NOTE: ... */` (these are `.css` files, not Ruby).

**NOT in scope:**

- Changing any actual CSS rule or value in these files. Any file outside this exact list.

**Build order:**

1. **Implement:** add one `/* AIDEV-NOTE: ... */` line to each of the 13 files.
2. **Verify:** `grep -rl "AIDEV-NOTE" app/assets/tailwind/components/` lists exactly the 13
   files from Resolved Decisions #7. `bin/rails tailwindcss:build` still succeeds.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.

### Task 6 [Master]: Catalog/preview sync, full test suite, final commit

**Reference:** `docs/COMPONENT_CATALOG.md` is currently empty (first-run case for
`/update-catalog`). `docs/architecture/component-map.mermaid` has empty category groups
(Buttons/Forms/Feedback/Overlays/Navigation/Data Display).

**In scope:**

- Run `/update-catalog` — generates the Buttons catalog entry and adds it to the `buttons`
  group in the component map. This command commits its own changes
  (`docs: update component catalog and map`).
- Run `/update-component-previews` — confirms the Lookbook preview and kitchen-sink section
  from Task 4 are in sync with the catalog (should report already in sync, or make minor
  adjustments). This command commits its own changes (`chore: update component previews`) if
  it makes any.
- Run `bin/rails test` (full suite) — must pass. Show the output.
- `git diff --stat` review of everything NOT already committed by the two commands above
  (`_tokens.css`, `rails_blocks/base.css`, `application.css`, the button component + test, the
  13 AIDEV-NOTE files).
- Final commit for the remaining changes: `feature: install Rails Blocks Pro and default
  design tokens`.

**NOT in scope:**

- Any new component or CSS migration beyond what Tasks 1–5 produced.

**Build order:**

1. **Implement:** run `/update-catalog`, then `/update-component-previews`.
2. **Verify:** `bin/rails test` (full suite, show output). `git diff --stat`.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. Not optional.
4. **Final commit:** stage the remaining files and commit as above.

## Task Dependencies

- **Task 1** first — Tasks 2 and 3 both build on the real token values.
- **Task 2** depends on Task 1. **Task 3** depends on Task 1. Tasks 2 and 3 touch disjoint
  files (`application.css`/`rails_blocks/base.css` vs. `app/components/buttons/`) and can run
  in parallel with each other once Task 1 is done.
- **Task 4** depends on Task 3 (needs the installed, token-wired button).
- **Task 5** has no file overlap with any other task and no dependency — can run any time,
  including in parallel with Task 1.
- **Task 6** depends on Tasks 2, 3, 4, and 5 (needs everything present before syncing docs and
  making the final commit). Runs last; Master does the final commit here.
