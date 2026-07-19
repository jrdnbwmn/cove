> Ticket: COV-18
> Branch: feature/cov-18-empty-state-component

# Plan: EmptyState design-system component

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Build `EmptyStateComponent` (`.rb` + `.html.erb`) + component test | Master | ✅ |
| 2 | Add `EmptyStateComponentPreview` (5 required + 2 bonus variants) | Clone | ✅ |
| 3 | Add "Empty State" kitchen sink section + update kitchen sink test | Clone | ✅ |
| 4 | Update `docs/COMPONENT_CATALOG.md` (Quick Reference + Details) | Clone | ✅ |

## Prerequisites

- Design: `docs/designs/empty-state-component.md`
- Prototype: None (follows existing component conventions/tokens)
- Feature branch `feature/cov-18-empty-state-component` exists (run /branch if needed)

## Tasks

### Task 1 [Master]: Build `EmptyStateComponent` + test

**Skills:** style-ui, write-tests
**Reference:** Read `app/components/alert_component.rb` + `.html.erb` (required `title:` kwarg, enum guarding with `VARIANTS.include?`, `custom_icon`/`html_safe` slot pattern) and `app/components/card_component.rb` (neutral token vocabulary, `.compact.reject(&:empty?).join(" ")` class assembly, `well` bordered treatment `border border-dashed border-black/10 dark:border-white/10 rounded-xl`).

**In scope:**

- `app/components/empty_state_component.rb`:
  - `initialize(title:, description: nil, size: :md, bordered: false, heading_level: 2, classes: nil)` — `super()` first.
  - `SIZES = %i[sm md lg].freeze`; guard invalid `size` → `:md` (like `CardComponent`).
  - Clamp `heading_level` to `1..6`, default `2` (out-of-range → `2`).
  - Slots: `renders_one :icon`, `renders_one :primary_action`, `renders_one :secondary_action`.
  - Per-size helpers for icon backdrop size, title text (`text-base`/`text-lg`/`text-xl`), description text (`text-sm`/`text-sm`/`text-base`), vertical padding (`py-8`/`py-12`/`py-16`), and action-row top margin.
  - Wrapper class helper: `flex flex-col items-center text-center max-w-sm mx-auto` + padding + optional bordered well + `@classes`.
- `app/components/empty_state_component.html.erb`, per design's rendered structure:
  - Icon block **only if `icon?`** — `rounded-full bg-neutral-100 dark:bg-neutral-800 text-neutral-400`, sized per size, `aria-hidden="true"`; render the slot markup (raw SVG passthrough).
  - Title as `content_tag "h#{heading_level}"` — `text-neutral-900 dark:text-neutral-100 font-semibold` + size text class.
  - Description **only if present** — `text-neutral-500 dark:text-neutral-400` + size text class.
  - Action row **only if `primary_action?` or `secondary_action?`** — `flex gap-3` centered, top margin per size; render whichever slots are present (secondary-only allowed).
- `test/components/empty_state_component_test.rb` (Minitest + `ViewComponent::TestCase`, mirror `alert_component_test.rb`).

**NOT in scope:** Lookbook preview, kitchen sink, catalog docs (later tasks). Any real feature wiring. Adding an icon gem.

**Build order:**

1. **Test:** `test/components/empty_state_component_test.rb` — assert: renders required title; renders description when given; omits icon backdrop when no `with_icon` slot (assert the muted-circle class is absent); omits action row when no action slots; renders secondary alone when only `with_secondary_action` given; `heading_level: 3` renders an `<h3>`; invalid `size` (e.g. `:xl`) falls back to `:md` classes; `bordered: true` adds `border-dashed`.
2. **Implement:** the two component files above. Quick check: RailsBlocks has no empty-state block to reuse, so build from scratch following `AlertComponent`/`CardComponent`.
3. **Verify:** `mise exec -- bin/rails test test/components/empty_state_component_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 2 [Clone]: `EmptyStateComponentPreview`

**Skills:** style-ui
**Reference:** Read `test/components/previews/alert_component_preview.rb` (method-per-variant style; hand-written sample SVGs inline).

**In scope:** `test/components/previews/empty_state_component_preview.rb` with the 5 required variants — `default`, `no_icon`, `primary_only`, `primary_and_secondary`, `empty_search_results` (`size: :sm`, magnifier SVG, "No results found" + short description, secondary "Clear filters" ghost `ButtonComponent`) — plus bonus `sizes` and `bordered`. Actions via `ButtonComponent.new(...)`; icons are hand-written `<svg>` passed into `with_icon`.

**NOT in scope:** Component logic changes. Kitchen sink. Docs.

**Build order:**

1. **Test:** N/A (preview file). Rely on Task 1's component test and the kitchen sink test for coverage.
2. **Implement:** the preview file.
3. **Verify:** `mise exec -- bin/rails test test/components/empty_state_component_test.rb` (still green); confirm previews load in Lookbook if running `bin/dev`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding.

### Task 3 [Clone]: Kitchen sink section + test

**Skills:** style-ui
**Reference:** Read `app/views/dev/kitchen_sink/show.html.erb` (section pattern: `<section class="py-10"><h2>…</h2>…</section>`) and `test/integration/dev/kitchen_sink_test.rb`.

**In scope:**

- Add an "Empty State" `<section>` to `app/views/dev/kitchen_sink/show.html.erb` (after "Data Display") rendering a representative couple: a default full-page variant (icon + title + description + primary action) and a compact `:sm` empty-search-results variant.
- Update `test/integration/dev/kitchen_sink_test.rb`: add `Empty\ State` to the `%w[...]` section-name array asserted with `assert_select "h2"`.

**NOT in scope:** Component logic. Preview file. Catalog docs.

**Build order:**

1. **Test:** update the section-name array in `kitchen_sink_test.rb`.
2. **Implement:** the new section markup.
3. **Verify:** `mise exec -- bin/rails test test/integration/dev/kitchen_sink_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding.

### Task 4 [Clone]: Catalog docs

**Reference:** Read `docs/COMPONENT_CATALOG.md` (Quick Reference table row format + a "Component Details" section like `AlertComponent`/`CardComponent`).

**In scope:** Add an `EmptyStateComponent` row to the Quick Reference table (`title`, `description`, `size`, `bordered`, `heading_level` as key args; preview `EmptyStateComponentPreview`) and a "Component Details" section documenting purpose, the full props table (from the design doc), the three optional slots, and the size scale.

**NOT in scope:** Any code. Kitchen sink.

**Build order:**

1. **Test:** N/A (docs only).
2. **Implement:** the catalog edits.
3. **Verify:** N/A — proofread against the component's actual API from Task 1.
4. **Review:** After completion, ALWAYS run review-changes before proceeding.

## Task Dependencies

- Task 1 first — it creates the component every other task references and sets the pattern (Master).
- Tasks 2, 3, and 4 all depend on Task 1 and can run in parallel (they touch disjoint files: preview / kitchen-sink view+test / catalog doc).
