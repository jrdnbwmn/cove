> Ticket: COV-27
> Branch: jrdnbwmn/cov-27-icon-set

# Plan: Icon set for the design system (rails_icons + Lucide)

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Install rails_icons + Lucide, configure default library, enable `icon` in ViewComponents, vendor SVGs | Master | ✅ |
| 2 | Swap `AlertComponent` variant icons to `icon` helper calls | Master | ✅ |
| 3 | Prove the pattern: kitchen-sink `icon "inbox"` + EmptyState slot preview | Clone | |
| 4 | Document Icons usage in `COMPONENT_CATALOG.md` | Clone | |
| 5 | Produce icon inventory audit doc (backlog for follow-up migration) | Master | |

## Prerequisites

- Design: `docs/designs/icon-set.md`
- Prototype: None
- Feature branch `jrdnbwmn/cov-27-icon-set` already exists
- Run all Rails/bin commands through `mise exec --` in this workspace

## Tasks

### Task 1 [Master]: Install rails_icons + Lucide, enable in ViewComponents

**Skills:** none special (dependency + config change)
**Reference:** rails_icons README / generator output for exact helper module path and initializer keys

**In scope:**

- Add `gem "rails_icons"` to `Gemfile` (near the `view_component` UI gems, ~line 22); `mise exec -- bundle install`.
- Run `mise exec -- rails generate rails_icons:install --library=lucide` (full sync, **no** `--skip-sync`). This creates `config/initializers/rails_icons.rb` and syncs the full Lucide set into `app/assets/svg/icons/lucide/` (~1,600 vendored SVGs).
- In `config/initializers/rails_icons.rb`, set `config.default_library = "lucide"`.
- In the same initializer, make `icon` callable inside ViewComponents by including the helper into the component base: `ViewComponent::Base.include(RailsIcons::Helpers::IconHelper)` (confirm the exact module path from the installed gem — the design names `RailsIcons::Helpers::IconHelper`; verify before committing).
- Add `.gitattributes` entry so the vendored folder doesn't dominate diffs: `app/assets/svg/icons/lucide/** linguist-vendored` and a `-diff` note.

**NOT in scope:**

- Heroicons or any secondary library (deferred).
- Any component/view SVG replacement (that's Task 2+).

**Build order:**

1. **Implement:** gem + generator + initializer edits + `.gitattributes` as above.
2. **Verify:** `mise exec -- rails runner 'puts RailsIcons::VERSION'` boots clean, and `mise exec -- rails runner 'puts helper.icon("inbox")'`-style smoke or a booting `mise exec -- rails test` proves the app still loads. Confirm `app/assets/svg/icons/lucide/inbox.svg` exists.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 2 [Master]: Swap AlertComponent icons to `icon` helper

**Skills:** write-tests, style-ui
**Reference:** Read `app/components/alert_component.rb` (lines 85–140) and `app/components/alert_component.html.erb`

**In scope:**

- In `alert_component.rb`, replace the `success_icon`/`error_icon`/`warning_icon`/`info_icon` `tag.svg` builders and `svg_group_attrs` with `icon(...)` calls dispatched by variant. Suggested Lucide names (verify each exists in the synced set): success → `circle-check`, error → `circle-alert`, warning → `triangle-alert`, info/neutral → `info`. Size with a class (e.g. `class: "size-[18px]"` to preserve the ~18px footprint) — accepted visual change to Lucide shapes.
- Keep `@custom_icon` override behavior intact (`return @custom_icon.html_safe if @custom_icon.present?`).
- Leave the `.html.erb` icon `<span>` wrapper and `colors[:icon]` coloring as-is (icons inherit `currentColor`).

**NOT in scope:**

- Any change to Alert's colors, layout, variants list, or other components.

**Build order:**

1. **Test:** Update `test/components/alert_component_test.rb` — add an assertion that `render_inline(AlertComponent.new(title: "Saved", variant: :success))` renders an `<svg` (proves both the swap and the ViewComponent base-include from Task 1). Keep existing preview test.
2. **Implement:** rewrite `icon_svg` dispatch + delete the four builder methods and `svg_group_attrs`.
3. **Verify:** `mise exec -- rails test test/components/alert_component_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 3 [Clone]: Prove the pattern in a view and a component slot

**Skills:** style-ui
**Reference:** Read `app/views/dev/kitchen_sink/show.html.erb` and `test/components/previews/empty_state_component_preview/default.html.erb`

**In scope:**

- Kitchen sink: add a new `<section>` (an "Icons" section, matching the existing `<section class="py-10">` pattern) rendering `<%= icon "inbox", class: "size-5" %>` in a plain view — proves the helper in a plain view.
- EmptyState slot demo: add a preview method `with_lucide_icon` to `test/components/previews/empty_state_component_preview.rb` (using `render_with_template`, like its siblings) plus a new template `test/components/previews/empty_state_component_preview/with_lucide_icon.html.erb` that renders `EmptyStateComponent` and passes `<% c.with_icon do %><%= icon "inbox", class: "w-full h-full" %><% end %>` into the icon slot — proves `icon("inbox")` flows into the slot (component untouched).

**NOT in scope:**

- Editing `EmptyStateComponent` itself; any other kitchen-sink section; AlertComponent (Task 2).

**Build order:**

1. **Implement:** kitchen-sink section + preview method + preview template.
2. **Verify:** `mise exec -- rails test` green; optionally load `/rails/lookbook` for `EmptyStateComponent` → `with_lucide_icon` and the kitchen sink to eyeball the icon renders.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 4 [Clone]: Document Icons usage in the component catalog

**Skills:** none special
**Reference:** Read `docs/COMPONENT_CATALOG.md` (structure/heading style)

**In scope:**

- Add an "Icons" section to `docs/COMPONENT_CATALOG.md` covering: calling `icon "name"` in views and in component templates; sizing via utility classes (`class: "size-5"`); `stroke_width:` option; and passing an icon into a component slot (`c.with_icon { icon "inbox" }`), using EmptyState as the example. Note Lucide is the default library and that icons are inline SVG inheriting `currentColor`.
- Mention that a secondary library (Heroicons) is a one-command add, deferred.

**NOT in scope:**

- Adding a row to the component Quick Reference table (icons are a helper, not a ViewComponent). Editing any component docs.

**Build order:**

1. **Implement:** new Icons section in the catalog.
2. **Verify:** re-read the section for accuracy against the shipped helper API.
3. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 5 [Master]: Produce the icon inventory audit doc

**Skills:** none special (research + doc)
**Reference:** grep the codebase for existing hand-pasted SVGs

**In scope:**

- Create `docs/designs/icon-inventory.md` listing **every remaining hand-pasted SVG location** with a suggested Lucide mapping, as a backlog table for the follow-up migration ticket. Group by design-system components (~10) and app views (~20).
- Find locations with: `grep -rn "tag.svg\|<svg" app/components app/views` (exclude `app/assets/svg/icons/lucide`). For each, record file, rough purpose, and a suggested Lucide name.
- Explicitly exclude SVGs injected via JS controllers / CSS (`select_controller.js`, `forms.css`, etc.) — note them as out of scope (different mechanism).

**NOT in scope:**

- Actually replacing any SVGs. AlertComponent (already done in Task 2 — mark it done in the inventory).

**Build order:**

1. **Implement:** run the greps, build the inventory table, write the doc.
2. **Verify:** spot-check 3–4 listed files against the doc; confirm counts roughly match the design's "~33 files".
3. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

## Task Dependencies

- Task 2 depends on Task 1 (needs the gem, Lucide sync, and the ViewComponent base include).
- Task 3 depends on Task 1 (needs the `icon` helper + synced SVGs). Independent of Task 2.
- Task 4 depends on Task 1 (documents the shipped helper); best written after Task 2 so the AlertComponent example is accurate.
- Task 5 is fully independent — it audits the codebase as-is and can run in parallel with everything (including before Task 1).
- Tasks 3, 4, 5 can run in parallel once Task 1 (and, for 4, Task 2) is done.
