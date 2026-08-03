> Ticket: COV-50
> Branch: feature/cov-50-extend-loops-client-contacts-lists-events-suppression
> Plan created: docs/plans/cov-50-loops-client-extension.md

# Feature: Extend the Loops client with contacts, lists, events, and suppression

## Problem

`LoopsClient` currently supports only transactional sends. The marketing track
needs the same authenticated client and error hierarchy to manage contacts, read
mailing lists, emit events, inspect suppression, and remove suppression without
duplicating transport or globally changing the transactional endpoint's special
409 behavior.

## Approach

Extend `LoopsClient` additively with explicit Ruby method signatures and keep
custom contact properties in caller-supplied hashes that are merged into the API
payload's top level. The public methods are:

```ruby
create_contact(email:, user_id: nil, subscribed: nil, mailing_lists: {}, contact_properties: {})
update_contact(email: nil, user_id: nil, subscribed: nil, mailing_lists: {}, contact_properties: {})
find_contact(email: nil, user_id: nil)
delete_contact(email: nil, user_id: nil)
suppression_status(email: nil, user_id: nil)
remove_suppression(email: nil, user_id: nil)
list_mailing_lists
send_event(event_name:, email: nil, user_id: nil, event_properties: {}, mailing_lists: {}, contact_properties: {}, idempotency_key: nil)
```

Use the current official Loops endpoint contracts:

| Method | Endpoint |
| --- | --- |
| `create_contact` | `POST /v1/contacts/create` |
| `update_contact` | `PUT /v1/contacts/update` |
| `find_contact` | `GET /v1/contacts/find` |
| `delete_contact` | `POST /v1/contacts/delete` |
| `suppression_status` | `GET /v1/contacts/suppression` |
| `remove_suppression` | `DELETE /v1/contacts/suppression` |
| `list_mailing_lists` | `GET /v1/lists` |
| `send_event` | `POST /v1/events/send` |

These correct two stale endpoint descriptions in the Linear ticket, which says
`DELETE /v1/contacts/delete` and `POST /v1/events`. Loops' current API reference
documents contact deletion as `POST` and event sending at `/v1/events/send`.

Add an injectable throttle collaborator to the existing initializer and
credential-backed factory. It responds to `call` with no arguments and is
invoked immediately before each new marketing request. Omitting it installs a
no-op callable. COV-50 exposes only this seam; COV-51 owns the pacing policy and
implementation. `send_transactional` does not invoke the new collaborator, so
its behavior remains unchanged.

Return parsed Loops response bodies from every data-bearing method. `send_event`
returns `true` for both an initial 2xx response and an idempotency-key 409.
Contact-create 409 continues to raise `LoopsClient::Conflict`, allowing a future
caller to fall back to update without this client choosing that policy.

### Request rules

- `create_contact` requires `email`; `user_id` is optional.
- `update_contact` and `send_event` require at least one of `email` or `user_id`;
  both may be supplied.
- Find, delete, and suppression methods require exactly one of `email` or
  `user_id`, avoiding ambiguous lookups.
- Explicit Ruby keywords map to Loops camelCase fields.
- `subscribed: nil` omits the field. Explicit `true` or `false` is serialized.
- Mailing-list IDs are serialized as strings and membership values must be
  booleans, preserving `{ "list_id" => true }` and `{ "list_id" => false }`.
- `contact_properties` is merged into the request's top level without renaming
  its keys. A `nil` custom value remains present because Loops uses it to clear
  a property.
- Explicit client-owned fields win over conflicting `contact_properties` keys,
  so a generic property hash cannot replace identifiers, event fields, or
  mailing-list membership.

### Response and error rules

- Create/update returns the parsed `{success, id}` body.
- Find returns Loops' parsed array, including an empty array when no contact is
  found.
- Delete returns the parsed `{success, message}` body.
- Suppression status returns `contact`, `isSuppressed`, and `removalQuota`.
- Suppression removal returns `success`, `message`, and `removalQuota`.
- Mailing lists returns the parsed array of `id`, `name`, `description`, and
  `isPublic` fields.
- Event 409 is rescued only inside `send_event` and returns `true`.
- Contact-create 409 is not rescued and remains `LoopsClient::Conflict`.
- Transactional 409 remains rescued only inside `send_transactional` and
  returns `true`.
- 422 and 429 continue through `ApplicationClient` as
  `LoopsClient::UnprocessableContent` and `LoopsClient::RateLimit` for every new
  method. Other inherited and Loops-specific error mappings remain intact.
- The client does not retry internally. Existing job-level retry behavior remains
  responsible for retrying retryable failures.
- A throttle exception stops the operation before HTTP and is not rescued.

## Acceptance Criteria

- [ ] Each new endpoint issues the documented HTTP verb, path, authorization,
      query/body, and optional header shape in a WebMock-backed unit test.
- [ ] Contact writes serialize identifiers and contact properties at the top
      level, omit an unspecified `subscribed`, and preserve explicit boolean
      subscription values.
- [ ] Mailing-list membership serializes IDs as string keys with exact boolean
      values for both subscribe and unsubscribe.
- [ ] `POST /v1/contacts/create` returning 409 raises
      `LoopsClient::Conflict`, distinguishable from success by a future caller.
- [ ] `POST /v1/events/send` returning 409 for a reused idempotency key returns
      `true`.
- [ ] `send_transactional` still returns `true` on 409, providing a regression
      guard for the existing endpoint-specific behavior.
- [ ] Every new method raises `LoopsClient::UnprocessableContent` on 422 and
      `LoopsClient::RateLimit` on 429.
- [ ] Suppression status and removal expose `removalQuota.limit` and
      `removalQuota.remaining`; removal does not silently refuse at low quota.
- [ ] Data-bearing methods return their parsed response bodies, while event
      success returns `true`.
- [ ] Missing or ambiguous identifiers and non-boolean mailing-list membership
      fail before any HTTP request.
- [ ] An injected throttler is invoked exactly once immediately before each new
      marketing request; the default is a no-op; throttler failure prevents HTTP.
- [ ] Existing `LoopsClient.client` callers and direct initialization without a
      throttler continue to work.
- [ ] `bin/rails test` passes, with output shown.
- [ ] `bin/rubocop` is clean.

## Prototype

None. This is backend infrastructure with no user interface.

## Data Model

No models, migrations, configuration, or persisted state are added.

All new data is transient request and response data inside `LoopsClient`.
Future contact sync uses `User#id` as the string `userId` and normally identifies
contacts by that field. Suppression is address-keyed, so future suppression
callers use `email` even though the client supports either documented identifier.

The throttle collaborator is also transient. It has one contract: respond to
`call` with no arguments.

## Screens / Flows

There are no screens, routes, controllers, forms, components, or user-visible
copy.

A future caller obtains `LoopsClient.client`, optionally supplies a throttler,
and invokes one method. The client validates identifiers and mailing-list
membership, invokes the throttler, serializes the request, performs the HTTP
call, and returns parsed response data or the endpoint-specific success value.

Create-then-update fallback is deliberately not performed here. A future caller
may rescue `LoopsClient::Conflict` from `create_contact` and call
`update_contact`; COV-48 expects normal contact sync to use the update endpoint's
upsert behavior directly.

## Scope

**In:** additive methods in `app/clients/loops_client.rb`; the injected no-op
throttling seam; endpoint-local 409 semantics; identifier and mailing-list
validation; parsed response contracts; WebMock unit tests in
`test/clients/loops_client_test.rb`; regression coverage for transactional 409;
and full test/lint verification.

**Deferred:** all calling code; contact synchronization and backfill (COV-51);
suppression reconciliation and support flows (COV-52); Loops mailing-list setup
(COV-53); lifecycle event emission (COV-54); a concrete token bucket or other
pacing implementation; jobs, models, controllers, routes, UI, live API calls,
campaign/workflow API methods, and any change to `send_transactional`.

## Open Questions

None.

## More Info

- Loops' baseline rate limit is 10 requests per second per team and is shared
  across transactional and marketing requests. Response headers expose
  `x-ratelimit-limit` and `x-ratelimit-remaining`; 429 remains a typed error.
- Suppression status returns `contact`, `isSuppressed`, and a `removalQuota`
  object with `limit` and `remaining`. Successful removal returns the updated
  quota. The client reports this data and never invents a low-quota refusal.
- Loops documents event 409 as reuse of an `Idempotency-Key` within the prior 24
  hours, so treating that endpoint's conflict as success does not generalize 409
  handling elsewhere.
- COV-48 establishes that normal sync uses `PUT /v1/contacts/update` as an
  upsert, uses stringified `User#id` as `userId`, uses email for suppression
  checks, and omits `subscribed` from routine property updates.
- Official API references consulted during design:
  `https://loops.so/docs/api-reference/create-contact`,
  `https://loops.so/docs/api-reference/update-contact`,
  `https://loops.so/docs/api-reference/find-contact`,
  `https://loops.so/docs/api-reference/delete-contact`,
  `https://loops.so/docs/api-reference/check-contact-suppression`,
  `https://loops.so/docs/api-reference/remove-contact-suppression`,
  `https://loops.so/docs/api-reference/list-mailing-lists`, and
  `https://loops.so/docs/api-reference/send-event`.
