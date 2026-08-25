> Ticket: COV-63
> Branch: feature/cov-63-capture-marketing-consent-on-google-oauth-signup
> Plan created: docs/plans/cov-63-oauth-marketing-consent.md

# Feature: Capture marketing consent on Google OAuth signup

## Problem

The marketing checkbox lives only in the Devise registration form
(`app/views/devise/registrations/new.html.erb:78`). The Google button is a
separate `button_to` in `app/views/devise/shared/_links.html.erb:10`, rendered on
both the sign-up and sign-in pages, so the checkbox never rides along. A user who
signs up with Google records no consent, gets no Loops contact, and can never
receive lifecycle mail — and a later settings toggle deliberately emits no
`user_signed_up` event (COV-54), so there is no recovery path.

## Approach

Treat OAuth account creation and marketing consent as separate choices. Signing
in with Google proves identity and supplies an email address; it must not imply
a subscription.

A one-time completion screen is shown after an OAuth-created account signs in.
It confirms the user's name, offers an unchecked marketing checkbox with a
privacy-policy link, and proceeds on a single **Continue** button whether or not
the box is ticked.

An interstitial rather than a checkbox on the registration page, because the
Google button also appears on the **sign-in** page — a new user arriving that way
would otherwise never be asked.

Consent granted here calls the existing
`grant_marketing_consent(source: "registration")`, so the whole downstream chain
fires unchanged with no new code: `after_update_commit :enqueue_contact_sync` →
`LoopsContactSyncJob(id, "opt_in")` → contact upsert → `user_signed_up` event
(`app/jobs/loops_contact_sync_job.rb:19`). **No Loops-side work is required**;
COV-55's welcome workflow is already compatible.

### Where this plugs into existing code

- `Jumpstart::Omniauth::Callbacks#create_user`
  (`lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb:63`) is the **only** branch
  that creates a `User`. Every other branch — `handle_previously_connected`,
  `attach_account`, and the `User.exists?(email:)` rejection — creates no user.
  Flagging inside `create_user` therefore gives "existing accounts are never
  prompted" for free, with no extra conditionals.
- `Users::AgreementUpdates`
  (`lib/jumpstart/app/controllers/concerns/users/agreement_updates.rb`) is the
  existing in-repo interstitial pattern: an `ApplicationController`
  `before_action` on `request.get? && user_signed_in? && !devise_controller?`
  that stores the location and redirects to a `layout "minimal"` screen. The new
  gate copies this shape. Note that
  `Rails.application.config.agreements` is currently an **empty array** (all
  entries in `config/initializers/agreements.rb` are commented out), so the
  existing agreements gate is a no-op today and the two cannot collide.
- Editing vendored Jumpstart code under `lib/jumpstart/` is established practice
  in this repo — COV-49 modified
  `lib/jumpstart/app/controllers/users/registrations_controller.rb` and
  `lib/jumpstart/app/controllers/concerns/authentication.rb`.

## Acceptance Criteria

- An OAuth-created user is shown the prompt exactly once; a persistent flag
  records that we asked, so declining does not re-prompt.
- The checkbox is unchecked by default (COV-48 Decision 4 — no pre-checked
  opt-in anywhere) and is visibly optional.
- A privacy-policy link is present next to the checkbox.
- Continue completes the signup whether or not the box is ticked; nothing blocks
  access to the product.
- Accepting sets `marketing_opt_in_at` and `marketing_opt_in_source =
  "registration"`, syncs the Loops contact, and emits `user_signed_up`.
- Declining writes no consent record and creates no Loops contact.
- Users signing in with OAuth to an existing account are never prompted.
- Existing email/password registration is unchanged.
- A Google account with no name no longer 500s the OAuth callback.
- `/privacy` renders real, accurate content instead of a placeholder.
- The Google Cloud OAuth client's public configuration carries an accurate
  privacy-policy URL and Google-user-data disclosure; marketing is disclosed
  separately and never implied by the Google authorization.
- `bin/rails test` passes and `bin/rubocop` is clean.
- The final `git diff` is reviewed, and any unrelated Rails 8.1 schema-dump
  reordering in the four known schema files is reverted (AGENTS.md gotcha).

### Deliberate departures from the ticket, with reasoning

1. **Single Continue, no Skip.** COV-63 specifies "Both Continue and Skip
   complete the signup." With an unchecked box, Continue and Skip are
   byte-for-byte the same outcome, and two buttons that differ only when the box
   is ticked make people hunt for a difference that isn't there. The underlying
   intent — *neither blocks access to the product* — is fully met by one
   Continue that honors the checkbox either way. Recorded here so
   `/review-changes` finds a decision rather than an apparent miss.
2. **The screen also confirms the user's name.** See "Screens / Flows"; this is
   real value rather than scope creep, because `has_person_name` splits Google's
   `auth.info.name` naively.

## Prototype

None. The screen uses the existing `minimal` layout and catalog components; no
new component is built and no existing layout is rearranged.

## Data Model

### One new column on `users`

| Column | Type | Default | Null |
| --- | --- | --- | --- |
| `signup_completion_required` | `boolean` | `false` | `null: false` |

**Why this polarity.** The obvious shape is `marketing_prompted_at` (nil = still
owed). It is wrong here: nil is also what every existing row, fixture, seed,
invited user, and future `User.create` gets by default, so nil-means-pending
would gate the app for everyone and would require both a backfill migration and
a standing discipline that every future creation path stamps it. Forgetting
would mean wrongly prompting someone.

`signup_completion_required` inverts that. Defaulting to `false` makes every
existing row, fixture, seed, and non-OAuth path correct with **no backfill and no
migration data step**; exactly one line inside `create_user` opts a user in. The
failure mode of forgetting is *not prompting*, which is the safe direction for an
optional screen.

**A boolean, not a timestamp.** COV-48 makes `marketing_opt_in_at` +
`marketing_opt_in_source` the audit artifact, and declining is defined as writing
nothing. There is no audit value in recording when we began owing someone a
screen, so a two-state gate is the honest type.

**No index.** The gate reads `current_user.signup_completion_required?` off an
already-loaded record and never queries by the column.

### No changes to the four marketing columns, and no new opt-in source

Consent granted on this screen calls the existing
`grant_marketing_consent(source: "registration")`. `"registration"` is already in
`User::MarketingConsent::MARKETING_OPT_IN_SOURCES`.

This matters more than it looks. Inventing an `oauth_completion` source would
fall outside `LoopsContactSyncJob`'s
`user.marketing_opt_in_source == "registration"` condition and would silently
stop `user_signed_up` firing — that event is COV-55's live workflow trigger.
Reusing `registration` is also simply accurate: this *is* the user's
registration.

### No new model concern

Rails provides `signup_completion_required?` for free. Wrapping one boolean in a
concern would be ceremony. `User::MarketingConsent` is untouched.

### Fixtures

One new intent-named record in `test/fixtures/users.yml` —
`oauth_signup_pending`, with `signup_completion_required: true` — following the
repository's fixtures-only convention (hand-written literals, associations by
label, no FactoryBot/Faker). Every other fixture inherits `false` from the column
default, so no existing fixture changes.

## Screens / Flows

### The happy path

1. New user clicks "Continue with Google" on the sign-up **or** sign-in page.
2. Google authorizes → `Users::OmniauthCallbacksController#google_oauth2` → falls
   through to `create_user`.
3. `create_user` builds the `User` + `ConnectedAccount` and signs them in.
   `signup_completion_required` is set to `true` here.
4. JSP's existing `sign_in_and_redirect` sends them to the dashboard exactly as
   it does today — **the redirect is not overridden**. On that GET the
   `ApplicationController` gate sees the flag, stores the intended location, and
   redirects to the completion screen. One mechanism, not two; a user who closes
   the tab gets the screen on their next sign-in instead of losing it forever.
5. Completion screen (below).
6. Continue → save name → grant consent if ticked → clear the flag → redirect to
   `stored_location_for(:user) || root_path`.
7. Consent granted fires the existing sync/event chain with no new code.

### Paths that must never see the screen

All fall out of setting the flag only inside `create_user`:

| Path | Branch in `callbacks.rb` | Flagged? |
| --- | --- | --- |
| Returning Google user signing in | `handle_previously_connected` | No |
| Signed-in user connecting Google from settings | `attach_account` | No |
| Existing email/password account tries Google | `User.exists?` → rejected, no user created | No |
| Email/password registration | never reaches this controller | No |
| Invited user | devise_invitable creates the row at invite time, so Google hits the "account exists" rejection | No |

### Route and controller

- `resource :signup_completion, only: [:show, :update], module: :users` in
  `config/routes/users.rb` → `/signup_completion`.
- `Users::SignupCompletionsController < ApplicationController`, `layout
  "minimal"`, with `skip_before_action :require_signup_completion!` — the same
  self-exclusion `Users::AgreementsController` uses, so the gate cannot redirect
  to itself.

### The screen

Centered in the `minimal` layout, `sm:max-w-sm` like the auth pages:

```
Finish setting up your account
You're signed in with Google. Confirm your name below.

Email
you@example.com                    <- plain muted text, not an input

First name  [ Mary Jo          ]   <- required
Last name   [ Van Der Berg     ]   <- optional

[ ] Send me occasional Cove updates and homeschooling resources.
    Optional. Change this any time in settings. Privacy Policy

[         Continue          ]
```

Components, all from `docs/COMPONENT_CATALOG.md` — nothing new is built:

- `FormFieldComponent` + `f.text_field` for first/last name, composed the way
  `devise/registrations/new.html.erb` already does it.
- `CheckboxComponent` with `label:` carrying the consent sentence and
  `description:` carrying `t(".marketing_hint_html")`. Because it is an `_html`
  key, Rails marks it safe and the privacy link renders through the component's
  otherwise-escaped `description` slot (`app/components/checkbox_component.html.erb:20`).
  This keeps the label a clean consent statement instead of cramming a link into
  it the way the terms checkbox has to.
- `ButtonComponent` — `type: "submit"`, `full_width: true`,
  `data: {disable_with: …}`.
- Errors via the existing `devise/registrations` `_error_messages` partial.

**Email renders as text, not a disabled input.** A disabled field implies
"editable somewhere," and this one never is — it is the OAuth identity that
`ConnectedAccount` matches on and that Loops maps `userId` → email with.

**Copy.** The checkbox label reuses COV-49's registration wording: "Send me
occasional Cove updates and homeschooling resources." The privacy link points at
`privacy_path` with `target: "_blank"`, matching the terms checkbox.

### Three details that satisfy specific criteria

- **Unchecked by default, with the hidden `"0"`.** An explicit
  `hidden_field_tag "user[marketing_opt_in]", "0"` immediately precedes the
  checkbox. `CheckboxComponent` does not emit Rails' unchecked-value field, so
  without it the param vanishes entirely when unchecked (AGENTS.md gotcha; COV-49
  hit this).
- **"Visibly optional"** is carried by the description line rather than an
  "(optional)" suffix, and the button says "Continue," not "Subscribe" — the
  primary action is never the consent action.
- **`checked:` renders `current_user.marketing_subscribed?`**, not a hard
  `false`. That evaluates to `false` for every real OAuth signup, so
  "unchecked by default" holds, while not lying to a user who reached the
  settings toggle first (see Edge Cases).

### Form, params, and save order

`form_with(model: current_user, url: signup_completion_path, method: :patch)`.

`update` permits **only** `first_name` and `last_name`. It reads
`params[:user][:marketing_opt_in] == "1"` separately and calls
`grant_marketing_consent(source: "registration")` itself, so the browser never
supplies provenance — the same principle `MarketingPreferencesController` already
enforces.

**Save order is load-bearing:** name first → then consent → then clear the flag.

- Name before consent, because granting consent fires
  `after_update_commit :enqueue_contact_sync` → `LoopsContactSyncJob`, which
  reads the user's name to build the Loops contact. Reversed, the pre-correction
  name would be synced.
- Flag cleared last, so if anything upstream fails the user sees the screen again
  rather than losing the prompt silently.

### Passive terms/privacy disclosure under the Google button

`app/views/devise/shared/_links.html.erb` gains a short line under the provider
buttons: "By continuing, you agree to the Terms and Privacy Policy."

This is in scope because it directly serves the ticket's disclosure criterion —
marketing is disclosed separately, on its own screen, and never implied by the
Google authorization. It is deliberately **passive text, not a checkbox**:
COV-48 Decision 4 refused a marketing checkbox on the invitation-accept form
precisely because that form carries a mandatory terms tick, and "stacking
marketing consent onto an acceptance the user must tick to proceed is bundled
consent." A required terms checkbox next to the optional marketing checkbox on
the completion screen would recreate exactly that, so it is not there.

### Privacy policy content

`app/views/users/agreements/_privacy_policy.html.erb` is currently a 7-line
placeholder ("Some suggestions to help create your Privacy Policy"), so `/privacy`
renders nothing and the required privacy link would point at a blank page.

This ticket writes plain-language content accurate to what Cove actually does,
verified against the codebase:

- Google OAuth (`omniauth_providers: ["google-oauth2"]`) — email, name, and
  profile only; scopes `openid`, `email`, `profile`.
- Stripe for payments (`payment_processors: ["stripe"]`, via the Pay gem).
- Loops for transactional and marketing email.
- Honeybadger for error monitoring (`integrations: ["honeybadger"]`).
- Disk-backed ActiveStorage for avatars (`config.active_storage.service = :local`).
- **No analytics or advertising trackers** — grepped for plausible/fathom/GA/
  gtag/posthog/segment across `app/views` and `config`; there are none. Worth
  stating plainly.
- Business name and postal address from `config/jumpstart.rb`: Cove,
  307 N 990 E, Salem, UT 84653. Support: support@covehomeschool.com.
- Account deletion deletes the Loops contact (COV-48 Decision 5).

Two constraints on this work:

- **This is not legal advice.** It is honest, readable content describing real
  behavior and should be reviewed before launch.
- **Privacy only, not terms.** `_terms_of_service.html.erb` remains a
  placeholder; terms is a different document with different risk and is not in
  this ticket.

`config/initializers/agreements.rb` stays as-is (both `Agreement.new` entries
commented out), so writing the policy triggers no re-acceptance prompt.

### The missing-name fix

`create_user` currently does `name: auth.info.name`, and `User::Profile` has
`validates :name, presence: true`, so a Google account with no name raises at
`save!` and 500s the callback before the completion screen is ever reached.

Fix in `lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb`: fall back to the
structured `auth.info.first_name` / `auth.info.last_name`, then to the email's
local part. `info.email` is guaranteed across OmniAuth providers, so this stays
provider-agnostic rather than Google-specific. Mark it with an `AIDEV-NOTE` so a
future Jumpstart upgrade sees the local modification.

## Edge Cases

### The gate

| Situation | Behavior |
| --- | --- |
| Closes the tab on the completion screen | Flag persists; screen returns on the next GET after sign-in |
| Arrives via a deep link while pending | `store_location_for(:user, request.fullpath)`, then Continue returns them there — **guarded so `/signup_completion` never stores itself**, mirroring `AgreementUpdates`' `unless request.fullpath.start_with?("/agreements/")` |
| Visits `/signup_completion` when not pending | Redirect to root, so a stale bookmark cannot re-show it |
| Visits it signed out | `authenticate_user!` → sign-in page |
| Two tabs, both submit | The second finds the flag already cleared and redirects to root |
| Non-GET requests while pending | **Not blocked** — same as `AgreementUpdates`. Blocking them would break sign-out, and a brand-new user has nothing else to POST to |
| Blank first name on submit | Re-render `:show`, `:unprocessable_entity`, checkbox state preserved from params |
| Admin impersonating a pending user | Sees the screen. Harmless; not worth a special case |
| API request from a pending user | Not gated — `Api::BaseController` inherits `ActionController::API`, not `ApplicationController`. Correct: consent must never block product access |
| Hotwire Native | Hits the same HTML routes and sees the screen; the `minimal` layout already handles `hotwire_native_app?` |

### Consent and Loops

- **Loops job fails after consent.** `LoopsContactSyncJob` includes
  `LoopsRetryable`, so it retries. The redirect has already happened; the user is
  never blocked on an outbound HTTP call.
- **Dev and staging.** `contact_sync_enabled` is false outside production
  (COV-48 Edge Cases), so consent columns write normally while every Loops call
  no-ops. The whole flow can be exercised on staging without writing test
  contacts into the production audience.
- **Settings toggle reached before completing.** Devise controllers are excluded
  from the gate, so a pending user can reach `/users/edit` and opt in there
  first. The checkbox reflects that via `checked: marketing_subscribed?`. If they
  did, their source stays `"settings"` and `user_signed_up` will not fire. This
  is recorded, not built for: it requires deliberately navigating to settings
  mid-prompt, and the only consequence is not receiving COV-55's welcome email.

### Pre-existing issues deliberately not fixed here

Recorded so they are not later mistaken for regressions introduced by this
ticket:

- Google returning no `email` still raises in `create_user`. Google always
  returns email with the `email` scope, so this is theoretical.
- OAuth users still get `accepted_terms_at` / `accepted_privacy_at` stamped by
  `User::Agreements` without having seen either document —
  `create_user` passes `terms_of_service: true` on their behalf. The passive
  disclosure line mitigates it; properly fixing it is its own ticket.

## Google Cloud Console (manual, operator-performed)

Not code. Values to set on the existing OAuth client / consent screen:

- **Privacy policy URL:** `https://covehomeschool.com/privacy` — set this only
  after the policy content ships.
- **Application terms-of-service URL:** leave **unset**.
  `_terms_of_service.html.erb` is still a placeholder, and pointing Google's
  consent screen at a blank page is worse than an empty field.
- **Scopes:** unchanged — `openid`, `email`, `profile`. Non-sensitive, so no
  verification review is required (COV-5).
- **Google-user-data disclosure:** satisfied by the privacy policy stating what
  Google-supplied data is collected (email, name, profile), that it is used to
  operate the account, and that it is **not** used for marketing without separate
  consent.
- **"Marketing never implied by the Google authorization"** is satisfied
  structurally: consent is captured on a separate screen *after* authorization,
  by an unchecked, optional control.

## Scope

**In:**

- One migration adding `signup_completion_required` to `users`.
- Flag set inside `Jumpstart::Omniauth::Callbacks#create_user`.
- `Users::SignupCompletion` controller concern (the gate) included in
  `ApplicationController`.
- `Users::SignupCompletionsController` + `show` view + route.
- Locale keys for the screen's copy.
- Passive terms/privacy line under the provider buttons in
  `devise/shared/_links.html.erb`.
- Privacy policy content in `app/views/users/agreements/_privacy_policy.html.erb`.
- Missing-name fallback in `create_user`.
- `oauth_signup_pending` user fixture.
- Tests (below).

**Deferred / out:**

- Terms of service content.
- Fixing the implicit terms acceptance on OAuth signup.
- Time zone capture, Google avatar import, or any other onboarding field — Cove
  has no domain models yet, so there is nothing product-specific to onboard into.
- Any Loops-side configuration or workflow change; COV-55 is already compatible.
- A Skip button (see "Deliberate departures").
- Backfilling or prompting existing users — there are none, and the column
  default handles them anyway.

## Tests

Fixtures-only, no new gems.

- **Integration:** OAuth signup sets the flag; returning connected user's sign-in
  does not; connecting Google while signed in does not; email/password
  registration does not. Drive with OmniAuth's `:developer` mock, following
  `test/integration/jumpstart/omniauth_callbacks_test.rb`.
- **Integration:** a pending user is redirected from a normal GET; completing
  clears the flag and returns them to the stored location; a second sign-in does
  not re-prompt.
- **Controller:** checked → `marketing_opt_in_at` set, `marketing_opt_in_source
  == "registration"`, `LoopsContactSyncJob` enqueued with `"opt_in"`; unchecked →
  all four consent columns still null and **no job enqueued**.
- **Event:** `assert_enqueued_with(job: LoopsEventJob, args: [user.id,
  "user_signed_up"])` through `LoopsContactSyncJob`, matching the existing
  assertions in `test/jobs/loops_contact_sync_job_test.rb`.
- **Rendered form:** unchecked by default, hidden `"0"` present, privacy link
  present.
- **Missing name:** an OmniAuth mock with no name does not raise.
- **Migration:** existing rows default to `false`.

Run with `export PATH="$HOME/.local/share/mise/shims:$PATH"` first (AGENTS.md).

## Open Questions

1. **Prefer Google's structured `first_name` / `last_name` over splitting
   `auth.info.name`?** `has_person_name` splits on the first space, so
   "Mary Jo Van Der Berg" becomes first name "Mary", last name "Jo Van Der
   Berg", while Google returns the two fields correctly. It is about two lines.
   Raised during brainstorming and left unanswered; **not currently in scope**,
   because the completion screen already shows first and last as separate
   editable fields, so a bad split is visible and user-fixable. Decide before
   `/write-plan` if you want it in.

## More Info

- **`user_signed_up` fires only when `marketing_opt_in_source == "registration"`**
  (`app/jobs/loops_contact_sync_job.rb:19`). This is the single most important
  constraint on this ticket: it is what makes reusing the `registration` source
  mandatory rather than merely convenient.
- **COV-48 Decision 4** forbids pre-checked opt-in anywhere, and forbids bundling
  marketing consent into a mandatory acceptance. Both shape this design.
- **COV-48 Decision 3** — contacts are created only on opt-in, so declining
  correctly leaves no Loops contact at all; the *absence* of a contact is the
  evidence nobody was mailed without agreeing.
- **`Users::AgreementsController`** (`lib/jumpstart/app/controllers/users/agreements_controller.rb`)
  is the closest working reference for the new controller: `layout "minimal"`,
  `skip_before_action`, `stored_location_for(:user) || root_path`.
- **AGENTS.md gotchas that apply here:** `CheckboxComponent` needs the explicit
  hidden `"0"`; do not run RuboCop directly on `.erb` paths; `bin/rails
  db:migrate` regenerates four schema dumps with unrelated reordering that must
  be reverted before committing.
