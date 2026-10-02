> Ticket: COV-96
> Branch: chore/cov-96-security-audit

# Plan: Security audit fixes (COV-96)

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Google sign-in refuses existing accounts, with a clear alert | Master | ✅   |
| 2    | 1     | 1          | Revoke API tokens whenever the password changes | Clone  | ✅   |
| 3    | 2     | 2          | "Email me a link to set a password" endpoint | Master | ✅   |
| 4    | 2     | 2          | Password reset links work while signed in | Master | ✅   |
| 5    | 2     | 2          | "Set a password" button on Settings → Password | Clone  | ✅   |
| 6    | 3     | 3          | Require current password to change email (controller) | Master |      |
| 7    | 3     | 3          | "Current password" field + hint on the profile form | Clone  |      |
| 8    | 3     | 4          | Loops "email changed" mailer method | Master |      |
| 9    | 3     | 4          | Turn on Devise email-changed notification | Clone  |      |
| 10   | 4     | 5          | Admin bootstrap only promotes when no system admin exists | Clone  |      |

## Prerequisites

- Design: the COV-96 security audit report and decisions in conversation. No design doc.
- Prototype: None
- Feature branch exists: `chore/cov-96-security-audit`
- **Blocker for Task 8:** Jordan creates a Loops transactional email "Email changed"
  (data variables: `recipient_email`, `new_email`) and provides its transactional ID.
- Shell: `export PATH="$HOME/.local/share/mise/shims:$PATH"` before any `bin/rails`
  command; `ruby -v` must report 4.0.5.

### Decisions (approved by Jordan)

- **Google sign-in when a password account already uses that email:** refuse. Show a
  clear alert on the sign-in page telling them to sign in with their password and then
  connect Google from Connected Accounts. After that, both Google and password work.
  Reason: sign-up emails aren't verified, so auto-linking lets an attacker who
  pre-registered someone's email keep a working password on the victim's account.
- **Users with no known password** (signed up with Google): Settings → Password gets an
  "Email me a link to set a password" button. It sends the existing Loops reset email.
- **Changing email requires the current password.** The old address gets an
  "email changed" notice through Loops.
- **Admin bootstrap** may promote an existing user only while zero system admins exist.

## Tasks

### Task 1 [Master]: Google sign-in refuses existing accounts, with a clear alert

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb` (engine flow; the
`User.exists?(email: ...)` branch is the behavior we want) and
`test/integration/users/google_oauth_test.rb`. The sign-in page uses `layouts/minimal`,
which renders flash messages inline as an `AlertComponent` (`application/_flash`,
`inline: devise_controller? && !user_signed_in?`). No new UI component is needed.

**In scope:**

- Rewrite `google_oauth2` in `app/controllers/users/omniauth_callbacks_controller.rb`:
  - If `!user_signed_in? && connected_account.blank? && auth.info.email.present? && User.by_email(auth.info.email).exists?`:
    `store_location_for(:user, user_connected_accounts_path)`, then
    `redirect_to new_user_session_path, alert: t("users.omniauth_callbacks.account_exists")`.
    The stored location sends them to Connected Accounts right after they sign in with
    their password.
  - Otherwise `super`.
  - Remove the existing auto-link code (`existing_user.connected_accounts.create!` and its sign-in).
  - Add an `# AIDEV-NOTE:` that auto-linking by email was removed in COV-96 because local
    password accounts have unverified emails (account pre-hijack).
- In `config/locales/en.yml`, replace `users.omniauth_callbacks.account_exists` with:
  "You already have a Cove account with this email. Sign in with your password below and
  we'll take you to Connected Accounts to add Google. Forgot your password? Use “Forgot
  your password?” below."

**NOT in scope:**

- Editing the engine file `lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb`.
- Changing the Connected Accounts page, the sign-in page layout, or adding a new component.
- Email confirmation (`:confirmable`).

**Build order:**

1. **Test:** in `test/integration/users/google_oauth_test.rb`:
   - Replace "links a verified Google identity to an existing user" with "Google sign-in
     with an existing account's email asks the person to sign in with their password".
     Mock email = `users(:one).email.upcase`. Assert:
     - no change in `User.count` / `ConnectedAccount.count`,
     - `controller.current_user` is nil,
     - redirected to `new_user_session_path`,
     - `flash[:alert] == I18n.t("users.omniauth_callbacks.account_exists")`.
     Then `follow_redirect!` and `assert_select` that the alert text renders on the page.
   - Add "a pre-registered password account cannot be entered through Google":
     `User.create!(email: "victim@example.com", password: "attackerpass123", name: "Victim", terms_of_service: true)`,
     mock Google with that email; assert not signed in and no ConnectedAccount created.
   - Add "after signing in with a password, the person lands on Connected Accounts":
     trigger the refusal for `users(:one)`, then `post user_session_path` with that user's
     fixture password; assert redirected to `user_connected_accounts_path`.
   - Keep the existing tests passing: new-user sign-up, returning connected user,
     different-UID refusal, blank email.
   - Run them first; the new and changed tests must fail.
2. **Implement:** the controller change and the locale copy.
3. **Verify:** `bin/rails test test/integration/users/google_oauth_test.rb test/integration/users/connected_accounts_test.rb`

### Task 2 [Clone]: Revoke API tokens whenever the password changes

**Skills:** write-tests
**Reference:** Read `test/integration/account_passwords_test.rb` and
`test/controllers/users/passwords_controller_test.rb` (line 4, valid reset-token flow).

**In scope:**

- In `app/models/user.rb` add
  `after_update :revoke_api_tokens, if: :saved_change_to_encrypted_password?`, with a
  private `revoke_api_tokens` that runs `api_tokens.destroy_all`.
- Add an `# AIDEV-NOTE:` covering two points:
  - this deliberately includes the token used by `Api::V1::PasswordsController`;
  - no native app ships yet, so nothing needs a re-issued token.

**NOT in scope:**

- Re-issuing tokens, hashing tokens at rest, token expiry, API tokens page UI.

**Build order:**

1. **Test:**
   - `test/models/user_test.rb`:
     - "changing the password revokes the user's API tokens"
     - "updating the name keeps API tokens"
   - `test/integration/account_passwords_test.rb`: "changing the password signs out API
     tokens". Create a token, `PUT /account/password` with the correct current password,
     then `get "/api/v1/me", headers: {"Authorization" => "Bearer #{token}"}` →
     `assert_response :unauthorized`. Reuse the file's Loops WebMock stubs.
   - `test/controllers/users/passwords_controller_test.rb`: "resetting a forgotten
     password signs out API tokens", with the same assertion.
2. **Implement:** the callback.
3. **Verify:** `bin/rails test test/models/user_test.rb test/integration/account_passwords_test.rb test/controllers/users/passwords_controller_test.rb test/integration/api_tokens_test.rb`
4. **Checkpoint 1 review:** when this task is done, run the full `bin/rails test`, then run
   review-changes-mini for Checkpoint 1 (Tasks 1–2). If the checkpoint's tasks ran as a
   parallel batch, the master runs this review once the whole batch returns instead.
   Run it exactly once per checkpoint.

### Task 3 [Master]: "Email me a link to set a password" endpoint

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/account/passwords_controller.rb` (the
same settings area) and `lib/jumpstart/app/controllers/users/passwords_controller.rb`
(the `rate_limit` line to copy).

**In scope:**

- `config/routes/users.rb`: inside the existing `namespace :account do` block add
  `resource :password_reset_link, only: :create`.
- New `app/controllers/account/password_reset_links_controller.rb`:
  - `before_action :authenticate_user!`
  - the same `rate_limit` as `Users::PasswordsController#create`, redirecting to
    `edit_account_password_path` with `I18n.t("try_again_later")`
  - `create` calls `current_user.send_reset_password_instructions`, then
    `redirect_to edit_account_password_path, notice: t(".sent", email: current_user.email)`
- `config/locales/en.yml`: add `account.password_reset_links.create.sent`:
  "We emailed a link to %{email}. Use it to set your password." (Insert next to the
  existing `account: passwords:` keys around line 571.)

**NOT in scope:**

- The button UI (Task 5), the reset page itself (Task 4), new email templates
  (reuses the existing Loops reset email).

**Build order:**

1. **Test:** new `test/integration/account_password_reset_links_test.rb`:
   - "signed-in user can email themselves a link to set a password": `sign_in users(:one)`,
     stub the Loops reset-password request the way `test/controllers/users/passwords_controller_test.rb`
     does, `post account_password_reset_link_path`. Assert:
     - redirected to `edit_account_password_path`,
     - the notice is present,
     - exactly one Loops request was sent to the user's email,
     - `users(:one).reload.reset_password_token` is present.
   - "signed-out visitor is sent to sign in" → redirected to `new_user_session_path`, no request.
2. **Implement:** route, controller, locale.
3. **Verify:** `bin/rails test test/integration/account_password_reset_links_test.rb`

### Task 4 [Master]: Password reset links work while signed in

**Skills:** write-tests
**Reference:** `lib/jumpstart/app/controllers/users/passwords_controller.rb` is a vendored
Jumpstart file that already carries local edits. Mark the change the same way other
vendored edits are marked ("AIDEV-NOTE: Local change (COV-96) to Jumpstart: ...").

**Why:** Devise's `PasswordsController` has `require_no_authentication`, so a signed-in
user clicking the emailed link from Task 3 gets bounced with "already signed in".

**In scope:**

- In `lib/jumpstart/app/controllers/users/passwords_controller.rb` add
  `skip_before_action :require_no_authentication, only: [:edit, :update]` with the
  AIDEV-NOTE.
- Devise's existing `update` signs the reset user in afterwards (the
  `sign_in_after_reset_password` proc in `config/initializers/devise.rb:250`). Leave that as is.

**NOT in scope:**

- `new`/`create` (the "Forgot your password?" request form stays signed-out only).
- Changing `sign_in_after_reset_password`.

**Build order:**

1. **Test:** in `test/controllers/users/passwords_controller_test.rb`:
   - "a signed-in user can open their emailed reset link and set a password": sign in
     `users(:one)`, generate a raw token as the existing valid-token test does,
     `get edit_user_password_path(reset_password_token: raw)` → `:success`
     (not a redirect). Then `put user_password_path` with the new password and
     confirmation, and assert `users(:one).reload.valid_password?(new_password)`.
   - Existing signed-out tests keep passing.
2. **Implement:** the skip line.
3. **Verify:** `bin/rails test test/controllers/users/passwords_controller_test.rb`

### Task 5 [Clone]: "Set a password" button on Settings → Password

**Skills:** style-ui, write-tests
**Reference:** `app/views/account/passwords/edit.html.erb`. Copy the two-factor section's
markup pattern below the `<hr>`: an `h2.h4` title, a muted `p`, and a
`ButtonComponent` with `variant: :secondary`. For a POST, use
`href:` + `data: {turbo_method: :post}`, like the 2FA disable button's `turbo_method: :delete`.

**In scope:**

- In `app/views/account/passwords/edit.html.erb`, add a section between the password form
  and the existing `<hr>`/two-factor section:
  - `<hr>`
  - `<h2 class="h4">` with `t(".set_password.title")` → "No password yet, or forgot it?"
  - `<p class="mt-2 mb-4 text-sm text-muted-foreground">` with `t(".set_password.description")` →
    "If you signed up with Google, or don't remember your current password, we'll email
    you a link to set one. Afterward you can sign in with Google or your password."
  - `ButtonComponent.new(text: t(".set_password.button"), variant: :secondary, href: account_password_reset_link_path, data: {turbo_method: :post})`
    with button text "Email me a link"
- Add those three keys under `account.passwords.edit.set_password` in `config/locales/en.yml`.

**NOT in scope:**

- Hiding the section for anyone (it shows for everyone; the app can't tell who has a password).
- Changing the existing password form or the two-factor section.

**Build order:**

1. **Test:** in `test/integration/account_passwords_test.rb`: "password page offers to
   email a link to set a password". `get edit_account_password_path`, then assert the
   title text and a `[data-turbo-method='post'][href='#{account_password_reset_link_path}']`
   element render.
2. **Implement:** view and locale.
3. **Verify:** `bin/rails test test/integration/account_passwords_test.rb`
4. **Checkpoint 2 review:** when this task is done, run review-changes-mini for
   Checkpoint 2 (Tasks 3–5). If the checkpoint's tasks ran as a parallel batch, the master
   runs this review once the whole batch returns instead. Run it exactly once per checkpoint.

### Task 6 [Master]: Require current password to change email (controller)

**Skills:** write-tests
**Reference:** `app/controllers/users/registrations_controller.rb` (`update_resource`) and
`test/controllers/users/registrations_controller_test.rb`.

**In scope:**

- Replace `update_resource` in `app/controllers/users/registrations_controller.rb`:
  - If `User.normalize_value_for(:email, params[:email])` differs from `resource.email`
    (and `params[:email]` is present), call `resource.update_with_password(params)`.
  - Otherwise call `resource.update_without_password(params.except(:current_password))`.
    The `.except` is required: `User` has no `current_password=` writer, and the form
    will always submit that field after Task 7.
  - Keep the "Jumpstart: Allow user to edit their profile without password" comment.
    Add an `# AIDEV-NOTE:` explaining the COV-96 email exception (a stolen session must
    not be able to silently re-point the login email).

**NOT in scope:**

- Form field and hint (Task 7), notifications (Tasks 8–9), the API.

**Build order:**

1. **Test:** in `test/controllers/users/registrations_controller_test.rb`, signed in as `users(:one)`:
   - "changing email without the current password is rejected": `put user_registration_path,
     params: {user: {name: "X", email: "new@example.com"}}` → `:unprocessable_content`;
     the email is unchanged.
   - "changing email with a wrong current password is rejected": same outcome.
   - "changing email with the correct current password succeeds" (use the fixture password).
   - "editing only the name needs no password".
   - "resubmitting the same email in different case needs no password".
2. **Implement:** as above.
3. **Verify:** `bin/rails test test/controllers/users/registrations_controller_test.rb test/integration/users_test.rb`

### Task 7 [Clone]: "Current password" field + hint on the profile form

**Skills:** style-ui, write-tests
**Reference:** copy the `PasswordComponent` usage from `app/views/account/passwords/edit.html.erb`
(lines 10–19). Edit target: `app/views/devise/registrations/edit.html.erb`.

**In scope:**

- After the email `FormFieldComponent` (before the confirmable alert), add a
  `PasswordComponent` with:
  - `label: resource.class.human_attribute_name(:current_password)`
  - `name: "user[current_password]"`, `id: "user_current_password"`
  - `autocomplete: "current-password"`
  - `error: resource.errors[:current_password].first`
  - `hint: t(".current_password_hint")`
  - `classes: "mb-6"`
  - not required
- `config/locales/devise.en.yml`, under `devise.registrations.edit`:
  `current_password_hint: "Needed only to change your email. No password yet? Set one from Settings → Password."`

**NOT in scope:**

- Showing or hiding the field dynamically, JS, other form changes.

**Build order:**

1. **Test:** in `test/controllers/users/registrations_controller_test.rb`:
   - "profile form asks for the current password": `assert_select "input[name='user[current_password]'][autocomplete='current-password']"`
     and the hint text is present.
   - "a rejected email change shows the current-password error on the form".
2. **Implement:** view and locale.
3. **Verify:** `bin/rails test test/controllers/users/registrations_controller_test.rb`
4. **Checkpoint 3 review:** when this task is done, run review-changes-mini for
   Checkpoint 3 (Tasks 6–7). If the checkpoint's tasks ran as a parallel batch, the master
   runs this review once the whole batch returns instead. Run it exactly once per checkpoint.

### Task 8 [Master]: Loops "email changed" mailer method

**BLOCKED until Jordan provides the Loops transactional ID.**
**Skills:** write-tests
**Reference:** `app/mailers/loops_devise_mailer.rb` (`password_change`) and
`test/mailers/loops_devise_mailer_test.rb`.

**In scope:**

- `config/loops.yml`: add `email_changed: <ID from Jordan>` under `shared.transactional`.
- `app/mailers/loops_devise_mailer.rb`: add `email_changed(record, opts = {})`, mirroring
  `password_change`, with data variables
  `{recipient_email: opts[:to] || record.email, new_email: record.email}`.
  Devise passes the **old** address as `opts[:to]`; it stays the recipient.
- `test/mailers/loops_devise_mailer_test.rb`: add the key to the "config/loops.yml exposes
  every checked-in transactional mapping" test (both the value and the ordered key list).

**NOT in scope:**

- Enabling the notification (Task 9), ERB bodies (stay `""`).

**Build order:**

1. **Test:** "email-changed notice goes to the old address with the new address in its
   data". Assert:
   - `to == ["old@example.com"]`,
   - the transactional-ID header equals the new ID,
   - the data-variables JSON is correct,
   - no ERB renders (use the existing `ExplodingLoopsDeviseMailer` pattern).
2. **Implement:** config and mailer method.
3. **Verify:** `bin/rails test test/mailers/loops_devise_mailer_test.rb`

### Task 9 [Clone]: Turn on Devise email-changed notification

**Skills:** write-tests
**Reference:** the Loops WebMock pattern in `test/integration/account_passwords_test.rb`
("changing the password sends exactly one Loops password-changed request", line 60).

**In scope:**

- `config/initializers/devise.rb` line 151: replace the commented line with
  `config.send_email_changed_notification = true`.
- An integration test in `test/controllers/users/registrations_controller_test.rb`.

**NOT in scope:**

- Mailer code (Task 8), confirmable/reconfirmable.

**Build order:**

1. **Test:**
   - "changing email notifies the old address": stub Loops like the reference test, `PUT`
     a new email with the correct current password, then assert exactly one Loops request
     with the `email_changed` ID and `email` equal to the old address.
   - "a name-only update sends no email-changed notice".
2. **Implement:** the Devise setting.
3. **Verify:** `bin/rails test test/controllers/users/registrations_controller_test.rb test/mailers/loops_devise_mailer_test.rb`
4. **Checkpoint 4 review:** when this task is done, run the full `bin/rails test`, then run
   review-changes-mini for Checkpoint 4 (Tasks 8–9). If the checkpoint's tasks ran as a
   parallel batch, the master runs this review once the whole batch returns instead.
   Run it exactly once per checkpoint.

### Task 10 [Clone]: Admin bootstrap only promotes when no system admin exists

**Skills:** write-tests
**Reference:** `app/services/admin_bootstrap.rb` and `test/services/admin_bootstrap_test.rb`.

**In scope:**

- In `AdminBootstrap#call`, when an existing non-admin user is found and
  `User.where(admin: true).exists?` is true:
  - don't grant admin,
  - log at `:error`: `"refused to promote existing user #{user.email}: a system admin already exists"`,
  - return the user.
- The zero-admin case and users that bootstrap creates itself behave as they do today.
- Add an `# AIDEV-NOTE:` explaining why (COV-96: emails aren't verified, and bootstrap
  runs on every staging boot).

**NOT in scope:**

- `render.yaml`, `lib/tasks/admin.rake`, removing the env var (Jordan does that in Render).

**Build order:**

1. **Test:** in `test/services/admin_bootstrap_test.rb`:
   - Adjust "promotes an existing user without changing profile password or marketing
     consent" to first run `User.where(admin: true).update_all(admin: false)`.
     (`admin` is `attr_readonly`, so `update_all` is required.)
   - Add "does not promote an existing user when a system admin already exists" using
     `users(:one).email`, with the `users(:admin)` fixture present. Assert `admin?` is
     false after reload and the error is logged.
   - The other existing tests still pass.
2. **Implement:** as above.
3. **Verify:** `bin/rails test test/services/admin_bootstrap_test.rb`, then the full `bin/rails test`.
4. **Checkpoint 5 review:** when this task is done, run review-changes-mini for
   Checkpoint 5 (Task 10). If it ran in a parallel batch, the master runs this review once
   the batch returns instead. Run it exactly once per checkpoint.

## Task Dependencies

- **Shared files:** Tasks 1, 3 and 5 all edit `config/locales/en.yml`. Tasks 6, 7 and 9
  all edit `test/controllers/users/registrations_controller_test.rb`. Don't run tasks that
  share a file in parallel.
- **Checkpoint 1:** Task 2 is independent of Task 1 and can run alongside it.
- **Checkpoint 2:** Task 4 depends on Task 3, since the emailed link is what it makes
  usable. Task 5 depends on Task 3 for the route.
- **Phase 3 needs Phase 2 shipped first:** Google-only users need the "set a password"
  button before email changes start requiring a password.
- **Checkpoint 3:** Task 7 depends on Task 6, because its error-state test needs the
  controller change.
- **Checkpoint 4:** Task 8 is blocked on the Loops ID. Task 9 depends on Task 8 and Task 6.
- **Task 10** is independent and can run any time.
