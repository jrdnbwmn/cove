> Ticket: COV-68
> Branch: feature/cov-68-transactional-account-created-email
> Plan created: docs/plans/cov-68-account-created-email.md

# Feature: Transactional account-created email

## Problem

Cove sends a new user nothing at all after signup. `config/loops.yml` carries
eleven transactional templates — password reset, password change, invite,
cancellation reason, receipt, refund, and five subscription/payment notices —
and none of them says "your account is ready."

There is no confirmation email either: `User` does not include Devise
`:confirmable` (`lib/jumpstart/app/models/user/authenticatable.rb`). A new user
therefore has no record that the account exists and no confirmation of which
address it is on. Because the marketing checkbox is unchecked by default
(COV-48 Decision 4), this silence is the **majority** path, not an edge case.

It also blocks the standard OAuth signup pattern, which sends a transactional
account email regardless of marketing consent and sends marketing only to
opted-in users.

## Approach

One LMX transactional email named `account-created`, on COV-40's shared `Cove`
theme, plus app wiring that follows the pattern `LoopsDeviseMailer` and
`AccountMailer` already established: a bodyless mailer method that sets
`X-Loops-Transactional-Id` and `X-Loops-Data-Variables` and reads its ID via
`loops_transactional_id(...)` from `config/loops.yml`.

The trigger is a single `after_create_commit` on `User`, delivered with
`deliver_later`.

### Why a model callback rather than controller call sites

Both signup paths converge on `User#save` — `Users::RegistrationsController`
through Devise, and `Jumpstart::Omniauth::Callbacks#create_user`
(`lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb:62`) through `user.save!`.
One `after_create_commit` covers both without touching `lib/jumpstart/`.

The controller alternative was considered and rejected. It would give precise
control over what counts as a "signup," but it needs two call sites, one of
which means overriding a vendored Jumpstart method that a JSP upgrade can
change underneath us — and it would still miss Madmin-created users, who
*should* receive this email (Decision 4 below). Once Madmin counts, the trigger
is not "signup" but **user existence**, which is a model fact and belongs on the
model.

The concern mirrors the structure of `User::MarketingConsent`, which already
does exactly this with `after_create_commit :enqueue_contact_opt_in`.

### Why `deliver_later` is required, not merely preferred

`config/application.rb:29` sets
`config.action_mailer.delivery_job = "LoopsMailDeliveryJob"`, and that job
already declares `retry_on LoopsClient::RateLimit, LoopsClient::InternalError,
Net::OpenTimeout, Net::ReadTimeout`. So `deliver_later` satisfies the
"signup succeeds when Loops returns 500" criterion using existing
infrastructure, with no rescue in app code.

`deliver_now` would **fail** that criterion. COV-43 deliberately chose
`deliver_now` for Devise mail so an auth-critical failure is loud; that
reasoning does not transfer here, because a missing account-created email must
never roll back a registration.

`ActionMailer::MailDeliveryJob` declares `rescue_from StandardError, with:
:handle_exception_with_mailer_class`. `LoopsMailDeliveryJob`'s `retry_on`
handlers are registered later and `rescue_handlers` is searched in reverse, so
the subclass's retries still win for the classes it names; everything else
falls through to a re-raise and a failed job. This is the mechanism behind the
whole Edge Cases table.

### Unconditional, and audience-free

The send is independent of `marketing_subscribed?` — it is transactional, so it
reaches email/password and Google OAuth signups alike. It keeps
`addToAudience: false` like every other transactional send (COV-37, COV-39): a
password-reset or account-created recipient consented to *that email*, not to a
marketing audience.

Being ActionMailer-based, it inherits COV-46's `StagingEmailRecipientGuard`
allowlist automatically — unlike the marketing track, which needed its own
`contact_sync_enabled` switch.

Content is product-independent and needs no product brief (all three files in
`docs/product/` are empty): the account is ready, this is the address it is on,
here is how to sign in.

### Decisions taken during design

1. **Invited users receive it, ungated.** `AccountMailer#invite` is about
   *someone else's team*; this email is the user's own record of their account
   and address. Gating would require an `AccountInvitation.exists?(email:)`
   lookup on every signup and a silent behavioral difference that is easy to
   forget.
2. **No name in `dataVariables`.** Exactly `recipient_email` and `sign_in_url`.
   This keeps consistency with COV-40's templates, which greet by email
   address, and with COV-55's finding that no `firstName` reaches Loops.
3. **The CTA points at `new_user_session_url`** (`/users/sign_in`), which
   carries both the password form and the Google button, so it is correct for
   both signup paths.
4. **Madmin-created users receive it.** It is true, and it is the only notice
   they would otherwise get.
5. **No `idempotency_seed`.** See Edge Cases — the constraint is recorded and
   worked around in verification rather than coded around.

## Acceptance Criteria

- An LMX transactional email is authored on the `Cove` theme, previewed in a
  real inbox, and published; its `transactionalId` and exact `dataVariables`
  contract are recorded in this document and added to `config/loops.yml`.
- Creating a user via email/password sends it.
- Creating a user via Google OAuth sends it.
- It sends regardless of marketing consent, and creates no Loops contact
  (`addToAudience: false`).
- It renders correctly with images blocked and in the plain-text alternative.
- Signup succeeds when the Loops endpoint returns 500 — a delivery failure does
  not block registration.
- Staging delivery respects COV-46's recipient allowlist.
- An invited user's registration sends both `account-invite` and
  `account-created`, asserted in a test so the decision cannot be reverted by
  accident.
- `bin/rails test` passes with output shown; `bin/rubocop` is clean.

## Prototype

None. Loops owns the email content and visual presentation; the `Cove` theme
from COV-40 is reused unchanged. No application UI changes.

## Data Model

**No models, migrations, or user fields change.** The only schema-adjacent
change is one new key in `config/loops.yml`.

### External Loops object

| Object | ID | Contract |
| --- | --- | --- |
| `Cove` theme | `cmsdnxho301lh0j17qh8ltsre` | Existing (COV-40). Reused unchanged |
| `account-created` | `cmt95d4t100gq0jyvqpknv5vi` | New. Required `recipient_email`, `sign_in_url` |

Live Loops state confirmed during brainstorming (2026-08-25): the template does
**not** exist. All eleven existing templates sit in the `Unsorted` group
(`cms4sm6bn00mj0jyk7r6nvhmi`), including `account-invite`, `password-changed`,
and `reset-password` — so the new one goes there too. Putting it in the empty
`Account Management` group would be a gratuitous inconsistency. Naming
convention is kebab-case, bare for auth/account and `billing-` prefixed for
billing; `account-created` fits alongside `account-invite`.

### Template contract

| Field | Value |
| --- | --- |
| Loops name | `account-created` |
| Group | `Unsorted` (`cms4sm6bn00mj0jyk7r6nvhmi`) |
| Theme | `Cove`, `cmsdnxho301lh0j17qh8ltsre` |
| Sender | `Cove <notify@covehomeschool.com>` |
| Reply-to | `support@covehomeschool.com` |
| `dataVariables` | exactly `recipient_email`, `sign_in_url` |
| Subject | `Your Cove account is ready` (26 characters) |
| Preview text | `Here's the address it's on, and how to sign in.` |

Body:

> # Your Cove account is ready
>
> You created a Cove account with **{data.recipient_email}**. That's the address
> to sign in with, and where we'll send anything important about your account.
>
> **[ Sign in to Cove ]** -> `{data.sign_in_url}`
>
> If you didn't create this account, just reply to this email and we'll sort it
> out.
>
> — The Cove team

App-side values:

| Key | Source |
| --- | --- |
| `recipient_email` | `user.email` |
| `sign_in_url` | `new_user_session_url` |

### Four deliberate properties of the copy

**The address is in the body sentence, not the greeting.** COV-40's templates
open `Hello {data.recipient_email}`. That pattern is broken here on purpose:
"which address is this account on" is the entire point of this email, and a
greeting line buries the load-bearing fact where readers skip.

**No password-flavored phrasing.** The same email reaches Google OAuth signups,
who have no password — `Jumpstart::Omniauth::Callbacks#create_user` assigns a
random `Devise.friendly_token`. "You created a Cove account" is true for both.

**"Just reply to this email" instead of a `support@` mailto.** Reply-to is
already `support@covehomeschool.com` (COV-40), so the security-notice value
costs zero extra links. Combined with no images, the images-blocked and
plain-text criteria pass **structurally rather than by luck** — the same
technique COV-55 used. The CTA is the only link in the body.

**No `{contact.*}` references anywhere.** Beyond the no-name decision, there is
a mechanical reason: this sends with `addToAudience: false`, so for most
recipients no Loops contact exists at all and every `{contact.*}` token would
resolve empty. `{data.*}` only.

### App-side changes — five files

**1. `config/loops.yml`** — new key under `shared.transactional`, added as the
first entry since account creation precedes every other transactional event:

```yaml
shared:
  transactional:
    account_created: <recorded after publishing>
    reset_password_instructions: cmsdnzduk02k40jx72rv3uwe2
    ...
```

**2. `app/mailers/user_mailer.rb`** (new) — mirrors
`AccountMailer#cancellation_reason`, the existing user-keyed transactional
method:

```ruby
class UserMailer < ApplicationMailer
  include LoopsTransactional

  def account_created
    user = params[:user]
    data_variables = {
      recipient_email: user.email,
      sign_in_url: new_user_session_url
    }

    mail(
      to: email_address_with_name(user.email, user.name),
      from: email_address_with_name(Jumpstart.config.support_email, Jumpstart.config.application_name),
      reply_to: Jumpstart.config.support_email,
      "X-Loops-Transactional-Id": loops_transactional_id(:account_created),
      "X-Loops-Data-Variables": data_variables.to_json,
      body: ""
    )
  end
end
```

A new `UserMailer` rather than a method on `AccountMailer`: `AccountMailer`
would work — `cancellation_reason` already takes `params[:user]` — but in
Jumpstart `Account` is the tenant model, and `AccountMailer#account_created`
would read as "the Account record was created" when the hook is on `User`. One
new file is cheaper than that ambiguity. `Pay::UserMailer` exists but is
namespaced, so there is no collision.

**3. `app/models/user/account_created_email.rb`** (new):

```ruby
module User::AccountCreatedEmail
  extend ActiveSupport::Concern

  included do
    after_create_commit :send_account_created_email
  end

  private

  def send_account_created_email
    UserMailer.with(user: self).account_created.deliver_later
  end
end
```

**4. `app/models/user.rb`** — one line, `AccountCreatedEmail` added to the
include list.

**5. Tests** — see Scope.

### Two notes on the mailer contract

**The `from:` line is decorative, and that is fine.** `LoopsDelivery#deliver!`
reads only `to`, the two `X-Loops-*` headers, and attachments — never `from`.
The real sender is a Loops-side template setting. It is set anyway so the file
does not look like it forgot something.

**`email_address_with_name` is safe for the staging guard.** It produces
`"Jordan" <j@example.com>`, but Mail normalizes `message.to` to bare addresses,
so `StagingEmailRecipientGuard#recipients` compares clean values against the
allowlist, and `LoopsDelivery#recipients` independently re-parses with
`Mail::Address`. This is how `AccountMailer` already works.

**`addToAudience: false` needs no new code and no new test.** It is hardcoded in
`LoopsClient#send_transactional` (`app/clients/loops_client.rb:92`) and already
covered by `test/mailers/loops_delivery_test.rb`. That criterion is inherited.

## Screens / Flows

No application screens change. The user-visible flow is entirely in the inbox.

### Email/password signup

1. The user submits `/users/sign_up`.
2. Devise saves the `User`; `after_create_commit` fires.
3. `UserMailer.with(user:).account_created.deliver_later` enqueues a
   `LoopsMailDeliveryJob`.
4. The registration response proceeds immediately — the send is already
   decoupled from the request.
5. The job builds the bodyless message; `LoopsDelivery` issues one
   `send_transactional` call.

### Google OAuth signup

Identical from step 2. `Jumpstart::Omniauth::Callbacks#create_user` calls
`user.save!`, the same callback fires, and no controller code changes.

### Invited-user signup

`AccountInvitationsController#authenticate_user_with_invite!` redirects a
signed-out invitee to `new_user_registration_path(invite: token)`, and
`Users::RegistrationsController#sign_up` calls `accept!` *after* the user is
saved. So at `after_create_commit` time the invitation has not been accepted
yet. The invitee receives `account-invite` first (at invitation creation,
sometimes days earlier) and `account-created` at registration.

### Execution order is load-bearing

Unlike COV-40 → COV-43, authoring and wiring are the **same** ticket here, and
`config/loops.yml` cannot be filled in until the template is published — Loops
rejects sends that reference an unpublished transactional email. Execution is
strictly: author and publish in Loops → record the ID → then write app code.
App-code tests cannot pass against a real ID until the first step completes.

### Live verification

`render.yaml` still has `cove-production` and `cove-production-db` commented
out, unchanged since COV-55, so **verification is staging-only**, behind
COV-46's allowlist — the same posture as COV-47.

The Loops-side recipe mirrors COV-40: confirm `loops api-key --team cove-cli`
reports `Cove` and never fall back to a production key; re-list transactional
emails immediately before creating, to avoid a duplicate; author the LMX and
require a clean Guardian pass; preview in a real inbox for styled,
images-blocked, and plain-text rendering; confirm the CTA renders a real
absolute URL rather than literal `{data.sign_in_url}` text (COV-40 hit exactly
this); publish, then confirm with `loops transactional get <id>` that it is
published and its `dataVariables` contract is exactly the two; create no
contact, list, campaign, workflow, or second theme.

Two staging constraints follow from the idempotency finding below:

1. **Use two different allowlisted addresses** — one for the email/password run,
   one for the OAuth run.
2. **The OAuth run needs a Google account whose address is on
   `STAGING_EMAIL_RECIPIENT_ALLOWLIST`.** Confirm before execution rather than
   discovering it mid-verification.

### Execution record

- On 2026-09-09, `account-created` (`cmt95d4t100gq0jyvqpknv5vi`) was previewed,
  published, and re-verified with exactly `recipient_email` and `sign_in_url`.
  Guardian returned no warnings or errors.
- The feature commit `c3f23171f29ba6f3ac174b5893bb67a7bf27e0fd` was deployed to
  `cove-staging`. One email/password signup and one Google OAuth signup used
  distinct allowlisted addresses. Both signups succeeded, each email arrived,
  each CTA opened the staging sign-in page, and neither recipient appeared as a
  Loops contact. Recipient values are deliberately not recorded.
- The original free staging database had been deleted after its free-tier
  retention window. A new empty `cove-staging-db` was provisioned in Oregon;
  no credentials are recorded here.
- `cove-staging` was restored to `main`; its successful restore deployment
  reported source `3af4f29` on 2026-09-10.

## Edge Cases

| Case | Behavior |
| --- | --- |
| **Loops returns 500** | `InternalError` is in `LoopsMailDeliveryJob`'s `retry_on` list, retried polynomially. The user committed before the job was enqueued, so signup is already done. Criterion satisfied by `deliver_later` alone |
| **Loops returns 400** (unpublished or wrong transactional ID) | `BadRequest` is not retryable. The job fails once and reports to Honeybadger; signup still succeeded. This is exactly what a deploy-before-publish looks like, which is why the execution order above is load-bearing |
| **Staging, non-allowlisted recipient** | `StagingEmailRecipientGuard::BlockedRecipient` raises inside the job. Not retryable, by COV-46's design. Signup succeeds; one Honeybadger report per non-allowlisted staging signup |
| **Invited user accepting an invitation** | Receives both emails, ungated. Asserted in a test |
| **User destroyed before the job runs** | `deliver_later` serializes by GlobalID; `ActiveJob::DeserializationError` fails the job. Nothing to fix — the recipient no longer exists |
| **`db/seeds.rb`** | Creates five users, so five deliveries enqueue. Development uses `:mailbin`, so no Loops API call is made. `find_or_create_by!` means re-seeding does not re-send |
| **Madmin-created user** | Sends. Decision 4 |
| **User changes email later** | No re-send. Out of scope |

### Silent idempotent suppression — the one that will bite during verification

`LoopsClient#idempotency_key` (`app/clients/loops_client.rb:107`) hashes the
transactional ID, the recipient, and the sorted `dataVariables`. Billing mail
escapes this by passing an `idempotency_seed`; `account_created` does not, so
its key is **purely content-derived — and both of its variables are constant for
a given email address**. `recipient_email` never varies and `sign_in_url` is a
fixed route.

The key for a given address is therefore *the same value forever*. Inside
Loops' roughly 24-hour window (COV-50), a second send to an address that
already received one returns 409, which `send_transactional` logs and treats as
success. Consequences:

- **Delete-and-re-register within a day silently sends nothing.** Narrow in
  production, but real.
- **It will make live verification look broken.** Staging and production share
  one Loops team (COV-46), so verifying against the same address twice in a day
  means the second send silently does not arrive — with a success in the logs.
  This is the same trap COV-55 documented for events, where a reused key "would
  silently fire nothing and look like a broken trigger."

**A per-signup seed was considered and rejected.** It would defeat retry
deduplication, which is the property that makes the 500-retry path safe. The
right response is to record the constraint and use a distinct address per
verification run.

## Scope

**In:** the `account-created` LMX template authored, previewed in a real inbox,
and published; its ID recorded here and in `config/loops.yml`; `UserMailer`;
the `User::AccountCreatedEmail` concern; the one-line `user.rb` change; the
tests below; and an audit of existing tests.

Tests:

| File | Asserts |
| --- | --- |
| `test/mailers/user_mailer_test.rb` (new) | Recipient is the user's email; `X-Loops-Transactional-Id` matches the configured `account_created` ID; `dataVariables` is exactly `recipient_email` + `sign_in_url` with no extras; body is empty and no ERB view is rendered. Following COV-43's precedent, `sign_in_url` is asserted against the real route helper, not a duplicated URL string |
| `test/models/user/account_created_email_test.rb` (new) | Creating a user enqueues exactly one delivery; it *enqueues* rather than delivering inline (the 500-doesn't-block-signup property, asserted directly); it sends with `marketing_opt_in` both true and false; updating a user does not re-send |
| `test/integration/jumpstart/omniauth_callbacks_test.rb` | Google OAuth signup sends it |
| Registration integration test | Email/password signup sends it, and an invited-user registration sends both `account-invite` and `account-created` |

**The existing-suite audit is work, not a footnote.** Every test that creates a
`User` through `create`/`save` and then counts enqueued jobs, emails, or
deliveries now sees one more. Fixtures do not run callbacks, so the blast
radius is limited to `test/integration/loops_contact_lifecycle_test.rb`, the
registration tests, and `test/models/user_test.rb`.

**Deferred / out:**

- Marketing or lifecycle welcome email — COV-55.
- Devise `:confirmable` or any email confirmation.
- Onboarding sequences.
- Any change to the existing eleven templates.
- OAuth marketing-consent capture — still the open gap COV-55 recorded, and
  still its own ticket. This ticket makes OAuth signups reachable by
  *transactional* mail only.
- Re-sending on email change.
- `firstName` on Loops contacts — COV-51's surface.
- Production verification, which needs a production service to exist.

## Open Questions

None. The ticket's two open questions were both resolved during design:

1. **Does an invited user get this email?** Yes, ungated — Decision 1.
2. **Does the copy include a sign-in link?** Yes, pointing at
   `new_user_session_url` — Decision 3.

## More Info

- **The transport contract is unchanged from COV-37/COV-43.**
  `X-Loops-Transactional-Id` and `X-Loops-Data-Variables` as internal headers,
  `body: ""` to prevent template lookup, `LoopsDelivery` reading the headers and
  delegating to `LoopsClient`. This ticket adds a caller, not a mechanism.
- **This is the twelfth transactional template and the first one triggered by a
  model callback.** The other eleven are triggered by Devise, by
  `AccountInvitation`, by a controller, or by Pay.
- **`User` has no `:confirmable`** (see `AGENTS.md` Known Gotchas), so
  `user.confirmed?` does not exist. This email is explicitly *not* a
  confirmation email — it asserts nothing about the address being verified.
- **Rate limit is 10 requests/second per team**, shared across transactional and
  marketing (COV-37, COV-38). Irrelevant at signup volume.
- **The Loops send allowance is 4,000 per rolling 30 days** (COV-38), shared
  between transactional and marketing.
