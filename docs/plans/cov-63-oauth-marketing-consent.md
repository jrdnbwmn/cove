> Ticket: COV-63
> Branch: feature/cov-63-capture-marketing-consent-on-google-oauth-signup

# Plan: Capture marketing consent on Google OAuth signup

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Replace the privacy placeholder with accurate Cove policy content | Master | |
| 2 | 1 | 1 | Add passive Terms and Privacy disclosure below Google OAuth | subagent | |
| 3 | 2 | 2 | Add persistent OAuth signup-completion state | Master | |
| 4 | 2 | 2 | Flag only new OAuth users and handle missing Google names | Master | |
| 5 | 2 | 3 | Add the authenticated GET gate and singular route | Master | |
| 6 | 2 | 3 | Build and test the signup-completion endpoint and screen | subagent | |
| 7 | 3 | 4 | Run release verification and prepare the Google Console handoff | Master | |

## Prerequisites

- Design: [`docs/designs/cov-63-oauth-marketing-consent.md`](../designs/cov-63-oauth-marketing-consent.md)
- Prototype: None
- Feature branch exists: `feature/cov-63-capture-marketing-consent-on-google-oauth-signup`
- Before Rails commands: `export PATH="/Users/jordan/.local/share/mise/shims:$PATH"` and confirm `mise exec -- ruby -v` reports Ruby 4.0.5.
- Component catalog scanned: `ButtonComponent`, `FormFieldComponent`, and `CheckboxComponent` cover the screen; no new component is required.
- Policy wording must receive human review before launch. It must not claim an exact Google scope set unless the operator verifies the live OAuth configuration. The locked gem defaults to `email,profile`, credentials may override scopes, and Cove stores a sanitized OAuth payload beyond only email/name.

## Tasks

## Phase 1: Public OAuth disclosures

### Task 1 [Master]: Publish accurate privacy-policy content

**Skills:** write-tests, style-ui
**Reference:** Read [`lib/jumpstart/app/views/public/privacy.html.erb`](../../lib/jumpstart/app/views/public/privacy.html.erb), [`config/jumpstart.rb`](../../config/jumpstart.rb), [`config/environments/production.rb`](../../config/environments/production.rb), and [`lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb`](../../lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb) for rendered structure and current data handling
**Prototype:** None — preserve the existing public-policy layout

**In scope:**

- Replace the placeholder in `app/views/users/agreements/_privacy_policy.html.erb` with readable sections covering collected account/OAuth data, use, Stripe, Loops, Honeybadger, avatars, consent choices, deletion, security, and Cove contact details.
- State that Google-supplied data operates the account and is not used for marketing without separate consent.
- Describe Google data broadly enough to cover the persisted sanitized OAuth payload; do not say Cove stores “only” email/name/profile.
- State that no analytics or advertising trackers are currently present, based on the repository's configuration and views.

**NOT in scope:**

- Terms-of-service content, legal conclusions, agreement re-acceptance, OAuth storage changes, or exact Google scope claims.
- Changes to `config/initializers/agreements.rb` or the existing public-page layout.

**Build order:**

1. **Test:** Extend `test/integration/public_test.rb` to request `/privacy`, assert substantive provider/consent/contact sections, and prove the placeholder text is absent.
2. **Implement:** Write the policy in `app/views/users/agreements/_privacy_policy.html.erb` using semantic headings, paragraphs, and lists without inline styles.
3. **Verify:** `mise exec -- bin/rails test test/integration/public_test.rb`

### Task 2 [subagent]: Add passive disclosure below Google OAuth

**Skills:** write-tests, style-ui
**Reference:** Follow the provider guard in [`app/views/devise/shared/_links.html.erb`](../../app/views/devise/shared/_links.html.erb) and the sign-in/sign-up coverage in [`test/integration/users/google_oauth_test.rb`](../../test/integration/users/google_oauth_test.rb)
**Prototype:** None — preserve the existing OAuth button and auth-page hierarchy

**In scope:**

- Render “By continuing, you agree to the Terms and Privacy Policy” after the provider-button grid on both sign-in and sign-up.
- Add shared Devise locale copy with links to `terms_path` and `privacy_path`, opening in a new tab.
- Keep marketing absent from this disclosure because it is requested separately after authorization.

**NOT in scope:**

- A mandatory terms checkbox, changes to the Google button, terms content, or marketing consent on the Devise pages.

**Build order:**

1. **Test:** Extend `test/integration/users/google_oauth_test.rb` to assert the disclosure and both policy links on `/users/sign_in` and `/users/sign_up`.
2. **Implement:** Update `app/views/devise/shared/_links.html.erb` and `config/locales/devise.en.yml` within the existing OmniAuth guard.
3. **Verify:** `mise exec -- bin/rails test test/integration/users/google_oauth_test.rb`

After Tasks 1–2 finish, run `review-changes-mini` once for checkpoint 1. If they run as a parallel batch, the Master runs the review after both return.

## Phase 2: OAuth signup-completion flow

### Task 3 [Master]: Add persistent signup-completion state

**Skills:** safe-migration, write-tests
**Reference:** Follow [`db/migrate/20260803200832_add_marketing_consent_to_users.rb`](../../db/migrate/20260803200832_add_marketing_consent_to_users.rb), [`test/migrations/add_marketing_consent_to_users_test.rb`](../../test/migrations/add_marketing_consent_to_users_test.rb), and the intent-named records in [`test/fixtures/users.yml`](../../test/fixtures/users.yml)

**In scope:**

- Generate a migration adding `users.signup_completion_required` as boolean, `default: false`, `null: false`, with no index or backfill.
- Add `test/migrations/add_signup_completion_required_to_users_test.rb` asserting the column contract and that existing/default users are not pending.
- Add the `oauth_signup_pending` fixture with the flag set to `true`.
- Retain the intentional `db/schema.rb` update.

**NOT in scope:**

- Changes to the four marketing-consent columns, a timestamp, a model concern, data backfill, or secondary-database schemas.

**Build order:**

1. **Test:** Add the migration contract test first and run it to demonstrate the missing column.
2. **Implement:** Run `mise exec -- bin/rails generate migration AddSignupCompletionRequiredToUsers signup_completion_required:boolean`, add the constraints, migrate, update `db/schema.rb`, and add the fixture.
3. **Verify:** `mise exec -- bin/rails db:migrate && mise exec -- bin/rails db:rollback:primary STEP=1 && mise exec -- bin/rails db:migrate && mise exec -- bin/rails test test/migrations/add_signup_completion_required_to_users_test.rb`

Inspect all four schema files afterward and revert only unrelated Rails 8.1 reordering/version noise from cable, cache, and queue schemas.

### Task 4 [Master]: Flag new OAuth users and handle missing names

**Skills:** write-tests
**Reference:** Follow the branch structure in [`lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb`](../../lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb) and existing cases in [`test/integration/jumpstart/omniauth_callbacks_test.rb`](../../test/integration/jumpstart/omniauth_callbacks_test.rb)

**In scope:**

- Test that only `create_user` sets `signup_completion_required: true`.
- Test that returning connected users, signed-in connection flows, and email/password registration remain unflagged.
- Test an explicit nil `name`, `first_name`, and `last_name` OAuth payload and fall back to the email local part without raising.
- Prefer a present `auth.info.name`; only then fall back to joined structured names and finally the email local part.
- Add an `# AIDEV-NOTE:` marking the local vendored Jumpstart modification.

**NOT in scope:**

- Reordering structured names ahead of a present full name, changing other OAuth branches, handling missing Google email, or changing implicit agreement acceptance.

**Build order:**

1. **Test:** Update `test/integration/jumpstart/omniauth_callbacks_test.rb` and `test/controllers/users/registrations_controller_test.rb` with the creation-path, returning-user, connection, password-registration, and missing-name cases.
2. **Implement:** Update only `Jumpstart::Omniauth::Callbacks#create_user` in `lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb`.
3. **Verify:** `mise exec -- bin/rails test test/integration/jumpstart/omniauth_callbacks_test.rb test/controllers/users/registrations_controller_test.rb`

After Tasks 3–4 finish, run `review-changes-mini` once for checkpoint 2.

### Task 5 [Master]: Add the shared signup-completion gate and route

**Skills:** write-tests
**Reference:** Follow [`lib/jumpstart/app/controllers/concerns/users/agreement_updates.rb`](../../lib/jumpstart/app/controllers/concerns/users/agreement_updates.rb), [`lib/jumpstart/app/controllers/users/agreements_controller.rb`](../../lib/jumpstart/app/controllers/users/agreements_controller.rb), and [`app/controllers/application_controller.rb`](../../app/controllers/application_controller.rb)

**In scope:**

- Add `app/controllers/concerns/users/signup_completion.rb` with `require_signup_completion!`.
- Gate only signed-in, non-Devise GET requests when `current_user.signup_completion_required?`.
- Store the intended path unless it starts with `/signup_completion`, then redirect to `signup_completion_path`.
- Include the concern in `ApplicationController`.
- Add `resource :signup_completion, only: [:show, :update], module: :users` to `config/routes/users.rb`.
- Add `test/integration/users/signup_completion_gate_test.rb` for pending, ordinary, Devise, and non-GET behavior.

**NOT in scope:**

- API gating, JSON behavior, blocking sign-out or other non-GET requests, changing the existing agreement gate, or redirecting directly from the OAuth callback.

**Build order:**

1. **Test:** Add gate tests proving pending users are redirected from a normal GET, ordinary users are unaffected, Devise pages remain reachable, and sign-out is not blocked.
2. **Implement:** Add the concern, include it in `ApplicationController`, and define the singular route.
3. **Verify:** `mise exec -- bin/rails test test/integration/users/signup_completion_gate_test.rb`

### Task 6 [subagent]: Build the signup-completion endpoint and screen

**Skills:** write-tests, style-ui
**Reference:** Follow [`lib/jumpstart/app/controllers/users/agreements_controller.rb`](../../lib/jumpstart/app/controllers/users/agreements_controller.rb), [`app/controllers/marketing_preferences_controller.rb`](../../app/controllers/marketing_preferences_controller.rb), and [`app/views/devise/registrations/new.html.erb`](../../app/views/devise/registrations/new.html.erb)
**Prototype:** None — use the existing `minimal` layout and auth-page width/hierarchy exactly as designed

**In scope:**

- Add `Users::SignupCompletionsController` with authentication, `layout "minimal"`, self-exclusion from the gate, and stale/two-tab redirects.
- Permit only `first_name` and `last_name`; read the checkbox separately and supply `"registration"` provenance server-side.
- Enforce a nonblank first name locally because the model validates combined `name`, and preserve the submitted checkbox when re-rendering a 422.
- In one transaction, save the name, grant consent when checked, then clear the flag last; redirect to `stored_location_for(:user) || root_path`.
- Build the form with email text, `FormFieldComponent`, explicit hidden `"0"`, `CheckboxComponent`, privacy link, `ButtonComponent`, and existing error partial.
- Add screen locale keys and controller coverage for authentication, stale visits, rendering, invalid name, checked/unchecked outcomes, job/no-job behavior, stored redirects, and duplicate submission.

**NOT in scope:**

- A Skip button, editable email, new components, new consent provenance, model/Loops job changes, or blocking product access when consent is declined.

**Build order:**

1. **Test:** Add `test/controllers/users/signup_completions_controller_test.rb` covering the full render and submission contract, including `LoopsContactSyncJob(id, "opt_in")` and no job when unchecked.
2. **Implement:** Add `app/controllers/users/signup_completions_controller.rb`, `app/views/users/signup_completions/show.html.erb`, and `config/locales/en.yml`.
3. **Verify:** `mise exec -- bin/rails test test/controllers/users/signup_completions_controller_test.rb test/jobs/loops_contact_sync_job_test.rb`

After Tasks 5–6 finish, run `review-changes-mini` once for checkpoint 3.

## Phase 3: Release readiness and operator handoff

### Task 7 [Master]: Run final verification and prepare the Google configuration handoff

**Skills:** review-changes-mini
**Reference:** Follow the testing, mise, schema-drift, and user-owned dashboard rules in `AGENTS.md`

**In scope:**

- Run the complete Rails suite, RuboCop, focused route/render checks, and final diff inspection.
- Confirm existing email/password registration and Loops event-chain tests still pass.
- Confirm only the intended primary schema change remains.
- Prepare exact post-deploy Google Cloud instructions: verify live `/privacy`, set the privacy-policy URL to `https://covehomeschool.com/privacy`, leave the terms URL unset, leave scopes unchanged, and confirm Google data and separate-marketing-consent disclosures.
- Record the Google Console action as a required post-deploy operator step; the user performs it and returns only non-secret confirmation.

**NOT in scope:**

- Agent-controlled Google Console changes, entering or exposing OAuth credentials, deployment, merging, Loops configuration, or unrelated cleanup.

**Build order:**

1. **Test:** Run `mise exec -- bin/rails test` and `mise exec -- bin/rubocop`.
2. **Implement:** Fix only task-scoped failures; inspect the four schema dumps and revert only known unrelated Rails 8.1 dump noise.
3. **Verify:** Run `git diff --check`, `git status --short`, and `git diff origin/main...`; confirm every acceptance criterion is either verified in code or explicitly listed as the post-deploy Google operator action.

Run `review-changes-mini` once for checkpoint 4 after all final checks finish.

## Task Dependencies

- Tasks 1–2 are independent and may run in parallel; both must finish before the public-disclosure phase is considered deployable.
- Task 4 depends on Task 3's column.
- Task 5 depends on Task 3's column and pending-user fixture.
- Task 6 depends on Tasks 3 and 5; it reuses Task 4's OAuth-created pending state but does not change its callback code.
- Task 7 depends on Tasks 1–6.
- The existing `test/jobs/loops_contact_sync_job_test.rb` remains the source of truth that registration-provenance opt-in emits `user_signed_up`; Task 6 verifies the new controller enters that existing chain.
