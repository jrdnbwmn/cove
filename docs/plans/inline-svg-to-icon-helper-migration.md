> Ticket: COV-28
> Branch: jrdnbwmn/cov-28-migrate-inline-svgs

# Plan: Migrate hand-pasted inline SVGs to the icon helper

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Nav & chrome components (navbar, sidebar, dropdown) | Master | ✅ |
| 2 | Other components (badge, breadcrumb, button, pagination, plan-card, switch, ui-modal) | Master | ✅ |
| 3 | Breadcrumb-separator views | Master | ✅ |
| 4 | Heading/action views | Master | ✅ |
| 5 | Billing / checkout / dev views | Master | ✅ |
| 6 | Final sweep + full test suite | Master | |

## Prerequisites

- Design: `docs/designs/inline-svg-to-icon-helper-migration.md`
- Mapping reference: `docs/designs/icon-inventory.md`
- Prototype: None (Lucide is the visual reference)
- Feature branch `jrdnbwmn/cov-28-migrate-inline-svgs` exists ✓

## Shared mechanics (applies to every task)

**Two SVG idioms to convert:**
1. **Raw `<svg>…</svg>` in `.html.erb`** → `<%= icon "name", class: "…" %>`
2. **`tag.svg`/`tag.path` Ruby builders in `.rb` component files** → return `icon("name", class: "…")` (exactly as the already-migrated `alert_component.rb:89-92` does). The `icon` helper is available in ViewComponent render context.

**Per-swap preservation rules (from the design):**
- **Size:** map `width`/`height` and existing `size-*`/`w-*`/`h-*` classes to `class: "size-*"`. Keep other layout classes (`shrink-0`, etc.). Example: `breadcrumb_component.rb`'s `chevron_svg` → `icon "chevron-right", class: "size-4 shrink-0 #{separator_classes}"`; `home_icon_svg` → `icon "house", class: "size-4 shrink-0"`.
- **Color:** `currentColor` is inherited — leave surrounding `text-*` / `dark:text-*` classes untouched.
- **State toggling:** keep `hidden`, `data-*-target`, and any Stimulus hooks intact on the icon or its wrapper.
- **Accessibility:** preserve `aria-*`, `aria-hidden`, and labels.

**Mapping source:** use the per-location Lucide names in the design's "Screens / Flows" tables (mirrored in `icon-inventory.md`). Do not invent mappings.

**Env:** `export PATH="$HOME/.local/share/mise/shims:$PATH"` before any `bin/rails`/`bin/rubocop`. Never run RuboCop on `.erb` paths — use project-wide `bin/rubocop`.

**No test changes expected:** verified that no component/view test asserts on the swapped SVG path markup, so swaps shouldn't break existing tests. If one does, update it to assert on the icon's rendered output instead.

## Tasks

### Task 1 [Master]: Nav & chrome components

**Skills:** style-ui
**Reference:** `app/components/alert_component.rb:85-95` (`.rb` icon-helper idiom)

**In scope — swap SVGs per mapping in these 7 files:**
- `app/components/navbar_component.rb` → `menu`
- `app/components/navbar_component/item_component.rb` → `chevron-down`
- `app/components/dropdown_component.rb` → `chevron-down`, `ellipsis`
- `app/components/dropdown_component/submenu_component.rb` → `chevron-right`
- `app/components/sidebar_component.html.erb` → `panel-left-open`, `panel-left-close`, `menu`
- `app/components/sidebar_component/section_component.html.erb` → `chevron-right`
- `app/components/sidebar_component/section_item_component.html.erb` → `ellipsis`

**NOT in scope:** any file not listed; changing component APIs, classes, or behavior; the deferred `loading_indicator`/`password`/`_dev_menu` items.

**Build order:**
1. **Swap:** replace each SVG following the shared mechanics; preserve toggle state on sidebar expand/collapse and dropdown/submenu chevrons.
2. **Verify (tests):** `bin/rails test test/components/navbar_component_test.rb test/components/dropdown_component_test.rb test/components/sidebar_component_test.rb`
3. **Verify (live):** run the app; review navbar, sidebar (expanded + collapsed + mobile), dropdown, and submenu in Lookbook / kitchen-sink. Confirm icon shapes/sizes/toggles read correctly.
4. **Review:** run review-changes, then commit.

### Task 2 [Master]: Other components

**In scope — swap SVGs per mapping in these 7 files:**
- `app/components/badge_component.html.erb` → `x`
- `app/components/breadcrumb_component.rb` → `house`, `chevron-right`
- `app/components/button_component.rb` → `loader-circle` + existing `animate-spin` class
- `app/components/pagination_component.rb` → `chevron-left`, `chevron-right`
- `app/components/plan_card_component.html.erb` → `check`
- `app/components/switch_component.html.erb` → `x`, `check`
- `app/components/ui_modal_component.rb` → `x`

**NOT in scope:** files outside the list; the deferred items; any spinner other than `button_component`'s loading spinner.

**Build order:**
1. **Swap:** follow shared mechanics. For `button_component`, keep the existing spin/`animate-spin` class on `loader-circle`. For `switch_component`, keep `x`/`check` bound to unchecked/checked state hooks.
2. **Verify (tests):** `bin/rails test test/components/badge_component_test.rb test/components/breadcrumb_component_test.rb test/components/button_component_test.rb test/components/pagination_component_test.rb test/components/plan_card_component_test.rb test/components/switch_component_test.rb test/components/ui_modal_component_test.rb`
3. **Verify (live):** review each in Lookbook / kitchen-sink — badge dismiss, breadcrumb home+separator, button loading state, pagination prev/next, plan-card check, switch on/off, modal close.
4. **Review:** run review-changes, then commit.

### Task 3 [Master]: Breadcrumb-separator views

**In scope — swap the separator SVG (→ `chevron-right`) in these 6 views:**
- `app/views/account_users/edit.html.erb`
- `app/views/accounts/account_invitations/edit.html.erb`
- `app/views/accounts/account_invitations/new.html.erb`
- `app/views/accounts/edit.html.erb`
- `app/views/api_tokens/edit.html.erb` → `key-round`, `chevron-right`
- `app/views/billing/subscriptions/payment_methods/new.html.erb`

**NOT in scope:** heading/action icons on those same screens that aren't listed here (except api_tokens/edit's `key-round`); files outside the list.

**Build order:**
1. **Swap:** replace each separator `<svg>` with `<%= icon "chevron-right", class: "…" %>`, preserving size/color classes.
2. **Verify (tests):** `bin/rails test` (view/integration coverage for these controllers, if any).
3. **Verify (live):** load each page; confirm breadcrumb separators (and api_tokens `key-round`) render correctly.
4. **Review:** run review-changes, then commit.

### Task 4 [Master]: Heading / action views

**In scope — swap SVGs per mapping in these 7 views:**
- `app/views/accounts/new.html.erb` → `chevron-right`
- `app/views/accounts/show.html.erb` → `shield-check`
- `app/views/api_tokens/new.html.erb` → `chevron-right`
- `app/views/api_tokens/show.html.erb` → `chevron-right`, `copy`
- `app/views/application/_account_menu.html.erb` → `users`
- `app/views/application/_navbar.html.erb` → `menu`
- `app/views/application/_notifications.html.erb` → `bell`

**NOT in scope:** the deferred `_dev_menu` Jumpstart logo; files outside the list.

**Build order:**
1. **Swap:** follow shared mechanics; preserve the copy affordance's Stimulus hooks on api_tokens/show `copy`, and any menu toggle state on `_navbar`/`_account_menu`.
2. **Verify (tests):** `bin/rails test`.
3. **Verify (live):** review new/show account, api token new/show (test copy button), account menu, navbar, notifications bell.
4. **Review:** run review-changes, then commit.

### Task 5 [Master]: Billing / checkout / dev views

**In scope — swap SVGs per mapping in these 3 views:**
- `app/views/billing/_charges.html.erb` → `download` (both PDF-download links)
- `app/views/checkouts/show.html.erb` → `check`, `circle-question-mark`
- `app/views/dev/kitchen_sink/show.html.erb` → `folder`, `search` (EmptyState examples)

**NOT in scope:** files outside the list.

**Build order:**
1. **Swap:** follow shared mechanics; for kitchen_sink EmptyState examples use the `with_icon { icon "…", class: "w-full h-full" }` slot pattern (catalog Icons section).
2. **Verify (tests):** `bin/rails test`.
3. **Verify (live):** review a charges list (receipt + refund status), checkout page (feature check + help marker), and `/dev/kitchen_sink` EmptyState examples.
4. **Review:** run review-changes, then commit.

### Task 6 [Master]: Final sweep + full suite

**In scope:**
- Re-run the inventory scan to confirm no in-scope hand-pasted SVGs remain: `grep -rn "tag.svg\|<svg" app/components app/views` and confirm every remaining hit is a documented deferred item (`loading_indicator_component`, `password_component`, `_dev_menu`).
- Full suite: `bin/rails test`.
- `bin/rubocop` (project-wide, not on `.erb` paths).

**NOT in scope:** touching any deferred item.

**Build order:**
1. **Verify:** run the grep + `bin/rails test` + `bin/rubocop`; show output.
2. **Review:** run review-changes; final commit if anything outstanding.

## Task Dependencies

- Tasks are independent by file set and could technically run in any order, **but** run them **sequentially (1 → 5)** to honor the design's "one batch = one commit = one live-review checkpoint" rule and keep each review focused.
- Task 6 depends on Tasks 1–5 being complete.
- All tasks are **Master** — each requires live visual judgment on the running app, which a clone can't perform.
