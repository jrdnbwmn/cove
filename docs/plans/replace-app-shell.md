> Ticket: COV-13
> Branch: feature/cov-13-replace-app-shell

# Plan: Rebuild the app shell with design-system components

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | App-level `_navbar` + `_left_nav`/`_right_nav` restyle + system-test skeleton | Master | ✅ |
| 2 | `_account_menu` → `DropdownComponent` | Clone | ✅ |
| 3 | `_user_menu` → `DropdownComponent` | Clone | ✅ |
| 4 | `_dev_menu` → `DropdownComponent` | Clone | ✅ |
| 5 | `_notifications` → `DropdownComponent` (preserve turbo-frame + badge) | Master | ✅ |
| 6 | `_flash` → `AlertComponent` banners (keep toasts) | Master | ✅ |
| 7 | `_footer` app-level restyle with tokens | Clone | ✅ |
| 8 | Surgical CSS trim of `top_nav.css` / `nav.css` | Master | ✅ |
| 9 | Full verification: tests, browser widths/themes, `/update-catalog` | Master | ✅ |

## Prerequisites

- Design: `docs/designs/replace-app-shell.md`
- Prototype: None (IA = existing Jumpstart top bar, restyled onto DS components + tokens)
- Feature branch `feature/cov-13-replace-app-shell` already exists (Conductor workspace)
- No missing components — `AvatarComponent`, `DropdownComponent`, `AlertComponent`, `ButtonComponent` all exist in the catalog. No `/create-component` needed.

## Key facts for all tasks

- **Shadow, don't edit the engine.** Create app-level partials under `app/views/application/`. Never touch `lib/jumpstart/app/views/application/`. App views win over engine views.
- **Keep `dropdown` registered.** The `dropdown` Stimulus controller (from `tailwindcss-stimulus-components`, registered in `app/javascript/controllers/index.js`) is still used by the out-of-scope Jumpstart docs page (`lib/jumpstart/.../jumpstart/docs/navigation.html.erb`). Do **not** unregister it. We just stop using it in the four shell menus.
- **Keep `toggle` registered** (mobile menu + out-of-scope surfaces use it).
- **Tokens:** primary accents via `bg-primary` / `text-primary-foreground`; Tailwind v4 `@theme`, no `tailwind.config.js`. Preserve `data-controller="theme"` on `<body>` and `theme_controller.js` untouched.
- **Preserve helpers:** `render_svg`, `nav_link_to`, `account_avatar`, `avatar_url_for`, `switch_account_button`, `banner`, `toasts` (all in `lib/jumpstart/app/helpers/`).

## Tasks

### Task 1 [Master]: App `_navbar` shell + left/right nav restyle + test skeleton

**Skills:** write-tests, style-ui
**Reference:** `lib/jumpstart/app/views/application/_navbar.html.erb` (behavior to preserve), existing app shadows `app/views/application/_left_nav.html.erb` / `_right_nav.html.erb`, `app/components/button_component.rb`

**In scope:**

- **Write test first:** create `test/system/app_shell_system_test.rb` asserting every shell behavior (signed-out: logo→`root_path`, pricing link, log in / sign up; signed-in: account switcher opens + switches, user menu opens, notifications opens, dev menu present in dev, flash banner shows, mobile menu toggle shows/hides nav; footer links). Menu-specific assertions will stay RED until Tasks 2–7 — that's expected. Follow patterns in `test/system/account_system_test.rb` and `login_system_test.rb` (use `switch_account` / sign-in helpers already used there).
- Create app-level `app/views/application/_navbar.html.erb`: full-width top bar (logo left, toggleable nav-container, user-controls right) built with semantic HTML + design tokens. **Keep `data-controller="toggle"` and the `toggle-target="toggleable"` hamburger** exactly as the mobile disclosure. Render `left_nav`, `right_nav`, `dev_menu` (dev only), `notifications` + `user_menu` (signed-in) — same conditionals as the engine partial.
- Update `app/views/application/_left_nav.html.erb`: pricing `nav_link_to` restyled with tokens (its old styling came from soon-to-be-deleted `section nav a` rules).
- Update `app/views/application/_right_nav.html.erb`: log in / sign up → `ButtonComponent` (`:secondary` / `:primary`), replacing the `.btn-container` markup whose CSS is being trimmed.

**NOT in scope:**

- The four menu partials (Tasks 2–5), flash/footer (6–7), CSS deletion (8).
- Hotwire Native / minimal / sidebar variants.

**Build order:**

1. **Test:** `test/system/app_shell_system_test.rb` — full behavior suite (red where menus not yet built).
2. **Implement:** app `_navbar.html.erb`, update `_left_nav`, `_right_nav`.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb` — logo/pricing/login/signup/mobile-toggle cases green.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 2 [Clone]: `_account_menu` → DropdownComponent

**Skills:** style-ui
**Reference:** `lib/jumpstart/.../_account_menu.html.erb` (behavior), `app/components/dropdown_component.rb` + `docs/COMPONENT_CATALOG.md` DropdownComponent section, `AvatarComponent`

**In scope:**

- Create `app/views/application/_account_menu.html.erb` using `DropdownComponent` (`placement: "bottom-start"`).
- Custom trigger (`with_trigger`): `account_avatar current_account` + truncated account name (replaces `.account-menu` CSS with token classes).
- Items: one `with_item_custom` per `Current.other_accounts` wrapping `switch_account_button account, data: { controller: :accounts, action: "ajax:success->accounts#reconnect" }` (preserve the `accounts` controller reconnect exactly); a divider; a `with_item_link` to `accounts_path` ("manage accounts") with the people icon.

**NOT in scope:** other menus; the `dropdown` controller registration; changing `switch_account_button` / `accounts` controller.

**Build order:**

1. **Test:** account-switcher cases already in `app_shell_system_test.rb` (Task 1) — this task turns them green. Do not edit the test file.
2. **Implement:** `app/views/application/_account_menu.html.erb`.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb -n /account/`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 3 [Clone]: `_user_menu` → DropdownComponent

**Skills:** style-ui
**Reference:** `lib/jumpstart/.../_user_menu.html.erb`, DropdownComponent catalog section

**In scope:**

- Create `app/views/application/_user_menu.html.erb` using `DropdownComponent` (`placement: "bottom-end"`).
- Icon/avatar trigger: `image_tag avatar_url_for(current_user)` (rounded avatar) via `with_trigger`.
- Items preserving every conditional: profile, password, connected accounts (`if Devise.omniauth_configs.any?`), billing (`if payments_enabled?`), accounts (`if team_accounts?`); divider + admin link (`if current_user.admin?`, `target: :_blank`, `data: { turbo: false }`); divider + sign out as `with_item_button` submitting `button_to destroy_user_session_path, method: :delete` (use `with_item_custom` if `button_to` markup doesn't fit the button slot).

**NOT in scope:** other menus; auth logic.

**Build order:**

1. **Test:** user-menu cases in `app_shell_system_test.rb` (from Task 1).
2. **Implement:** `app/views/application/_user_menu.html.erb`.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb -n /user_menu/`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 4 [Clone]: `_dev_menu` → DropdownComponent

**Skills:** style-ui
**Reference:** `lib/jumpstart/.../_dev_menu.html.erb`, DropdownComponent catalog section

**In scope:**

- Create `app/views/application/_dev_menu.html.erb` using `DropdownComponent`.
- Custom trigger: Jumpstart logo SVG button (keep the `tooltip` controller + `aria-label="Dev Menu"`).
- Label "Jumpstart" (`with_item_label`) + links: Configuration (`jumpstart_path(script_name: nil)`), Documentation (`jumpstart.docs_path`, `target: :_blank`), Mailbin (`mailbin_path(script_name: nil)`, `target: :_blank`) — all `data: { turbo: false }`.
- Preserve "hidden on mobile" behavior with a token utility class (old rule was `.dropdown-menu:has([aria-label="Dev Menu"]) { display:none; @lg: flex }`).

**NOT in scope:** other menus; the render guard (`if Rails.env.development?` stays in `_navbar`, Task 1).

**Build order:**

1. **Test:** dev-menu case in `app_shell_system_test.rb` (dev env).
2. **Implement:** `app/views/application/_dev_menu.html.erb`.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb -n /dev_menu/`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 5 [Master]: `_notifications` → DropdownComponent (preserve product logic)

**Skills:** style-ui
**Reference:** `lib/jumpstart/.../_notifications.html.erb`, `app/javascript/controllers/notifications_controller.js`, DropdownComponent catalog section

**In scope:**

- Create `app/views/application/_notifications.html.erb`. Keep the **outer `data-controller="notifications"` div** with its `notifications_account_id_value` / `_account_unread_value` / `_total_unread_value` data exactly.
- Replace only the `dropdown`-controller wrapper with `DropdownComponent` (`placement: "bottom-end"`, wider `width:` e.g. `w-96`).
- Custom trigger (`with_trigger`) = a button that is itself the popover target (include `data-ui-dropdown-popover-target="button"` so the component passes it through untouched) carrying **both** `click->notifications#open` and `click->ui-dropdown-popover#toggle`; contains the bell SVG + the unread `badge` span (`data-notifications-target="badge"`).
- Menu body via `with_item_custom(unstyled: true)` holding the existing `turbo_frame_tag "notifications", loading: :lazy, src: nav_notifications_path, data: { notifications_target: "list" }` — preserve lazy-load + mark-read-on-open.

**NOT in scope:** changing `notifications_controller.js`, `nav_notifications_path`, or the badge logic.

**Build order:**

1. **Test:** notifications-open case in `app_shell_system_test.rb`.
2. **Implement:** `app/views/application/_notifications.html.erb`.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb -n /notification/`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 6 [Master]: `_flash` → AlertComponent banners (keep toasts)

**Skills:** style-ui
**Reference:** `lib/jumpstart/.../_flash.html.erb`, `app/components/alert_component.rb`, `ToastComponent`
**Decision (confirmed):** banners move to `AlertComponent`; toasts stay on `ToastComponent`.

**In scope:**

- Create `app/views/application/_flash.html.erb`. Keep `#flash` (`data-turbo-temporary`) and `#toasts` wrappers.
- Alert → `AlertComponent.new(title: alert, variant: :warning)`; notice → `variant: :info` — rendered only when present.
- Keep the `toasts.each` loop rendering `ToastComponent` unchanged.

**NOT in scope:** changing the toast pipeline, `banner` helper definition (left available for other callers), impersonation banner.

**Build order:**

1. **Test:** flash-shows case in `app_shell_system_test.rb`; assert `AlertComponent` markup renders for a flashed message.
2. **Implement:** `app/views/application/_flash.html.erb`.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb -n /flash/`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 7 [Clone]: `_footer` app-level restyle with tokens

**Skills:** style-ui
**Reference:** `lib/jumpstart/.../_footer.html.erb`

**In scope:**

- Create `app/views/application/_footer.html.erb`: same IA (mark→`root_path`, copyright, announcements/about/privacy/terms links) restyled with design tokens. Preserve all `t(".…")` keys and routes.

**NOT in scope:** changing footer routes/content; new links.

**Build order:**

1. **Test:** footer-links case in `app_shell_system_test.rb`.
2. **Implement:** `app/views/application/_footer.html.erb`.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb -n /footer/`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 8 [Master]: Surgical CSS trim

**Skills:** style-ui
**Reference:** design "CSS trim boundary" table; `app/assets/tailwind/components/top_nav.css`, `nav.css`

**In scope — delete ONLY rules confirmed orphaned by the implementation audit:**

- `top_nav.css`: `.top-nav__sub-nav*`, `.dropdown-menu`, and `.account-menu`.
- `nav.css`: only the `nav.menu-component.notifications` modifier.
- **Keep:** `.top-nav` base, `.top-nav.native`, `.minimal-top-nav`, `.nav-container`, `.nav-user-controls`, `#sidebar-open`, `section nav a` / `section nav form button`, `button[aria-label="Notifications"]`, and the main `nav.menu-component` rule because Hotwire Native and/or the vendored docs navigation examples still use them; also keep `.sidebar`, `.vertical-nav`, and `.left-nav__sub-nav`.

**NOT in scope:** deleting either file entirely (later ticket); touching native/minimal/sidebar/docs rules.

**Build order:**

1. **Test:** re-run full `app_shell_system_test.rb` after each deletion chunk to catch a rule that was still load-bearing.
2. **Implement:** delete orphaned rules only; grep the class in `app/`/`lib/` before removing to confirm it's shell-only.
3. **Verify:** `bin/rails test:system TEST=test/system/app_shell_system_test.rb`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 9 [Master]: Full verification + catalog

**Skills:** verify

**In scope:**

- `bin/rails test` and `bin/rails test:system` — full suites, show output.
- Browser check via `/run`: shell signed-out and signed-in at mobile + desktop widths, light + dark. Confirm every behavior in the acceptance list.
- If any component in `app/components/` changed (expected: none — we compose, not modify), run `/update-catalog`. If nothing changed, state that and skip.
- Confirm Devise, billing, Hotwire Native / minimal / sidebar surfaces untouched (`git diff --stat`).

**NOT in scope:** opening the PR (that's `/close-out` later).

**Build order:**

1. **Verify:** `bin/rails test` + `bin/rails test:system` (show output); browser sweep.
2. **Catalog:** `/update-catalog` only if a component file changed.
3. **Review:** final review-changes.

## Task Dependencies

- Task 1 first — it writes the shared system test and the navbar that renders every other partial; sets patterns.
- Tasks 2, 3, 4, 7 can run in parallel after Task 1 (independent partials, no shared files; each turns its own already-written test case green).
- Task 5 (notifications) and Task 6 (flash) are Master (product logic / decision) — do after or alongside the clone batch.
- Task 8 (CSS trim) must come after Tasks 1–7 (needs the new markup in place so deletions are truly orphaned).
- Task 9 last (full verification + catalog).

## Phasing

- **Phase 1 — Shell + menus (Tasks 1–5):** independently deployable; old `_flash`/`_footer` engine partials and legacy CSS coexist harmlessly.
- **Phase 2 — Flash, footer, CSS trim, verify (Tasks 6–9):** polish + cleanup.
