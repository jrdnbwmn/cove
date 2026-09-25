> Plan created: docs/plans/cov-84-finalized-shell-and-navigation.md

> Ticket: COV-84
> Branch: feature/cov-84-finalized-shell-and-navigation

# Feature: Finalized signed-in shell and sidebar navigation

## Problem
The signed-in app still uses the COV-13 top bar (logo, notifications bell, avatar
menu, footer), which has no home for the product's core areas (schedules,
subjects, students). Parents need a persistent, app-like navigation that makes
those areas one click away and gathers account pages in one predictable place.

## Approach
Replace the signed-in chrome with a left sidebar built on the Rails Blocks
`SidebarComponent`, next to an inset white content panel. Signed-out pages keep
the current top bar + footer. **Rails Blocks components are used wherever
possible**; the two gaps are closed by extending existing Rails Blocks
components, not by hand-building new UI:

1. **`SidebarComponent`** — add a new variant (e.g. `:inset`) that uses the
   page background token (`bg-background`, the tan body background) with no
   border. Existing variants unchanged. Nothing in production uses the sidebar
   yet (only kitchen sink + previews).
2. **`UiTabsComponent`** — add a link-tabs mode where each tab is an `<a href>`
   to its own page (no panels, no JS switching), reusing the component's
   existing tab styles. Rails Blocks tabs are panel-only; there is no
   navigation-tabs variant (confirmed via `rails-blocks docs tabs`).

Shell partials are app-level overrides of vendored Jumpstart views (same pattern
as COV-13); `lib/jumpstart` stays pristine.

## Acceptance Criteria
- Every signed-in page using the application layout renders the sidebar shell;
  signed-out pages render the existing top bar + footer unchanged.
- Sidebar shows: Cove wordmark → Home; Home, Schedules, Subjects, Students,
  Admin (superadmin only) with icons; Support, Settings, and the account button
  at the bottom.
- Account button opens a menu with Profile, Password, Connected accounts*,
  Billing*, Family, dev-only Jumpstart links, Sign out, and Privacy / Terms.
- Sidebar collapses to icons (with tooltips) on desktop and remembers the
  choice; on mobile it is a drawer opened by a menu button.
- Correct item is highlighted on every page (see Highlight rules).
- Settings pages show horizontal link tabs instead of the left sub-nav.
- No flash message pushes page content down: flashes appear as bottom-right
  toasts (errors stay until closed), except Devise auth pages, which show them
  as a banner inside the form card.
- A superadmin impersonating a user sees the impersonation card in the expanded
  sidebar, a ringed avatar when collapsed, and a dot on the mobile menu button;
  Stop ends impersonation as today.
- `/schedules`, `/subjects`, `/students` exist, require sign-in, and show a
  "Coming soon" empty state.
- Notifications bell, top bar, and footer no longer appear when signed in.
- Account menu works in expanded, collapsed, and mobile-drawer states; collapsed
  state doesn't flash expanded across Turbo navigations.
- Key pages (Dashboard, settings pages, Billing, Family, Pricing) look correct at
  mobile, tablet, and desktop widths.
- Tests written first; `bin/rails test` and `bin/rails test:system` pass;
  `/update-catalog` run for the two component changes.

\* only when the feature is enabled, as today.

## Prototype
Screenshot reference: `.context/attachments/Z1DG4w/original-3b79913c7fcab11e97b641433dd794a3.webp`
(Untitled UI settings page). Only these elements are pulled from it:
- Left sidebar with logo at top, flat icon+label nav list (no group headings).
- Bottom stack: Support (with external-link icon on the right), Settings, then a
  bordered account card (avatar, name, email, up/down chevron).
- Content in a white rounded panel inset from the background.
- Settings sub-pages as horizontal tabs across the top of the page.

Not pulled: the workspace switcher chevron next to the logo, section headings,
the ⋯ page menu, and the page content itself. Colors/typography follow Cove's
brand tokens, not the screenshot.

## Data Model
No database changes — no migrations, models, or columns.

Shell reads existing data only:
| Piece | Source |
|---|---|
| Account button | `current_user.name`, `.email`, `avatar_url_for(current_user)` |
| Admin item | `current_user.admin?` (superadmin) |
| Connected accounts link | `Devise.omniauth_configs.any?` |
| Billing link | `Jumpstart.config.payments_enabled?` |
| Family link | `account_path(current_account)` |
| Collapsed state | browser localStorage (component `storage_key`) |

New routes/controllers (placeholder pages):
- `resources :schedules, only: :index`, `resources :subjects, only: :index`,
  `resources :students, only: :index` → `SchedulesController`,
  `SubjectsController`, `StudentsController`, each `index` only, behind
  `authenticate_user!`. Resourceful so the real features slot in later without
  renames. No Pundit/account scoping yet — there's no data on them.

## Screens / Flows

### Sidebar (`SidebarComponent`, new inset variant, `collapsible: true`)
- **Logo slot:** `application/_brand` (Cove wordmark `logo.svg`) linked to
  `root_path`.
- **Items** (`with_item`, Lucide `icon`, caller-computed `active:`):
  | Label | Icon | Target |
  |---|---|---|
  | Home | `house` | dashboard (authenticated root) |
  | Schedules | `calendar` | `schedules_path` |
  | Subjects | `book-open` | `subjects_path` |
  | Students | `users` | `students_path` |
  | Admin (superadmin only) | `shield` | `madmin_root_path`, **same tab** |
- **Footer slot** (expanded), top to bottom:
  - **Support** — `life-buoy` icon, `external-link` icon on the right,
    `mailto:support@covehomeschool.com`, `title` shows the address.
  - **Settings** — `settings` icon → Profile (`edit_user_registration_path`).
  - **Account button** — full-width bordered card: `AvatarComponent`, name with
    email beneath (email only if no name), `chevrons-up-down` icon; long text
    truncates with full value in `title`.
- **Collapsed footer slot:** icon-only Support and Settings (tooltips) and
  avatar-only account button that still opens the same menu.
- **Mobile:** component's built-in drawer + `show_mobile_toggle` menu button.

### Account menu (`DropdownComponent`, opens upward, e.g. `top-start`)
1. Profile, Password, Connected accounts*, Billing*, Family
2. Dev-only (`Rails.env.development?`): Jumpstart Configuration, Documentation,
   Mailbin (moved from `_dev_menu`)
3. Divider, Sign out (`button_to … method: :delete`)
4. Divider, Privacy and Terms as smaller muted links

Admin is removed from this menu (it's in the sidebar now). API tokens is not in
the menu (still a settings tab).

### Layout
- `layouts/application`: signed in (and not Hotwire Native) → sidebar + inset
  white rounded content panel (scrolls independently) on the tan background;
  signed out → existing `_navbar` + `_footer`.
- No full-width banners push the layout down: flash messages become toasts (see
  Flash messages) and impersonation moves into the sidebar (see Impersonation).
- `UiToastComponent` host stays rendered exactly once, globally.
- Retired from the signed-in shell: `_user_menu`, `_notifications`, `_dev_menu`,
  footer.

### Settings tabs
- App-level override of `_account_navbar` renders `UiTabsComponent` in the new
  link-tabs mode: Profile, Password, Connected accounts*, Billing*, Family, API
  tokens (Referrals if `Refer` defined, as today).
- App-level override of `layouts/sidebar` (Jumpstart's settings layout —
  unrelated to the new nav despite the name) changes from left-column sub-nav to
  tabs on top, content below.
- Tab row scrolls horizontally on narrow screens.

### Flash messages (all layouts)
Today, string flashes (`notice`/`alert`, e.g. Devise's "Welcome! You have signed
up successfully.") render as a full-width `AlertComponent` banner that pushes the
page down; only hash flashes become toasts.
- **Change:** `application/_flash` sends **every** flash (string or hash) to the
  existing Rails Blocks toast (`UiToastComponent` via the `flash-toast`
  controller), bottom-right. No change to how controllers/Devise set flash.
- **Timing:** success/notice toasts auto-dismiss; error/alert toasts stay until
  the user closes them.
- **Exception — Devise auth pages** (signed-out, `minimal` layout): Log in,
  2FA code step (`sessions/otp`), Sign up, Forgot password, Reset password,
  Resend confirmation, Unlock. Flash renders as an `AlertComponent` **inside the
  form card**, not a toast (e.g. "Invalid email or password", "You will receive
  an email with instructions…" after a reset request). These pages must not
  also fire a toast for the same message.
- Other `minimal` pages (checkout, agreements, signup completion) use toasts.
- Unchanged: inline form validation errors (`_error_messages`).

### Impersonation (superadmin only)
Replaces the full-width `impersonation_banner` in the application layout.
- **Expanded sidebar:** a warning-colored card in the footer, directly above the
  account button: "Viewing as {name}" (email in `title`), name links to the
  user in Madmin, plus a **Stop** button (same `madmin_user_impersonate_path`
  `DELETE` as today).
- **Collapsed sidebar:** the avatar in the collapsed footer gets a
  warning-colored ring and a tooltip "Viewing as {name}"; Stop is reachable by
  expanding the sidebar.
- **Mobile:** the mobile menu button gets a warning-colored dot; the card shows
  inside the drawer.
- **`minimal` layout** (checkout, agreements) has no sidebar, so it keeps the
  existing top `impersonation_banner`.
- Uses warning tokens (`yellow`/`orange` scale from `application.css` `@theme`),
  no hard-coded hex.

### Placeholder pages
Schedules, Subjects, Students: `h1` page title + `EmptyStateComponent` with the
page's icon, title "Coming soon", one-line description.

### Highlight rules
| Page(s) | Sidebar highlight | Tab highlight |
|---|---|---|
| Dashboard | Home | — |
| `/schedules`, `/subjects`, `/students` | matching item | — |
| Profile, Password (+ two-factor), Connected accounts, Billing (+ `/billing/*`), Family (`/accounts/*`, members, invitations, transfer), API tokens | Settings | matching tab |
| Pricing, accept-invitation page | none | — |

## Scope
**In:**
- Sidebar shell in the application layout for signed-in users.
- `SidebarComponent` inset variant; `UiTabsComponent` link-tabs mode (+ tests,
  previews, catalog).
- Account menu with dev links and Privacy/Terms.
- Settings link-tabs + settings layout override.
- Three placeholder pages with routes/controllers.
- All flash messages as toasts (errors persist, success auto-dismisses), except
  in-card banners on Devise auth pages.
- Impersonation indicator in the sidebar (expanded card, collapsed avatar ring,
  mobile button dot); `minimal` layout keeps the top banner.
- Update tests that reference the old top bar / user menu / bell / flash
  banner markup.

**Deferred / out:**
- Student, Subject, Schedule models and real pages (own tickets; Students has
  product rules for limits/read-only).
- Notifications UI (bell and `/notifications` page dropped from the shell).
- Announcements and About links in the signed-in app (dropped).
- Signed-out top bar/footer, `minimal` layout (checkout, agreements, signup
  completion), Hotwire Native navbar, Madmin, error pages — unchanged.
- No pricing link in the sidebar; signed-in pricing (reached from Billing) uses
  the sidebar layout with nothing highlighted.

## Open Questions
None. Risks to verify during implementation:
- Error toasts that persist must be announced to screen readers (check
  `ui_toast_controller.js` uses a live region) and not stack up across Turbo
  navigations.
- Collapsed sidebar flashing expanded on Turbo navigation — fix with
  `data-turbo-permanent` (or equivalent) if it occurs.
- The sidebar clones its content template into the mobile drawer, duplicating
  the account dropdown — verify no ID collisions and the menu works in desktop,
  collapsed, and mobile states.

## More Info
- Follow COV-13 conventions: override engine views in `app/views/...`, never
  edit `lib/jumpstart`.
- Icons via `rails_icons` + Lucide (`icon "house", class: "size-4"`); all listed
  icons verified present in `app/assets/svg/icons/lucide/`.
- `ButtonComponent`/`DropdownComponent` gotchas from AGENTS.md apply (use
  `with_item_custom` for non-Turbo or `button_to` items).
- Brand tokens: tan = `--background`; don't hard-code hex. Dark mode stays
  disabled.
- Accessibility: sidebar `nav` labeled primary; active item gets
  `aria-current="page"`; account button has an `aria-label`; dropdown keyboard
  support comes from Rails Blocks.
