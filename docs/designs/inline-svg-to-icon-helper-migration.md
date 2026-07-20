> Ticket: COV-28
> Branch: jrdnbwmn/cov-28-migrate-inline-svgs
> Plan created: docs/plans/inline-svg-to-icon-helper-migration.md

# Feature: Migrate hand-pasted inline SVGs to the icon helper

## Problem

Since COV-27 the app has a single icon foundation — the `rails_icons` `icon`
helper backed by Lucide — but ~30 locations across the app still render
hand-pasted `<svg>` markup (most of it inherited from the Rails Blocks starter
set in COV-12). This is inconsistent, hard to maintain, and means icon changes
have to be made SVG-by-SVG. Migrating them to `icon "…"` calls standardizes on
one icon system.

## Approach

Replace each in-scope hand-pasted `<svg>` with the equivalent Lucide `icon`
helper call, working **one screen/component at a time with live visual review**.
Every swap is a deliberate visual decision — Lucide shapes differ from the
current custom SVGs — so each batch is reviewed in the running app before moving
on.

The mapping comes from the COV-27 inventory doc
(`docs/designs/icon-inventory.md`). For every swap, preserve the location's
existing **size** (map `width`/`height` and existing `size-*` classes to the
appropriate `class: "size-*"`), **color** (`currentColor` is inherited, so keep
the surrounding text-color classes), **visibility/state toggling**
(`hidden`/`data-*-target` hooks stay intact), and **accessibility treatment**
(`aria-*`, `aria-hidden`, labels).

The `icon` helper: `icon "name"`, `icon "name", class: "size-5"`,
`icon "name", class: "size-5", stroke_width: 1.5`. Icons render as inline SVG
and inherit `currentColor`. Lucide is the configured default, so no library
prefix is needed. See `docs/COMPONENT_CATALOG.md` → Icons.

**Sequencing** — design-system components first (shared, reviewable in Lookbook
/ the kitchen-sink page), then app views grouped by area, in ≤7-file batches so
each batch is one commit + one live-review checkpoint:

1. **Nav & chrome components** — navbar (+ item), sidebar (+ section,
   section-item), dropdown (+ submenu)
2. **Other components** — badge, breadcrumb, button spinner, pagination,
   plan-card, switch, ui-modal
3. **Breadcrumb-separator views** — account_users/edit, the two account
   invitation views (edit, new), accounts/edit, api_tokens/edit, billing
   payment-methods/new
4. **Heading/action views** — accounts (new, show), api_tokens (new, show),
   _account_menu, _notifications, _navbar
5. **Billing / checkout / dev** — billing/_charges, checkouts/show,
   kitchen_sink/show

## Acceptance Criteria

- All in-scope hand-pasted SVGs replaced with `icon` helper calls.
- Each affected screen/component visually reviewed live; intended icon changes
  are deliberate, not accidental. Existing size, color, state toggling, and
  accessibility treatment preserved.
- `bin/rails test` green.

## Prototype

None. Visual reference for target icons is Lucide (the configured library) plus
the per-location mapping in `docs/designs/icon-inventory.md`.

## Data Model

None — view/component markup only. No models, migrations, routes, or
controllers change.

## Screens / Flows

No new flows. Each swap is an in-place markup change to an existing
component/view. In-scope locations and their Lucide mappings:

**Design-system components (14)**

| Location | Lucide mapping |
| --- | --- |
| `badge_component.html.erb` | `x` (dismiss) |
| `breadcrumb_component.rb` | `house`, `chevron-right` |
| `button_component.rb` | `loader-circle` + existing `animate-spin` class (loading spinner) |
| `dropdown_component.rb` | `chevron-down`, `ellipsis` |
| `dropdown_component/submenu_component.rb` | `chevron-right` |
| `navbar_component.rb` | `menu` |
| `navbar_component/item_component.rb` | `chevron-down` |
| `pagination_component.rb` | `chevron-left`, `chevron-right` |
| `plan_card_component.html.erb` | `check` |
| `sidebar_component.html.erb` | `panel-left-open`, `panel-left-close`, `menu` |
| `sidebar_component/section_component.html.erb` | `chevron-right` |
| `sidebar_component/section_item_component.html.erb` | `ellipsis` |
| `switch_component.html.erb` | `x`, `check` |
| `ui_modal_component.rb` | `x` |

**App views (16)**

| Location | Lucide mapping |
| --- | --- |
| `account_users/edit.html.erb` | `chevron-right` |
| `accounts/account_invitations/edit.html.erb` | `chevron-right` |
| `accounts/account_invitations/new.html.erb` | `chevron-right` |
| `accounts/edit.html.erb` | `chevron-right` |
| `accounts/new.html.erb` | `building-2` |
| `accounts/show.html.erb` | `users` |
| `api_tokens/edit.html.erb` | `key-round`, `chevron-right` |
| `api_tokens/new.html.erb` | `key-round` |
| `api_tokens/show.html.erb` | `key-round`, `copy` |
| `application/_account_menu.html.erb` | `users` |
| `application/_navbar.html.erb` | `menu` |
| `application/_notifications.html.erb` | `bell` |
| `billing/_charges.html.erb` | `receipt`, `rotate-ccw` |
| `billing/subscriptions/payment_methods/new.html.erb` | `chevron-right` |
| `checkouts/show.html.erb` | `check`, `circle-question-mark` |
| `dev/kitchen_sink/show.html.erb` | `folder`, `search` (EmptyState examples) |

## Scope

**In:** The 14 design-system components and 16 app views above — 30 files of
pure-ERB / template hand-pasted SVGs swapped to `icon` helper calls.

**Deferred:**

- **`loading_indicator_component`** — already the self-hosted Rails Blocks
  loading indicator (COV-12). Its two spinners (stepped iOS-style + smooth
  circular) are Rails Blocks' bespoke hand-drawn SVGs that Lucide's single-arc
  `loader-circle` cannot reproduce. Left as-is by design.
- **`_dev_menu` Jumpstart logo** — the custom mark is the Jumpstart *brand*
  glyph, not a generic tool icon, on a dev-only menu. Replacing it with `wrench`
  would discard brand meaning. Left as-is.
- **`password_component`** — genuinely entangled with JS-injected SVGs. Its eye
  show/hide toggle and confirm match/mismatch icons are re-rendered by
  `password_controller.js` via `innerHTML = "<svg>…</svg>"` string injection.
  Swapping only the ERB copies would make the icon visibly morph to a
  different-style SVG on first interaction. A clean migration must also rewrite
  the Stimulus controller's string injection — which is the "SVGs injected via
  JS controllers" mechanism the inventory explicitly puts out of scope. Deferred
  as its own small follow-up that does eye + match + requirement checklist
  (and the JS) together.
- **JS/CSS-injected SVGs generally** — e.g. `select_controller.js`,
  `forms.css`. Different mechanism; out of scope per the inventory.
- **`alert_component`** — already migrated in COV-27.

## Open Questions

None.

## More Info

- The app has dark mode intentionally disabled but keeps `dark:` utilities
  inert; icons inherit `currentColor`, so surrounding `dark:text-*` classes
  stay untouched and remain harmless.
- Do NOT run RuboCop directly on `.erb` paths (it parses them as Ruby). Use the
  project-wide `bin/rubocop` command. Prepend the mise shims dir before any
  `bin/rails`/`bin/rubocop` call: `export PATH="$HOME/.local/share/mise/shims:$PATH"`.
</content>
</invoke>
