> Ticket: COV-14
> Branch: jrdnbwmn/cov-14-rebuild-auth-devise-views

# Plan: Rebuild auth (Devise) views with design-system components

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Shared partials: `_error_messages` + `shared/_links` | Master | ✅ |
| 2 | `sessions/new` + `sessions/otp` + system-test selector updates (pattern-setter) | Master | ✅ |
| 3 | `passwords/new`, `confirmations/new`, `unlocks/new` (simple email forms) | Clone | ✅ |
| 4 | `passwords/edit` (hidden token + two PasswordComponents) | Clone | ✅ |
| 5 | `registrations/new` (name/email/password/terms/captcha) | Clone | ✅ |
| 6 | `registrations/edit` (avatar, selects, cancel-account, sidebar) | Master | |
| 7 | Add password-reset request test; full `test` + `test:system`; browser verify | Master | |

## Prerequisites

- Design: `docs/designs/rebuild-auth-devise-views.md`
- Prototype: None (visual design = existing Jumpstart auth layout, restyled onto DS components)
- Feature branch `jrdnbwmn/cov-14-rebuild-auth-devise-views` exists (current branch) ✓
- Components all exist in catalog (`FormFieldComponent`, `PasswordComponent`, `ButtonComponent`, `CheckboxComponent`, `SelectComponent`, `AlertComponent`) — no `/create-component` needed.

## Global rules for every task

- **Copy, don't edit the engine.** Create new files under `app/views/…`; leave `lib/jumpstart/…` pristine. App views win over engine views.
- **Environment:** run all Rails/bin commands via `mise exec --` (e.g. `mise exec -- bin/rails test …`).
- **Preserve verbatim:** every field name/param, `devise_mapping.*` guards, `hotwire_native_app?` branch, i18n lazy keys (`t('.foo')`), CSRF/form structure. View paths stay `devise/…` so i18n lookup is unchanged — **no locale edits**.
- **Field-wrapping pattern (the core recipe):**
  ```erb
  <%= render FormFieldComponent.new(label: resource.class.human_attribute_name(:email),
                                    name: "user[email]",
                                    error: resource.errors[:email].first) do |field| %>
    <% field.with_input do %>
      <%= f.email_field :email, autofocus: true, autocomplete: "email", placeholder: true, class: "form-control" %>
    <% end %>
  <% end %>
  ```
  Passing the raw `f.*_field` through `with_input` keeps ALL original options. `error:` is nil-safe when clean. Label text = whatever the original `f.label` produced: `resource.class.human_attribute_name(:attr)` for plain labels, or the explicit `t('...')` for the custom-labeled ones (`otp_attempt`, `new_password`, `confirm_new_password`).
- **Password fields → `PasswordComponent`** — it regenerates its own input, so map options explicitly: `name:` (e.g. `"user[password]"`), `autocomplete:` (`current-password` / `new-password`), `placeholder:`, `error:`. ⚠️ If a field had `autofocus: true` (passwords/edit) or `required: true`, check whether `PasswordComponent` exposes those args; if it doesn't, STOP and ask rather than dropping them.
- **Submit → `ButtonComponent.new(text:, type: "submit", …)`** — this renders `<button>`, not `<input name="commit">`. Map `btn-expanded` → `full_width: true` (omit for buttons that lacked it). Carry `disable_with` via `data: { disable_with: t('.submitting') }`.
- **Errors render two ways:** per-field via each component's `error:` AND the summary via the rebuilt `_error_messages` (Task 1). Keep both.
- Route accents through tokens (`bg-primary`/`text-primary-foreground`); no `form-control`/`btn` Jumpstart classes remain in rebuilt views. Use `# AIDEV-NOTE:` for non-obvious decisions.

## Tasks

### Task 1 [Master]: Shared partials — error summary + auth links

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/application/_error_messages.html.erb`, `lib/jumpstart/app/views/devise/shared/_links.html.erb`; catalog `AlertComponent`, `ButtonComponent`.

**In scope:**

- Create `app/views/application/_error_messages.html.erb`: when `resource.errors.any?`, render `AlertComponent.new(variant: :error, title: <the "not_saved" count string>)` with the `full_messages` list as the body/description. Keep `data-turbo-temporary` on the wrapper.
- Create `app/views/devise/shared/_links.html.erb`: omniauth providers → keep `button_to` (preserving `data: { turbo: false, disable_with: … }`) restyled with secondary DS classes; the recoverable/confirmable/lockable `link_to`s restyled to token link/muted classes. Preserve ALL `devise_mapping.*` / `controller_name` guards and the "or" divider exactly.

**NOT in scope:** any form view; the omniauth *logic*; adding/removing links.

**Caveats:** `_error_messages` is shared app-wide — this restyles every error summary (intended, visual-only, same messages). `AlertComponent` `description` is `html_safe`; the messages are developer-authored validation strings (safe), but pass the `full_messages` list as escaped `<li>`s in the body rather than concatenating raw HTML.

**Build order:**

1. **Implement:** the two partials above.
2. **Verify:** `mise exec -- bin/rails test test/controllers/users/registrations_controller_test.rb` (exercises `_error_messages` on the failure path) — must stay green.
3. **Review:** run review-changes before proceeding.

### Task 2 [Master]: `sessions/new` + `sessions/otp` + system-test selectors (pattern-setter)

**Skills:** style-ui, write-tests
**Reference:** `lib/jumpstart/app/views/devise/sessions/{new,otp}.html.erb`, `test/system/login_system_test.rb`.

**In scope:**

- `app/views/devise/sessions/new.html.erb`: email → `FormFieldComponent`(`f.email_field`), password → `PasswordComponent` (`current-password`), remember_me → `CheckboxComponent` (`name: "user[remember_me]"`), submit → `ButtonComponent`. Preserve the `hotwire_native_app?` hidden-`remember_me` branch, the `devise_mapping.rememberable?` guard, and `render "devise/shared/links"`.
- `app/views/devise/sessions/otp.html.erb`: otp_attempt → `FormFieldComponent`(`f.text_field`, keep `inputmode: "numeric"`, `autocomplete: "one-time-code"`, `autofocus`, `required`); submit → `ButtonComponent`. Keep the `users.two_factor.*` i18n keys and the `<h1>` title.
- `test/system/login_system_test.rb`: change the two `find('input[name="commit"]').click` calls (in `login_with_email_and_password` and `submit_otp`) to `find("button[type=submit]").click`.

**NOT in scope:** other views; the sessions controller; 2FA logic.

**Caveats:** This is the canonical pattern all clone tasks copy — get the FormField/Password/Button recipe clean. `CheckboxComponent` emits no companion hidden `"0"`; absent `remember_me` == false, so behavior is unchanged (per design).

**Build order:**

1. **Test:** update `login_system_test.rb` selectors first (Test-first: it will fail against the old `input` until the view is rebuilt).
2. **Implement:** the two views.
3. **Verify:** `mise exec -- bin/rails test:system test/system/login_system_test.rb` — all 7 tests (incl. the five 2FA) green.
4. **Review:** run review-changes before proceeding.

### Task 3 [Clone]: `passwords/new`, `confirmations/new`, `unlocks/new`

**Skills:** style-ui
**Reference:** Task 2's rebuilt `sessions/new` for the pattern; `lib/jumpstart/app/views/devise/{passwords/new,confirmations/new,unlocks/new}.html.erb`.

**In scope:** rebuild all three single-email-field forms. email → `FormFieldComponent`(`f.email_field`), submit → `ButtonComponent`, `render "error_messages"` summary kept, `render "devise/shared/links"` kept. Preserve: `confirmations/new`'s reconfirmation prefill `value:` and each view's exact `t('.…')` heading/button keys. Match each original's full-width choice (new/confirmations use `btn-expanded` → `full_width: true`; unlocks does not).

**NOT in scope:** `passwords/edit` (Task 4); controllers.

**Build order:**

1. **Implement:** the three views.
2. **Verify:** `mise exec -- bin/rails test` (full suite green; these have no dedicated view test — rely on suite + Task 7 browser check).
3. **Review:** run review-changes before proceeding.

### Task 4 [Clone]: `passwords/edit`

**Skills:** style-ui
**Reference:** Task 2's `sessions/new`; `lib/jumpstart/app/views/devise/passwords/edit.html.erb`.

**In scope:** `app/views/devise/passwords/edit.html.erb`. Keep the **raw** `f.hidden_field :reset_password_token` verbatim (not wrapped). password → `PasswordComponent` (`new-password`, was `autofocus: true` — see caveat) with the `@minimum_password_length` hint (`hint:` or the muted `<p>` below); password_confirmation → `PasswordComponent` (`new-password`). Submit → `ButtonComponent` (no `btn-expanded` → `full_width: false`). Keep `error_messages` + `shared/links`.

**NOT in scope:** password reset logic; token generation.

**Caveats:** ⚠️ original password field has `autofocus: true` — if `PasswordComponent` exposes no autofocus arg, STOP and ask before dropping it. Invalid/expired token: the hidden token stays and the `:reset_password_token` error surfaces in the summary alert (already handled by keeping `error_messages`).

**Build order:**

1. **Implement:** the view.
2. **Verify:** `mise exec -- bin/rails test`.
3. **Review:** run review-changes before proceeding.

### Task 5 [Clone]: `registrations/new`

**Skills:** style-ui, write-tests
**Reference:** Task 2's `sessions/new`; `lib/jumpstart/app/views/devise/registrations/new.html.erb`; `test/controllers/users/registrations_controller_test.rb`.

**In scope:** `app/views/devise/registrations/new.html.erb`. name/email → `FormFieldComponent`; password → `PasswordComponent` (`new-password`) + `@minimum_password_length` hint; terms_of_service → `CheckboxComponent` (`name: "user[terms_of_service]"`); keep `invisible_captcha` verbatim (wrapped or standalone); `@account_invitation` block → `AlertComponent(variant: :info)` keeping the avatar + `invited_you_to_join_html`; submit → `ButtonComponent` (`full_width: true`, `disable_with: t('.submitting')`). Preserve the commented `owned_accounts` block and `error_messages` + `shared/links`.

**NOT in scope:** `registrations/edit` (Task 6); registration controller/captcha logic.

**Caveats:** ⚠️ `terms_of_service` label contains **links** (terms + privacy). Check whether `CheckboxComponent` renders `label:` as HTML or offers a slot/`description`. If it escapes HTML and has no HTML-capable slot, STOP and ask — do not silently drop the links.

**Build order:**

1. **Test:** the existing `registrations_controller_test.rb` already asserts the render contains `user[name]`/`user[email]`/`user[password]` + captcha sentence, plus success/failure counts — these are the spec; keep them green.
2. **Implement:** the view.
3. **Verify:** `mise exec -- bin/rails test test/controllers/users/registrations_controller_test.rb`.
4. **Review:** run review-changes before proceeding.

### Task 6 [Master]: `registrations/edit`

**Skills:** style-ui
**Reference:** Task 2's `sessions/new`; `lib/jumpstart/app/views/devise/registrations/edit.html.erb`.

**In scope:** `app/views/devise/registrations/edit.html.erb`. Keep `content_for :sidebar, render("account_navbar")` verbatim (sidebar partial NOT rebuilt). avatar → `FormFieldComponent`(`f.file_field`, keep the avatar `image_tag` preview + accept list); name/email → `FormFieldComponent`; preferred_language + theme → `SelectComponent` (render real `select_tag`, `name: "user[theme]"`/`"user[preferred_language]"`, `selected:` current value, options = `theme_options` / `I18n.available_locales`). Reconfirmation warning → `AlertComponent(variant: :warning)`. Update button → `ButtonComponent(type: "submit")` carrying `data: { "bridge--form-target": "submit", "bridge-title": t('.update'), disable_with: t('.saving') }`. Cancel-account: keep the `button_to` + `bridge--sign-out` + all `turbo_confirm*` data verbatim, restyled with destructive DS classes. Keep the `bridge--form` controller/actions on the `form_with`.

**NOT in scope:** the `_account_navbar` sidebar partial (keeps rendering, not rebuilt); billing/account views; cancel-account or bridge logic.

**Caveats:** ⚠️ `SelectComponent` may auto-insert a blank `<option>`; the originals pass `{}` (no `include_blank`), so the option set must be unchanged — do **not** pass `placeholder:`, and verify no stray blank option is emitted (suppress if it is). Preserve `I18n.available_locales.length > 1` guard around preferred_language.

**Build order:**

1. **Implement:** the view.
2. **Verify:** `mise exec -- bin/rails test`.
3. **Review:** run review-changes before proceeding.

### Task 7 [Master]: Request test for reset + full verification

**Skills:** write-tests
**Reference:** existing `test/controllers/api/v1/passwords_controller_test.rb` for request-test style; `test/system/login_system_test.rb`.

**In scope:**

- Add a request/integration test for the password-reset flow the design calls out: reset **request** (`POST` to `password_path` renders/redirects) and **token reset** (`PUT` with a valid `reset_password_token` updates the password). Add a lightweight confirmation/unlock render smoke test if not already covered.
- Run the full suite and show output: `mise exec -- bin/rails test` and `mise exec -- bin/rails test:system`.
- Browser-verify (via the run/verify skill): sign-in happy path + wrong-password error, in light AND dark, at mobile width.

**NOT in scope:** new behavior; new components; `/update-catalog` (no component changed).

**Build order:**

1. **Test:** write the reset request test(s) first.
2. **Verify:** full `bin/rails test` + `bin/rails test:system`, output shown; browser check light/dark/mobile.
3. **Review:** run review-changes before final commit.

## Task Dependencies

- **Task 1** (shared partials) and **Task 2** (pattern-setter) are the foundation — do them first, in order. Every later view renders `_error_messages`/`shared/links` (Task 1) and copies the field/password/button recipe from Task 2.
- **Tasks 3, 4, 5** are independent of each other and can run in parallel (clones) once Tasks 1–2 land. Each touches only its own view file(s) (+ Task 5 verifies an existing test).
- **Task 6** depends on Tasks 1–2; independent of 3–5 but assigned Master for the `SelectComponent`/bridge/destructive-button judgment.
- **Task 7** runs last, after all views exist.

## Note on TDD framing

This is a *visual replacement with behavior preserved*, so the existing tests (login system test, registrations controller test) are the regression net — the "test-first" step in most tasks is updating/keeping those green, with one genuinely new test (password-reset request) in Task 7.
