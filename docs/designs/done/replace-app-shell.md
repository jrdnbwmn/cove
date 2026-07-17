> Ticket: COV-13
> Branch: feature/cov-13-replace-app-shell
> Plan created: docs/plans/replace-app-shell.md

# Feature: Rebuild the app shell with design-system components

## Problem
Jumpstart's app chrome (the layout + its nav/flash/footer partials) still uses
hand-rolled Jumpstart markup and CSS (`top_nav.css`, `nav.css`, the `dropdown`
Stimulus controller). Now that COV-12 shipped a curated Rails Blocks component
library, the shell should be rebuilt on that vocabulary + design tokens. This is a
**visual replacement, not a feature change** — every existing shell behavior must
survive. No auth/billing/Devise logic is touched.

## Approach
Rebuild the shell as **app-level partials that shadow the vendored engine**, built
as a thin app-specific top bar that **composes design-system pieces where they fit**
rather than adopting the whole `NavbarComponent`.

### Key decisions (locked in brainstorm)

1. **Override in `app/views/application/`, don't edit the engine.** The shell
   partials live in the vendored in-repo Jumpstart engine
   (`lib/jumpstart/app/views/application/`). Rails app views win over engine views,
   and the app already shadows `_head`, `_left_nav`, `_right_nav` + the layout this
   way. We create app-level `_navbar`, `_flash`, `_footer`, `_account_menu`,
   `_user_menu`, `_dev_menu`, `_notifications` and leave `lib/jumpstart` pristine.

2. **Thin app shell composing DS pieces, NOT a forced `NavbarComponent`.** The DS
   `NavbarComponent` is a centered marketing nav with hover mega-menu viewports;
   the app chrome is a full-width top bar (logo left, avatar/notifications/menus
   right). Those are different shapes. We build the top-bar layout with semantic
   HTML + design tokens and pull in DS components only for the pieces that genuinely
   fit: `AvatarComponent`, `DropdownComponent`, `AlertComponent`.

3. **Adopt Rails Blocks `DropdownComponent`; drop Jumpstart's `dropdown`
   controller.** User, account, and dev menus become `DropdownComponent`.
   Notifications: the dropdown *wrapper* becomes `DropdownComponent`, but the
   turbo-frame lazy-load + `notifications` Stimulus controller + unread badge are
   product logic and are preserved, just re-housed.

4. **Theme: preserve plumbing only.** Keep `data-controller="theme"` on `<body>` and
   `theme_controller.js` as-is. There is **no theme-toggle UI today** and we are not
   adding one now — so the ticket's "theme toggle works" system test is dropped
   (nothing to click).

5. **Surgical CSS trim, not file deletion.** `top_nav.css` / `nav.css` mix
   shell-only rules with rules for out-of-scope surfaces. After the rebuild, delete
   ONLY the rules that become orphaned; keep the rest. See Data Model table below.

6. **Mobile menu**: keep a small `toggle`-style disclosure (show/hide the mobile
   nav), token-styled. The catalog has no mobile-drawer component, and
   `NavbarComponent`'s mobile model is the hover-viewport approach we're avoiding.

### Standing hygiene (carried from COV-12)
Self-host assets (no CDN `<head>` links — Inter's existing CDN link is a known
pre-existing exception, deferred to a later ticket). Lazy-register Stimulus. Route
primary accents through tokens (`bg-primary` / `text-primary-foreground`). Never
`--force` over a Jumpstart controller without approval.

## Acceptance Criteria
- Every shell behavior below still works (system tests + browser at multiple widths,
  light + dark): logo→root, pricing link (signed-out), log in / sign up (signed-out),
  account switcher, user menu, notifications, dev menu (dev-only), flash banners +
  toasts, mobile menu toggle, footer links.
- Chrome uses our components + palette; no **orphaned** Jumpstart shell CSS remains.
- `bin/rails test` and `bin/rails test:system` pass (output shown).
- Devise, billing, and the Hotwire Native / `minimal` / `sidebar` surfaces are NOT
  touched.
- `/update-catalog` run if any component changed. One PR on
  `feature/cov-13-replace-app-shell`.

## Prototype
None. Visual design = the existing Jumpstart top-bar information architecture,
restyled onto DS components + tokens. Layout/IA is preserved, not redesigned.

## Data Model
No database models. The "model" here is the **behavior inventory** (must be
preserved) and the **CSS trim boundary**.

### Shell behavior inventory (source: engine partials, to be shadowed)
| Element | Current impl | Behavior to preserve |
| --- | --- | --- |
| Navbar shell | `.top-nav` flex bar + `toggle` controller | logo→`root_path`, mobile hamburger |
| `_left_nav` | app-overridden | pricing link (signed-out); account switcher (signed-in, team + other accounts) |
| `_right_nav` | app-overridden | log in / sign up buttons (signed-out) |
| `_account_menu` | `dropdown` controller | switch account (`switch_account_button` + `accounts` controller reconnect), manage accounts |
| `_user_menu` | `dropdown` controller | profile, password, connected accounts, billing, accounts, admin (if admin), sign out |
| `_notifications` | `dropdown` + `notifications` controller + turbo-frame lazy-load + badge | unread counts, mark-read on open, lazy list |
| `_dev_menu` | `dropdown` controller | dev-only (config, docs, mailbin) |
| `_flash` | `banner` helper + `ToastComponent` | alert/notice banners, toasts |
| `_footer` | plain HTML | mark→root, copyright, announcements/about/privacy/terms |

### CSS trim boundary (surgical)
| Rules | Consumer | Action |
| --- | --- | --- |
| `.top-nav` core, `.nav-container`, `.nav-user-controls`, `#sidebar-open`, `.top-nav__sub-nav*`, `section nav a/form button` | app `_navbar` (rebuilt) | **delete (orphaned)** |
| `.dropdown-menu`, `nav.menu-component`, `.account-menu`, `button[aria-label="Notifications"]` | 4 menus → `DropdownComponent` | **delete (orphaned)** |
| `.top-nav.native` | `_navbar.html+native.erb` (Hotwire Native) | **keep** — out of scope |
| `.minimal-top-nav` | `minimal` layout (billing checkout, agreements) | **keep** — out of scope |
| `.sidebar`, `.vertical-nav`, `.left-nav__sub-nav` | Jumpstart dev-only docs page | **keep** — out of scope |

Note: `.top-nav` base is shared with native/minimal/docs, so it stays; only the
shell-specific top-bar/menu rules are removed. Full deletion of `top_nav.css` /
`nav.css` is a separate later ticket once native + minimal + sidebar + docs are
also migrated off them.

## Screens / Flows
No new user-facing flows. Verification surfaces:
- The app shell rendered signed-out (logo, pricing, log in / sign up) and signed-in
  (account switcher, user menu, notifications, dev menu, mobile menu), at multiple
  widths, light + dark.
- Capybara system tests: nav renders, user menu opens, account switch works, flash
  shows, mobile menu opens.

## Scope
**In:** app-level rebuild of `_navbar`, `_flash`, `_footer`, `_account_menu`,
`_user_menu`, `_dev_menu`, `_notifications` (+ verify `_head`/`_left_nav`/
`_right_nav` still fit); surgical CSS trim; system tests; `/update-catalog` if a
component changes.

**Out:**
- Hotwire Native navbar variant (`_navbar.html+native.erb`), `_account_navbar`.
- `minimal` and `sidebar` layouts.
- Devise and billing views.
- Adding a theme-toggle UI (plumbing preserved only).
- Inter self-hosting (deferred to a later ticket).
- Full deletion of `top_nav.css` / `nav.css` (later ticket).

## Open Questions
None outstanding — all brainstorm decisions resolved (approach 2b, adopt RB
dropdowns, preserve theme plumbing, surgical CSS trim, keep `toggle` mobile menu,
scope boundary confirmed).

## More Info
- **DS components used:** `AvatarComponent`, `DropdownComponent`, `AlertComponent`
  (all from COV-12 catalog; see `docs/COMPONENT_CATALOG.md`).
- **Preserve these Jumpstart behaviors/controllers:** `notifications`, `accounts`,
  `theme`, `toggle`, plus the `banner` helper and `ToastComponent` for flash.
- **Environment:** Tailwind v4 CSS-first via `@theme` (never create
  `tailwind.config.js`); tokens in `app/assets/tailwind/theme/_tokens.css`; JS via
  importmap (no Node); Stimulus registered in `app/javascript/controllers/index.js`.
- If a needed base component is missing from the catalog, install on demand via the
  `rails-blocks-cli` skill (dry-run first, never `--force`), or STOP and ask if it's
  not in Rails Blocks — don't hand-build.
