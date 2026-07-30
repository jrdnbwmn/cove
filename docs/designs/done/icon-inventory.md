> Ticket: COV-61
> Branch: feature/cov-61-migrate-icons
> Status: Retired — the migration this doc backlogged is complete.

# Icon Inventory (retired)

This started life in COV-27 as the migration backlog for hand-pasted `<svg>`
markup across the app. That migration is done. This file is kept as the
historical record of what moved to the `icon` helper, what deliberately did
not, and why.

**Lineage**

| Ticket | What it did |
| --- | --- |
| COV-27 | Added `rails_icons` + Lucide, proved the pattern on `AlertComponent`, produced this inventory. See `docs/designs/done/icon-set.md`. |
| COV-28 | Migrated the remaining 30 locations. See `docs/designs/done/inline-svg-to-icon-helper-migration.md`. |
| COV-61 | Verified the end state and retired this doc. No code changes. |

COV-61 was filed against this file while it still read as a 32-location
backlog, before it had been updated to reflect COV-28. Its two "flagged
decisions" (`_dev_menu`, `loading_indicator_component`) had already been
decided in COV-28 — both as *leave as-is*. They are restated below so the
reasoning is findable without digging through a closed ticket's design doc.

## Verified end state

A scan of the app tree finds hand-pasted SVG in exactly three files:

```bash
grep -rn "<svg\|tag.svg" app/components app/views
```

Those three are the deliberate non-migrations in the second table. Everything
else renders through the `icon` helper.

## Migrated

Lucide names below are what actually shipped, which in several places differs
from this doc's original suggestion — the "deviation" column records why.

### Design-system components

| Location | Purpose | Lucide name(s) shipped | Deviation from original suggestion |
| --- | --- | --- | --- |
| `app/components/alert_component.rb` | Variant feedback icons | `circle-check`, `circle-alert`, `triangle-alert`, `info` | — (done in COV-27) |
| `app/components/badge_component.html.erb` | Remove a dismissible badge | `x` | — |
| `app/components/breadcrumb_component.rb` | Home item and separator | `house`, `chevron-right` | — |
| `app/components/button_component.rb` | Loading spinner | `loader-circle` + `animate-spin` | — |
| `app/components/dropdown_component.rb` | Trigger chevron, kebab menu | `chevron-down`, `ellipsis` | — |
| `app/components/dropdown_component/submenu_component.rb` | Nested-menu disclosure | `chevron-right` | — |
| `app/components/navbar_component.rb` | Mobile navigation toggle | `menu` | — |
| `app/components/navbar_component/item_component.rb` | Dropdown-item disclosure | `chevron-down` | — |
| `app/components/pagination_component.rb` | Previous / next controls | `chevron-left`, `chevron-right` | — |
| `app/components/plan_card_component.html.erb` | Included plan feature | `check` | — |
| `app/components/sidebar_component.html.erb` | Expand, collapse, mobile nav | `panel-left-open`, `panel-left-close`, `menu` | — |
| `app/components/sidebar_component/section_component.html.erb` | Section disclosure | `chevron-right` | — |
| `app/components/sidebar_component/section_item_component.html.erb` | Per-item overflow actions | `ellipsis` | — |
| `app/components/switch_component.html.erb` | Unchecked / checked states | `x`, `check` | — |
| `app/components/ui_modal_component.rb` | Close control | `x` | — |

### App views

| Location | Purpose | Lucide name(s) shipped | Deviation from original suggestion |
| --- | --- | --- | --- |
| `app/views/account_users/edit.html.erb` | Breadcrumb separator | `chevron-right` | — |
| `app/views/accounts/account_invitations/edit.html.erb` | Breadcrumb separator | `chevron-right` | — |
| `app/views/accounts/account_invitations/new.html.erb` | Breadcrumb separator | `chevron-right` | — |
| `app/views/accounts/edit.html.erb` | Breadcrumb separator | `chevron-right` | — |
| `app/views/accounts/new.html.erb` | Breadcrumb separator | `chevron-right` | This doc called it a "new-account heading icon" and suggested `building-2`. It is a breadcrumb separator. |
| `app/views/accounts/show.html.erb` | Admin/role marker | `shield-check` | Suggested `users`; the mark sits next to an administrator role, so `shield-check` carries the meaning. |
| `app/views/api_tokens/edit.html.erb` | Heading icon + separators | `key-round`, `chevron-right` ×2 | — |
| `app/views/api_tokens/new.html.erb` | Breadcrumb separator | `chevron-right` | Suggested `key-round`; this file's only SVG is a separator, not a heading mark. |
| `app/views/api_tokens/show.html.erb` | Breadcrumb separator + copy affordance | `chevron-right`, `copy` | Suggested `key-round`, `copy`; same misread as above. |
| `app/views/application/_account_menu.html.erb` | Account/team menu entry | `users` | — |
| `app/views/application/_navbar.html.erb` | Responsive navigation toggle | `menu` | — |
| `app/views/application/_notifications.html.erb` | Notifications entry | `bell` | — |
| `app/views/billing/_charges.html.erb` | Receipt download links | `download` ×2 | Suggested `receipt`, `rotate-ccw`; both marks are receipt *download* affordances, not a receipt icon and a refund status. |
| `app/views/billing/subscriptions/payment_methods/new.html.erb` | Breadcrumb separator | `chevron-right` | — |
| `app/views/checkouts/show.html.erb` | Plan feature + help marker | `check`, `circle-question-mark` | — |
| `app/views/dev/kitchen_sink/show.html.erb` | Helper demo + EmptyState examples | `inbox`, `folder`, `search` | — |

## Deliberately not migrated

These keep their hand-pasted SVG. Decided in COV-28, reaffirmed in COV-61.

| Location | Decision | Reasoning |
| --- | --- | --- |
| `app/views/application/_dev_menu.html.erb` | Keep the custom mark | It is the Jumpstart **brand glyph**, not a generic tool icon, on a dev-only menu. Swapping it for `wrench` would trade a brand mark for a generic one and lose the meaning. |
| `app/components/loading_indicator_component.html.erb` | Keep both spinners | The stepped iOS-style spinner (8 fading tick marks, `animate-[spin_0.8s_steps(8)_infinite]`) and the smooth circular spinner are bespoke Rails Blocks art. Lucide's single-arc `loader-circle` cannot reproduce the stepped one, so adopting it would silently delete the component's `stepped:` variant. `ButtonComponent`'s spinner already uses `loader-circle`; the two coexist intentionally. |

## Open follow-up

`app/components/password_component.html.erb` (9 SVGs) is **not** done and is not
a simple swap. Its eye show/hide toggle and requirement-checklist marks are
re-rendered at runtime by `app/javascript/controllers/password_controller.js`,
which injects SVG through `innerHTML = "<svg>…</svg>"` string literals
(`password_controller.js:276`, `:301`, `:336`, `:341`). Migrating only the ERB
copies would make the icon visibly morph to a different style on first
interaction.

A clean migration renders every state server-side via the `icon` helper and has
the controller toggle `hidden` instead of injecting markup — an ERB change plus
a Stimulus rewrite, in one component. That is its own ticket, not part of this
inventory.

## Out of scope

- **SVG injected by JavaScript controllers or CSS** — e.g.
  `app/javascript/controllers/select_controller.js`,
  `app/assets/stylesheets/forms.css`. A different mechanism; assess separately.
  (The `password_controller.js` case above is the one place this mechanism
  blocks an otherwise in-scope ERB migration.)
- **`lib/jumpstart/app/views/**`** — the vendored Jumpstart engine's own views
  still carry ~60 hand-pasted SVGs. Every one that matters is shadowed by an
  `app/views/` override that has already been migrated. Editing vendored engine
  code was never in scope for any of these tickets.
- **Heroicons / secondary icon libraries** — not installed. One command to add
  (`rails generate rails_icons:install --libraries=heroicons`) if ever needed.
