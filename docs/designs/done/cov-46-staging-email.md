> Plan created: docs/plans/cov-46-staging-email.md
> Ticket: COV-46
> Branch: feature/cov-46-decide-and-apply-staging-email-behavior

# Feature: Guarded staging email delivery

## Problem

Staging currently sets `config.action_mailer.perform_deliveries = false`, so it
cannot provide the real end-to-end inbox verification required by COV-47 while
production remains dormant. Its mailer configuration is also asymmetric with
production: production selects the registered Loops delivery method, while
staging still assigns unused SMTP settings.

Enabling staging without a recipient boundary would allow password resets and,
later, account and billing mail to reach real users from a non-production
environment. Staging and production also share one Loops team, sending domain,
rate limit, and reputation, so staging delivery must remain deliberately small
and controlled.

## Approach

Enable real transactional delivery in staging, guarded by a fail-closed,
staging-only ActionMailer interceptor.

Staging and production will both select `:loops` as their delivery method in
structurally parallel configuration. Staging will additionally set
`perform_deliveries = true` explicitly and register the recipient guard.
`config/jumpstart.rb` will keep `email_provider` set to `""`; Loops is not a
Jumpstart mail provider and the Jumpstart config generator must not be run.

The guard reads a comma-separated exact-address allowlist from
`STAGING_EMAIL_RECIPIENT_ALLOWLIST`. It normalizes case and whitespace, rejects
invalid entries, and makes staging fail to boot when the variable produces no
valid recipients. Before delivery, it checks every `To`, `CC`, and `BCC`
destination. If any destination is absent from the allowlist, the entire
message is rejected with a dedicated staging error before `LoopsDelivery`
makes an API request. The error is intentionally not retryable.

This chooses an application-level allowlist over a second Loops team. A second
team would provide rate-limit, audience, and reputation isolation, but would
also require another subdomain, DNS setup, credentials, and operational upkeep.
That cost is not justified for COV-47's small set of controlled verification
sends. The accepted limitation is that allowed staging sends consume the
shared team's quota and reputation.

`perform_deliveries = false` remains the documented emergency code-level kill
switch. Revoking the staging Loops API key remains an account-level fallback.

## Acceptance Criteria

- The staging decision is recorded here with its reasoning and accepted risks.
- Staging and production select the Loops delivery method in parallel
  structure, with no later SMTP/provider override.
- Staging explicitly enables deliveries and registers the recipient guard;
  production does not register it.
- The staging `AIDEV-NOTE` states that outbound email is live only for exact
  allowlisted recipients and names `perform_deliveries = false` as the
  emergency kill switch.
- `config/jumpstart.rb` keeps `email_provider` set to `""`.
- Staging refuses to boot when `STAGING_EMAIL_RECIPIENT_ALLOWLIST` is missing,
  empty, or contains no valid address.
- Address comparison is case-insensitive and exact; aliases and domain
  wildcards are not inferred.
- A message with any non-allowlisted `To`, `CC`, or `BCC` recipient is entirely
  blocked before any Loops request.
- An allowed staging test message reaches its inbox.
- A fabricated non-allowlisted address is demonstrably blocked and produces no
  Loops request.
- The deployed staging user table is audited before delivery is activated; no
  real address is silently assumed safe from the checked-in seeds.
- The staging boot check returns `true`:
  `RAILS_MASTER_KEY=$(cat config/credentials/staging.key) RAILS_ENV=staging bin/rails runner "puts Rails.application.config.action_mailer.perform_deliveries"`.
- Automated tests cover configuration parity, allowlist parsing, boot failure,
  allowed delivery, blocked delivery, multiple recipients, and environment
  isolation.
- `bin/rails test` passes and `bin/rubocop` is clean.

## Prototype

None. This is environment configuration and delivery safety behavior with no
application UI.

## Data Model

No database or model changes.

`STAGING_EMAIL_RECIPIENT_ALLOWLIST` is the only new configuration input. It is
stored in Render's staging environment settings rather than source control or
Rails credentials so the approved inboxes can be rotated operationally. The
parsed allowlist is process-local and stateless.

The guard raises a dedicated blocked-recipient error. That error is separate
from Loops transport errors so `LoopsMailDeliveryJob` does not retry a send
that policy intentionally rejected.

## Screens / Flows

There is no Cove screen or component work. The operational flow is:

1. Before deploying the enabling change, the operator adds one or more exact
   inboxes to `STAGING_EMAIL_RECIPIENT_ALLOWLIST` in Render.
2. Staging boots with `delivery_method = :loops` and
   `perform_deliveries = true`. Missing or unusable allowlist configuration
   fails the deploy rather than permitting unguarded delivery.
3. An existing transactional trigger builds its normal ActionMailer message.
4. The staging interceptor checks all message destinations.
5. If all destinations are allowlisted, delivery continues through
   `LoopsDelivery` and the existing `LoopsClient`.
6. If any destination is not allowlisted, the guard raises before the Loops
   client is called. Synchronous Devise flows show a loud staging failure;
   asynchronous mail jobs fail without retrying the policy rejection.
7. COV-46 verifies one allowed arrival and one blocked fabricated recipient.
   COV-47 later uses only approved inboxes for its eleven-message verification.
8. If delivery must be shut down, restore `perform_deliveries = false`; the
   existing Mail behavior prevents the Loops API call entirely.

## Scope

**In:** the recorded decision; parallel `:loops` configuration in staging and
production; explicit staging delivery enablement; a staging-only exact-address
recipient guard; fail-closed configuration; the updated staging `AIDEV-NOTE`;
tests; deployed-user audit; and allowed/blocked staging verification.

**Deferred:** provisioning or enabling production; COV-47's eleven-message
verification; changing `config/jumpstart.rb`'s `email_provider`; creating a
separate Loops team or subdomain; changing Loops templates; account and billing
mailer wiring; and marketing/contact safety controls.

The ActionMailer interceptor does not cover direct `LoopsClient` calls.
COV-51 must add its own fail-closed guard before staging can create or update
contacts or initiate marketing behavior. This ticket's guard must not be
described as covering the marketing track.

## Open Questions

None.

## More Info

### Current implementation facts

- COV-37 chose a custom ActionMailer delivery method, so
  `perform_deliveries = false` is a proven kill switch that prevents the Loops
  API call.
- COV-39 added `LoopsClient`, explicit network timeouts, and
  `LoopsMailDeliveryJob` retry handling for transient Loops and network errors.
- COV-43 registered `:loops`, wired the Devise transactional mailer, and made
  production select `delivery_method = :loops`.
- Staging now uses the `:async` Active Job adapter, not the `:inline` adapter
  described in the original ticket. Delivery therefore does not add Loops
  latency to asynchronous mail-triggering requests, although Devise's existing
  `deliver_now` behavior remains synchronous.
- Production uses Solid Queue but its Render service remains commented out and
  unprovisioned.
- The checked-in development seeds use only `@cove.test` addresses. That does
  not establish what addresses already exist in the deployed staging database,
  so a live audit remains mandatory.
- COV-38 deliberately gave staging and production separate API keys within one
  shared Loops team. The allowlist provides recipient safety, not team,
  audience, quota, or reputation isolation.

### Guard behavior

- Missing recipients fail closed.
- Empty entries are discarded, but every remaining configured entry must be a
  valid email address.
- Comparison is case-insensitive after parsing; it does not broaden addresses
  through plus-address handling or domain patterns.
- One blocked destination blocks the whole message, preventing partial sends.
- The blocked-recipient error may name the rejected address for diagnosis but
  must not expose the full allowlist.
- Registration is staging-only. Development keeps Mailbin, test keeps the test
  delivery method, and production has no recipient guard.

### Manual activation boundary

The allowlist must be saved in Render before the enabling commit deploys. The
actual recipient values belong in Jordan's Render account and must not be
committed or pasted into implementation notes. Activation is not complete
until the live staging database audit, allowed inbox arrival, and blocked-send
proof have all been recorded.
