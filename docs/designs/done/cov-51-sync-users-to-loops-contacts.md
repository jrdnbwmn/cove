> Ticket: COV-51
> Branch: feature/cov-51-sync-users-to-loops-contacts
> Plan created: docs/plans/cov-51-sync-users-to-loops-contacts.md

# Feature: Sync consenting users to Loops contacts

## Problem

Cove records marketing consent and can write Loops contacts, but the two are not
connected. Consenting users therefore never enter the Loops audience or the
`Cove updates` mailing list, while lifecycle changes and account deletion are
not reflected in Loops.

## Approach

Implement COV-48's approved consent architecture with an intent-aware,
background-only contact sync. Only users who explicitly consent become Loops
contacts. Use `User#id.to_s` as Loops' stable `userId`, and use
`PUT /v1/contacts/update` as an upsert rather than calling contact creation.

A focused synchronizer owns Loops payload construction. Separate lifecycle,
deletion, and cursor-based backfill jobs keep routine synchronization,
post-deletion cleanup, and operational bulk work independently retryable.
Lifecycle hooks enqueue work only after the user transaction commits, so a
Loops outage never rolls back or blocks a signup or settings save.

Payloads are intent-specific:

- An explicit app opt-in sends `email`, `userId`, `subscribed: true`, and
  membership in `Cove updates`.
- An app opt-out sends `subscribed: false` and removes the contact from
  `Cove updates`.
- An email change identifies the contact by `userId`, sends the latest email,
  and omits `subscribed` and mailing-list fields.
- Account deletion sends the snapshotted string `userId` to the contact-delete
  endpoint.

The intent distinction is structural: routine updates can never resubscribe a
contact. Each job reloads current app state before writing, so delayed or
reordered work cannot override a newer consent decision.

Production is the only environment allowed to write contacts. Development,
test, and staging fail closed before constructing a client or issuing HTTP.
This extends COV-46's staging-email posture to direct Loops contact calls, which
are not protected by Action Mailer's `perform_deliveries` setting.

## Acceptance Criteria

- Creating a user without marketing consent enqueues no contact sync and sends
  no personal data to Loops.
- Creating a user with explicit marketing consent enqueues a contact upsert
  with their email, string `userId`, `subscribed: true`, and membership in the
  configured `Cove updates` mailing list.
- Opting in from settings creates or updates the contact with subscribed
  audience and mailing-list state.
- Opting out in the app updates the existing contact to `subscribed: false`
  and removes its mailing-list membership.
- Changing the email of a user who has previously been synced updates the
  existing contact by `userId`, sends the latest email, and omits consent and
  mailing-list fields.
- Name changes do not enqueue contact work because names are intentionally not
  sent to Loops.
- Deleting a user enqueues contact deletion with a plain string `userId`; a
  missing contact is treated as already deleted.
- A Loops or network failure cannot roll back or fail the originating user
  record change, and transient job failures retry independently.
- Stale or reordered jobs re-read current consent and cannot override a newer
  user decision.
- Development, test, and staging make no contact-write requests even when a
  lifecycle or backfill path is invoked.
- The dry-run backfill reports the current consenting-user count without
  contacting Loops or enqueueing jobs.
- The live backfill refuses to start outside production, when contact sync is
  disabled, or when the mailing-list ID is missing.
- The live backfill resumes by user-ID cursor, upserts only currently consenting
  users, and is paced at no more than five requests per second through COV-50's
  throttler seam.
- WebMock-backed tests cover payloads, guards, retries, job ordering, deletion,
  and throttling.
- `bin/rails test` passes, `bin/rubocop` is clean, and the final `git diff` is
  reviewed.

## Prototype

None. COV-51 adds background and operational behavior only. The existing
registration checkbox and Marketing preferences UI remain unchanged.

## Data Model

No models, migrations, tables, or associations are added.

The existing `User` consent fields remain Cove's source of truth:

- `email`
- `marketing_opt_in_at`
- `marketing_opt_in_source`
- `marketing_opt_out_at`
- `marketing_opt_out_reason`

The Loops contact contains only:

- `email`
- `userId`, set to `User#id.to_s`
- `subscribed`
- membership in the existing `Cove updates` list

Do not sync first name, last name, account information, plan, role, consent
timestamps, or speculative custom properties. Do not store the Loops contact
ID or a local "was synced" marker.

`config/loops.yml` stores two non-secret configuration values:

- The COV-53 `Cove updates` mailing-list ID,
  `cmsdo8ncl02wc0j0j4rxwhy4l`.
- `contact_sync_enabled`, true only in production and false in development,
  test, and staging.

Background-job arguments contain only the state needed to survive record
changes:

- Lifecycle sync: user ID plus `opt_in`, `opt_out`, or `email_change` intent.
- Deletion: snapshotted string `userId`, never a GlobalID.
- Backfill: the last successfully processed user ID as a cursor.

The backfill needs no progress table. Each successful batch enqueues the next
cursor, and retrying a failed batch is safe because contact updates are
idempotent upserts.

## Screens / Flows

### Registration without consent

1. The user registers without selecting the existing marketing checkbox.
2. Their account is created normally.
3. No contact-sync job is enqueued and Loops receives no personal data.

### Registration or settings opt-in

1. Cove commits the explicit consent transition.
2. An `opt_in` job is enqueued after commit.
3. The job reloads the user and proceeds only if they are still subscribed.
4. It upserts the contact with email, string `userId`, `subscribed: true`, and
   `Cove updates` membership set to true.

### App opt-out

1. Cove commits a `user_app` opt-out.
2. An `opt_out` job is enqueued after commit.
3. The job reloads the user and skips if they have since explicitly opted back
   in.
4. It sends `subscribed: false` and `Cove updates` membership set to false.
5. The contact remains in Loops so a later valid app opt-in can restore it.

Only app-originated changes enqueue these consent writes. Future COV-52
webhook-originated changes are not echoed back to Loops.

### Email change

1. A user who has previously entered the Loops audience changes their email.
2. An `email_change` job is enqueued after commit.
3. The job reloads the user and sends the latest email keyed by `userId`.
4. It omits `subscribed` and mailing-list membership.

An email change for a never-consenting user does nothing in Loops.

### Account deletion

1. The existing account-deletion flow destroys the user.
2. An after-commit hook enqueues deletion with the string `userId`.
3. The job deletes the matching Loops contact.
4. A missing contact is accepted as an already-complete deletion.

Deletion is attempted for every deleted user because Cove deliberately stores
no local sync marker. A delete call cannot create a contact and guarantees that
an older contact is not left behind.

### Backfill

1. `bin/rails loops:contacts:backfill:dry_run` prints the environment, guard
   state, mailing-list configuration status, and consenting-user count. It is
   safe in every environment and performs no external writes.
2. `bin/rails loops:contacts:backfill:enqueue` refuses to run unless the
   environment is production, contact sync is enabled, and the list ID exists.
3. The first cursor job loads currently consenting users in ascending ID order.
4. It upserts them as subscribed members of `Cove updates` sequentially at no
   more than five requests per second.
5. A successful batch enqueues the next cursor. A failed batch retries safely.
6. Progress and completion are written to production logs.
7. The operator compares the production dry-run count with the resulting Loops
   Audience change, accounting for lifecycle syncs during the run.

No admin page, progress table, cancel control, new UI, or user-visible sync
error is added.

## Edge Cases

- **Stale and reordered jobs:** Jobs reload the user and confirm current state.
  Delayed intent cannot override a newer consent choice, and email jobs send the
  latest email rather than a stale snapshot.
- **User deleted before sync:** A lifecycle job with no user exits. The separate
  deletion job still cleans up by string `userId`.
- **Missing contact on deletion:** Treat Loops `NotFound` as success so deletion
  remains idempotent.
- **Disabled environment:** Return before client construction or HTTP. Staging
  never writes into the shared production Loops audience.
- **Missing production configuration:** Fail visibly inside the background job
  rather than creating a contact without its required list membership. The
  backfill refuses to enqueue.
- **Transient failure:** Retry Loops rate limits and server errors plus network
  timeouts with polynomial backoff. These failures occur after the originating
  database transaction.
- **Permanent failure:** Validation, authorization, or identity-conflict errors
  remain visible job failures instead of retrying indefinitely.
- **Protected opt-out:** `user_loops`, `mailing_list_unsubscribe`, `hard_bounce`,
  and `spam_report` cannot be reversed by routine sync. COV-49 remains the gate
  for any later valid consent transition.
- **Rate-limit pressure:** The cursor job is sequential and injects a 0.2-second
  throttle through `LoopsClient`, capping backfill traffic at five requests per
  second and leaving headroom within Loops' shared ten-request budget.
- **Backfill concurrency:** A user who opts in after the cursor passes is handled
  by the normal lifecycle job. Retried batches are harmless upserts.

## Scope

**In:** production-only contact-sync configuration; existing mailing-list ID;
intent-aware synchronization; lifecycle hooks; background upsert and deletion;
resumable throttled backfill; dry-run and enqueue rake tasks; transient retry
behavior; staging guard; WebMock-backed tests.

**Deferred:** unsubscribe and suppression reconciliation (COV-52); additional
mailing lists or Loops configuration; events (COV-54); workflows; campaigns;
contact properties beyond email and `userId`; admin progress UI; cancellation;
changes to the consent model or preference screens.

## Open Questions

None.

## More Info

COV-48 is the governing architecture and overrides stale COV-51 ticket text in
three places:

1. Never-consenting users are not synced as `subscribed: false`; they have no
   Loops contact.
2. Contact writes use the update endpoint's upsert behavior, so contact-create
   409 fallback handling is not part of COV-51.
3. Deletion follows COV-48 Decision 5, using `POST /v1/contacts/delete` keyed by
   string `userId`.

COV-53 is complete. It created and verified the public `Cove updates` list with
ID `cmsdo8ncl02wc0j0j4rxwhy4l`; COV-51 owns adding that non-secret ID to Rails
configuration and sending membership in contact payloads.

The ticket's live staging-backfill criterion is replaced by automated guard and
payload coverage plus dry-run counting. Staging and production use different
API keys for one shared Loops team, not isolated audiences, so a live staging
backfill would put test users into the production audience. Production is the
only safe live target.
