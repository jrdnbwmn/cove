> Ticket: COV-5
> Branch: jrdnbwmn/feature/cov-5-implement-google-oauth

# Plan: Google OAuth Sign-In

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Enable `google-oauth2` provider + bundle | Master | |
| 2 | Store production Google credentials + delete scratch file | Master | |
| 3 | Add test-env credentials so provider registers in test | Master | |
| 4 | Integration tests: sign-up, returning login, button render | Master | |

## Prerequisites

- Design: `docs/designs/google-oauth.md`
- Prototype: None (JSP default provider button)
- Feature branch exists: `jrdnbwmn/feature/cov-5-implement-google-oauth`
- Scratch credentials at `.context/google-oauth-credentials.txt` (gitignored)

## Key Findings (why the plan looks like this)

- The OAuth flow is **already fully built and tested generically** in JSP:
  `Users::OmniauthCallbacksController`, `ConnectedAccount`, the callbacks
  concern, and `test/integration/jumpstart/omniauth_callbacks_test.rb` (which
  drives register/login/connect/reject with the `:developer` mock). We are not
  writing flow code.
- The gem `omniauth-google-oauth2` loads whenever `"google-oauth2"` is in
  `config/jumpstart.rb`'s `omniauth_providers` (`Gemfile.jumpstart:42`) —
  **independent of credentials**.
- Devise only mounts a provider's routes/button when
  `Jumpstart::Omniauth.enabled?` is true, which requires **both** the config
  entry **and** credentials (`lib/jumpstart/lib/jumpstart/omniauth.rb:63`). This
  is evaluated **once at boot** (`config/initializers/devise.rb:298`).
- Consequence: to test the real `google_oauth2` callback route and the rendered
  button in the test env, dummy Google credentials must exist in
  `config/credentials/test.yml.enc` **at boot** — runtime stubbing won't mount
  the route. Hence Task 3.
- Every task touches shared auth/config/credentials infra → all Master. No clone
  work.

## Tasks

### Task 1 [Master]: Enable Google provider and bundle

**In scope:**

- Edit `config/jumpstart.rb`: change `"omniauth_providers" => []` to
  `"omniauth_providers" => ["google-oauth2"]`.
- Run `bundle install` (pulls `omniauth`, `omniauth-rails_csrf_protection`,
  `omniauth-google-oauth2`).
- Confirm the app boots: `bin/rails runner "puts OmniAuth::Strategies::GoogleOauth2"`.

**NOT in scope:**

- Any other provider. Credentials (Task 2). Test credentials (Task 3).

**Build order:**

1. **Implement:** edit `config/jumpstart.rb`; `bundle install`.
2. **Verify:** `bin/rails runner "puts defined?(OmniAuth::Strategies::GoogleOauth2)"`
   prints `constant`; `git diff Gemfile.lock` shows the three gems added.
3. **Review:** run review-changes before proceeding.

---

### Task 2 [Master]: Store production Google credentials, delete scratch file

**Reference:** credentials layout in
`lib/jumpstart/lib/jumpstart/omniauth.rb:74-81` — nested `omniauth.google_oauth2`
with `public_key` (Client ID) and `private_key` (Client Secret).

**In scope:**

- `bin/rails credentials:edit` (default/production credentials,
  `config/credentials.yml.enc`), add:
  ```yaml
  omniauth:
    google_oauth2:
      public_key: <Client ID from .context/google-oauth-credentials.txt>
      private_key: <Client Secret>
  ```
- Delete `.context/google-oauth-credentials.txt` after storing.

**NOT in scope:**

- Test credentials (Task 3). Committing any secret to a tracked file.

**Build order:**

1. **Implement:** edit credentials; delete scratch file.
2. **Verify:** `bin/rails runner "puts Jumpstart::Omniauth.has_credentials?('google-oauth2')"`
   prints `true`; `ls .context/google-oauth-credentials.txt` reports missing.
3. **Review:** run review-changes (confirm no secret landed in the diff — only
   `credentials.yml.enc` changed).

---

### Task 3 [Master]: Add test-env credentials so the provider registers in test

**Reference:** `config/credentials/test.yml.enc` (decrypt with existing
`config/credentials/test.key`). These are **dummy** non-sensitive values, safe to
commit encrypted.

**In scope:**

- `bin/rails credentials:edit --environment test`, add:
  ```yaml
  omniauth:
    google_oauth2:
      public_key: test-google-client-id
      private_key: test-google-client-secret
  ```

**NOT in scope:**

- Real secrets in the test file. Any production credential change.

**Build order:**

1. **Implement:** edit test credentials.
2. **Verify:**
   `RAILS_ENV=test bin/rails runner "puts Jumpstart::Omniauth.enabled?('google-oauth2'); puts User.omniauth_providers.inspect"`
   → `enabled?` is `true` and `:google_oauth2` appears in the providers list
   (route/button will mount).
3. **Review:** run review-changes.

---

### Task 4 [Master]: Integration tests for the Google flow

**Skills:** write-tests
**Reference:** `test/integration/jumpstart/omniauth_callbacks_test.rb` — mirror its
`OmniAuth.config.test_mode` + `add_mock` pattern, but for `:google_oauth2`.
Depends on Task 3 (route must be mounted in test).

**In scope:** new file `test/integration/users/google_oauth_test.rb`, guarded by
`if defined? OmniAuth`, covering:

- **New-user sign-up:** mock `:google_oauth2` (uid + `info: { email:, name: }`),
  `get "/users/auth/google_oauth2/callback"` → asserts a `User` is created with
  the Google email/name, a `ConnectedAccount` with `provider "google_oauth2"` +
  uid, and the user is signed in (`controller.current_user`).
- **Returning connected user:** after the above, `sign_out`, hit the callback
  again → asserts the **same** user is signed in and no duplicate
  `User`/`ConnectedAccount` (`assert_no_difference`).
- **Button renders:** `get "/users/sign_in"` and `get "/users/sign_up"` →
  response body includes the Google sign-in button (assert on
  `t("oauth.sign_in_with", provider: t("oauth.google_oauth2"))` text or the
  `auth/google_oauth2` authorize path).

**NOT in scope:**

- Re-testing connect-while-signed-in or the existing-email rejection — already
  covered generically by `omniauth_callbacks_test.rb`. Modifying any JSP engine
  file. System/browser tests.

**Build order:**

1. **Test:** write `test/integration/users/google_oauth_test.rb` as above.
2. **Verify:** `bin/rails test test/integration/users/google_oauth_test.rb`
   passes; also run
   `bin/rails test test/integration/jumpstart/omniauth_callbacks_test.rb` to
   confirm no regression.
3. **Review:** run review-changes.

## Task Dependencies

- Task 1 → 2 → 3 → 4 are strictly **sequential**: bundling must precede
  credentials; test credentials (3) must exist before the test route mounts (4).
- No parallelism; no clone tasks (all touch shared config/credentials/auth infra).
