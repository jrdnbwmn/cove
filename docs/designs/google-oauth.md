> Ticket: COV-5
> Branch: jrdnbwmn/feature/cov-5-implement-google-oauth

# Feature: Google OAuth Sign-In

## Problem
Users can only sign up and sign in with email and password. Offering "Sign in
with Google" gives them a faster, password-free way to register and log in,
reducing friction at the front door of Cove.

## Approach
Enable Jumpstart Pro's built-in OmniAuth support for the Google provider. This
is a configuration change, not new feature code — JSP already ships the entire
OAuth flow in this app:

- `Users::OmniauthCallbacksController` (register / login / connect / reject).
- `ConnectedAccount` model and `connected_accounts` table (migrations already run).
- Connected-accounts management UI at `/users/connected_accounts` (view + disconnect).
- Provider buttons auto-rendered on the login and registration pages
  (`devise/shared/_links`), styled with the app's secondary button.
- Devise auto-registration of enabled providers via `Jumpstart::Omniauth.enabled_providers`.
- A `"google-oauth2"` entry already defined in JSP's provider registry.
- `Gemfile.jumpstart` loads `omniauth-google-oauth2` automatically when the
  provider is enabled.
- Locale strings for the buttons and edge-case flashes already exist in `en.yml`.

Implementation reduces to:
1. Add `"google-oauth2"` to `omniauth_providers` in `config/jumpstart.rb`.
2. `bundle install` (pulls in `omniauth`, `omniauth-rails_csrf_protection`,
   `omniauth-google-oauth2`).
3. Store the Google Client ID / Secret in Rails encrypted credentials under
   `omniauth.google_oauth2` (`public_key` = Client ID, `private_key` = Client Secret).
4. Add automated test coverage for the sign-up and login paths.

## Acceptance Criteria
- A "Sign in with Google" button appears on both the login and registration pages.
- A brand-new user can click it, authorize with Google, and land signed in with a
  Cove account created from their Google email + name.
- A returning user who previously connected Google is signed straight in.
- A signed-in user can connect Google from settings and see it under
  `/users/connected_accounts`, and can disconnect it.
- A user with an existing email/password account who tries Google with that same
  email is rejected with the "log in first" message (JSP default — see Scope).
- Tests cover the new-user sign-up and returning-user login paths.

## Prototype
None. UI is JSP's default provider button — no custom design.

## Data Model
No changes. Uses the existing `ConnectedAccount` model / `connected_accounts`
table (polymorphic `owner`, stores `provider`, `uid`, tokens, and the auth hash).
No migration.

## Screens / Flows
1. **Sign up / Sign in pages** — a "Sign in with Google" button below the
   email/password form (both `registrations#new` and `sessions#new`).
2. **New user** — clicks button → Google consent → callback creates a `User`
   (random password, `terms_of_service: true`, `name` from Google) plus a
   `ConnectedAccount`, then signs them in.
3. **Returning connected user** — clicks button → callback finds the existing
   `ConnectedAccount` → signed straight in.
4. **Signed-in user connecting Google** — from `/users/connected_accounts`,
   clicks Google → callback attaches a `ConnectedAccount` to `current_user`.
5. **Existing-email-but-not-connected** — rejected with
   "We already have an account with this email. Login with your previous account
   before connecting this one." and redirected to the login page.
6. **Manage** — `/users/connected_accounts` lists connected providers and allows
   disconnecting.

## Scope
**In:**
- Enable Google via `omniauth_providers` config.
- Google OAuth credentials in Rails encrypted credentials.
- `bundle install` for the OmniAuth gems.
- Test coverage for new-user sign-up and returning-user login.

**Deferred / intentionally not built:**
- Any other providers (GitHub, Facebook, Microsoft, Twitter).
- Softening the existing-email rejection flow — keeping JSP's default
  anti-account-takeover behavior by explicit decision.
- Requesting additional Google scopes beyond `openid`, `email`, `profile`.
- Custom styling of the provider button.

## Open Questions
None.

## More Info
- **Credentials handoff:** Google Client ID + Secret were provided and stashed in
  the gitignored `.context/google-oauth-credentials.txt` for the execute step.
  They must go into Rails encrypted credentials (`bin/rails credentials:edit`),
  never into a committed file. Delete the scratch file once stored.
- **Google Cloud Console setup (done by user):** External consent screen, app
  "Cove", non-sensitive scopes (`openid`/`email`/`profile`, no verification
  review needed), Web application OAuth client with authorized redirect URIs
  `https://covehomeschool.com/users/auth/google_oauth2/callback` and
  `http://localhost:3000/users/auth/google_oauth2/callback`.
- **Button gating:** `Jumpstart::Omniauth.enabled?` requires both the provider in
  config AND present credentials, so the button won't render until credentials
  are in place. In test env, Devise registers `config.omniauth :developer`, so
  tests should drive the flow with OmniAuth's mock/test mode rather than real
  Google credentials.
- **Config surface:** `config/jumpstart.rb` `omniauth_providers` array;
  `Gemfile.jumpstart` gem loading; `config/initializers/devise.rb` auto-registers
  enabled providers; `config/routes/users.rb` already mounts omniauth callbacks
  when OmniAuth is defined.
