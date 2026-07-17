> Ticket: COV-14
> Branch: jrdnbwmn/cov-14-rebuild-auth-devise-views

# Feature: Rebuild auth (Devise) views with design-system components

## Problem
Jumpstart's authentication views (sign in, sign up, password reset, confirmation,
unlock, 2FA, edit registration) still use hand-rolled Jumpstart markup and the
`form-control` / `btn` CSS classes. Now that COV-12 shipped a curated Rails Blocks
component library and COV-13 rebuilt the app shell on it, the auth surfaces should
be rebuilt on the same component vocabulary + design tokens. This is a **visual
replacement, not a behavior change** — every field name, param, route, Devise
wiring, flash, and validation path is preserved exactly.

## Approach
**Copy the Devise views out of the vendored engine into the app, then rebuild them
there.** The auth views are currently served from the in-repo Jumpstart engine
(`lib/jumpstart/app/views/devise/`). Rails app views win over engine views (the
same override pattern COV-13 used for the shell), so step one is to copy each view
into `app/views/devise/` and rebuild it against components, leaving `lib/jumpstart`
pristine.

Because the view paths stay `devise/...`, **i18n lazy lookup (`t('.sign_in')`) is
unchanged** — zero locale edits.

### Key decisions (locked in brainstorm)

1. **Override in `app/views/devise/`, don't edit the engine.** Copy then rebuild;
   `lib/jumpstart` stays untouched.

2. **Components wrap raw Devise controls via slots.** `FormFieldComponent` supplies
   a label/helper/error shell around a raw `<input>`/`<select>` passed through its
   `with_input` slot — so every Devise field helper (`f.email_field`, `f.file_field`,
   `f.select`, `placeholder: true`, `autocomplete:`, `invisible_captcha`) survives
   verbatim. Field names/params never change.

3. **Password fields → `PasswordComponent`.** Generates its own input from
   `name:`/`autocomplete:` (params preserved) and adds a client-only show/hide
   toggle. "Zero change to auth behavior" refers to the auth *logic*, which is
   untouched; the toggle is a small UX addition (approved).

4. **Submit buttons → `ButtonComponent` (`type: "submit"`).** This renders a
   `<button>`, not Rails' `<input name="commit">`, so the 3 `input[name="commit"]`
   selectors in `login_system_test.rb` (login form + otp submit) are updated to
   `button[type=submit]`.

5. **`edit registration` is IN scope.** It's a Devise registration view. Its *form*
   is rebuilt with components; its `_account_navbar` sidebar partial and the
   Hotwire Native `bridge--form` / `bridge--sign-out` controllers + `button_to`
   cancel-account action are preserved verbatim (the sidebar partial itself is not
   rebuilt — it just keeps rendering).

6. **Selects (`theme`, `preferred_language`) → `SelectComponent`.** It renders a
   real `select_tag @name, options_for_select(...)`, so submission is byte-identical
   (`name: "user[theme]"`, `selected:`, `options: theme_options`). It's a
   JS-enhanced dropdown (`data-controller="select"`) — a visual upgrade. Two
   handled caveats: suppress its auto-inserted blank option so the option set is
   unchanged; ensure the `select` Stimulus controller is registered (should already
   be from COV-12 — verify).

7. **Errors render two ways (both).** The `application/_error_messages` summary
   partial is rebuilt as `AlertComponent variant:error` for base/whole-record
   errors; per-attribute errors are wired into each `FormField`/`Password`/`Select`
   via `error: resource.errors[:attr].first` (nil-safe when clean).

### Standing hygiene (carried from COV-12/COV-13)
Self-host assets (no CDN `<head>` links). Lazy-register Stimulus (only controllers
whose components are used: `password`, `select`). Route primary accents through
tokens (`bg-primary` / `text-primary-foreground`). Never `--force` over a Jumpstart
controller without approval. Tailwind v4 CSS-first via `@theme` — never create
`tailwind.config.js`. Use `# AIDEV-NOTE:` for non-obvious decisions.

## Acceptance Criteria
- All auth flows work unchanged (tests + browser): sign up, sign in, wrong password
  shows error, password reset, confirmation, unlock, 2FA otp.
- Validation errors render through our components (summary `AlertComponent` +
  per-field `error:`).
- Views use the palette / design tokens; no `form-control`/`btn` Jumpstart classes
  remain in the rebuilt views.
- `bin/rails test` and `bin/rails test:system` pass (output shown).
- Billing/account views are NOT touched (except the in-scope `registrations/edit`
  form). One PR on `jrdnbwmn/cov-14-rebuild-auth-devise-views`.

## Prototype
None. Visual design = the existing Jumpstart auth layout/IA, restyled onto DS
components + tokens. Layout is preserved, not redesigned.

## Data Model
No database models, migrations, routes, or controller changes. The "model" here is
the **field/param inventory** that must be preserved exactly (email, password,
password_confirmation, name, remember_me, terms_of_service, avatar,
preferred_language, theme, otp_attempt, reset_password_token, invisible_captcha
honeypot) plus every `devise_mapping.*` / `hotwire_native_app?` conditional.

## Screens / Flows
No new flows; same fields, params, redirects. Component mapping:

| View | Fields → components | Submit | Preserved verbatim |
| --- | --- | --- | --- |
| `sessions/new` | email → `FormFieldComponent`(`f.email_field`); password → `PasswordComponent`; remember_me → `CheckboxComponent` | `ButtonComponent` | `hotwire_native_app?` hidden branch, `rememberable?` guard, `_links` |
| `sessions/otp` | otp_attempt → `FormFieldComponent`(`f.text_field`, `inputmode:numeric`, `autocomplete:one-time-code`) | `ButtonComponent` | `users.two_factor.*` i18n |
| `registrations/new` | name/email → `FormFieldComponent`; password → `PasswordComponent` (+ `@minimum_password_length` hint); terms_of_service → `CheckboxComponent` (HTML label w/ terms+privacy links) | `ButtonComponent` (`button_text`/`disable_with`) | `invisible_captcha`, commented owned_accounts block, `@account_invitation` → `AlertComponent info` |
| `registrations/edit` | avatar → `FormFieldComponent`(`f.file_field`); name/email → `FormFieldComponent`; preferred_language/theme → `SelectComponent` | `ButtonComponent` (`bridge--form-target:submit`) | `bridge--form`, `pending_reconfirmation?` → `AlertComponent warning`, cancel-account `button_to`+`bridge--sign-out` (destructive DS classes), `_account_navbar` sidebar untouched |
| `passwords/new` | email → `FormFieldComponent` | `ButtonComponent` | `_links` |
| `passwords/edit` | reset_password_token hidden (raw); password/password_confirmation → `PasswordComponent` | `ButtonComponent` | `@minimum_password_length` hint |
| `confirmations/new` | email → `FormFieldComponent` (reconfirmation prefill) | `ButtonComponent` | `_links` |
| `unlocks/new` | email → `FormFieldComponent` | `ButtonComponent` | `_links` |
| `shared/_links` | omniauth providers → `button_to` + secondary DS classes | — | all `devise_mapping.*` conditionals |
| `application/_error_messages` | → `AlertComponent variant:error` (title = N-errors, `full_messages` list) | — | per-field errors also wired into each field's `error:` |

### Edge cases
- **Failed registration w/ empty params** (`post … params: {}`, existing test):
  components render with `nil` values; User not created.
- **Invalid/expired reset token** (`passwords/edit`): hidden `reset_password_token`
  kept; Devise `:reset_password_token` error shown in the summary alert.
- **Checkbox hidden-field nuance:** `CheckboxComponent` emits no companion hidden
  `"0"` field. For `terms_of_service` (required) and `remember_me`, an absent param
  == unchecked/false, so behavior is unchanged.
- **Omniauth disabled** (`omniauth_providers: []`): `omniauthable?` guard preserved
  → nothing renders, no stray "or" divider.
- **2FA:** incorrect-code flash stays controller-driven; login/otp system tests
  updated for `button[type=submit]`, five 2FA tests stay green.

### Testing
- **Request/integration:** sign-up success + failure (exists — verify/extend),
  sign-in success + wrong-password error, password-reset request + token reset;
  confirmation/unlock smoke.
- **System:** sign-in happy path + one error state (adapt existing
  `login_system_test` selectors; keep 2FA green).
- **Browser:** verify light/dark + mobile.
- `bin/rails test` + `bin/rails test:system` output shown.

## Scope
**In:** copy + rebuild all `app/views/devise/` views (`sessions/new`,
`sessions/otp`, `registrations/new`, `registrations/edit`, `passwords/new`,
`passwords/edit`, `confirmations/new`, `unlocks/new`, `shared/_links`) and the
`application/_error_messages` summary partial; wire per-field + summary errors
through our components; request + system tests; `/update-catalog` only if a
component changes.

**Deferred / Out:**
- The `_account_navbar` sidebar partial itself (kept rendering, not rebuilt).
- Any billing/account/subscription views.
- Devise mailer views (`devise/mailer/*` — not user-facing auth screens).
- Controller/model/route/i18n changes.
- Adding new component features (reuse the catalog as-is; no new installs expected).

## Open Questions
None — all brainstorm decisions resolved (edit-registration in, `ButtonComponent`
+ selector updates, `PasswordComponent` toggle, `SelectComponent` for selects,
both error layers).

## More Info
- **DS components used:** `FormFieldComponent`, `PasswordComponent`,
  `ButtonComponent`, `CheckboxComponent`, `SelectComponent`, `AlertComponent` (all
  from COV-12 catalog; see `docs/COMPONENT_CATALOG.md`).
- **Stimulus controllers relied on (lazy-registered):** `password`, `select` — plus
  preserved `bridge--form`, `bridge--sign-out` on edit-registration.
- **Preserve verbatim:** every field name/param, `invisible_captcha`,
  `devise_mapping.*` guards, `hotwire_native_app?` branch, CSRF/form structure,
  Devise's `error_messages` data (`resource.errors`).
- **Environment:** run Rails/bin commands via `mise exec --`; Tailwind v4 CSS-first
  via `@theme` (never create `tailwind.config.js`); JS via importmap (no Node);
  Stimulus registered in `app/javascript/controllers/index.js`.
- If a needed base component turns out missing, install on demand via the
  `rails-blocks-cli` skill (dry-run first, never `--force`), or STOP and ask.
