> Ticket: COV-50
> Branch: feature/cov-50-extend-loops-client-contacts-lists-events-suppression

# Plan: Extend the Loops client with contacts, lists, events, and suppression

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add the throttling seam and contact-write methods | Master | |
| 2 | 1 | 1 | Add contact lookup, deletion, and suppression methods | subagent | |
| 3 | 1 | 1 | Add mailing-list and event methods with endpoint-local conflict handling | subagent | |
| 4 | 1 | 2 | Prove cross-endpoint errors, throttling, and full regression safety | Master | |

## Prerequisites

- Design: `docs/designs/cov-50-loops-client-extension.md`
- Prototype: None
- Feature branch exists: `feature/cov-50-extend-loops-client-contacts-lists-events-suppression`
- Backend-only: no views, components, routes, models, migrations, or component-catalog work.
- Architecture references reviewed: `docs/architecture/app-structure.mermaid`, `docs/architecture/data-model.mermaid`, and `docs/architecture/routes-map.mermaid`.
- Preserve COV-37's approved raw-HTTP architecture: extend `LoopsClient < ApplicationClient`; do not add `loops_sdk` or another gem.
- Endpoint contracts were revalidated against Loops' current official documentation for [contact creation](https://loops.so/docs/api-reference/create-contact), [contact updates](https://loops.so/docs/api-reference/update-contact), [contact lookup](https://loops.so/docs/api-reference/find-contact), [contact deletion](https://loops.so/docs/api-reference/delete-contact), [suppression checks](https://loops.so/docs/api-reference/check-contact-suppression), [suppression removal](https://loops.so/docs/api-reference/remove-contact-suppression), [mailing lists](https://loops.so/docs/api-reference/list-mailing-lists), and [events](https://loops.so/docs/api-reference/send-event).
- Before Rails or RuboCop commands, prepend mise's shims:
  `export PATH="/Users/jordan/.local/share/mise/shims:$PATH"`
- The design and plan must be committed together so execute-plan begins from a clean worktree.

## Tasks

### Task 1 [Master]: Add the throttling seam and contact-write methods

**Skills:** write-tests, loops-api

**Reference:** Read `app/clients/loops_client.rb`, `test/clients/loops_client_test.rb`, `lib/jumpstart/app/clients/application_client.rb`, and the contact request rules in `docs/designs/cov-50-loops-client-extension.md`.

**In scope:**

- Extend direct initialization and `.client` to accept an optional callable throttler while preserving every existing call shape.
- Install a no-op callable when no throttler is supplied.
- Add `create_contact` and `update_contact` with the exact public signatures from the design.
- Validate required identifiers and boolean mailing-list memberships before throttling or HTTP.
- Serialize mailing-list IDs as strings while preserving both `true` and `false`.
- Preserve custom-property keys and `nil` values at the top level.
- Remove conflicting string or symbol custom-property keys before merging so client-owned JSON fields always win.
- Return each successful response's parsed body; allow contact-create 409 to remain `LoopsClient::Conflict`.

**NOT in scope:**

- Contact reads, deletion, suppression, mailing-list reads, or events.
- A concrete throttle algorithm, sleeping, rate-limit header interpretation, retries, or changes to COV-51.
- Create-then-update fallback behavior.
- Changes to `ApplicationClient`, `send_transactional`, credentials, gems, jobs, or callers.

**Build order:**

1. **Test:** extend `test/clients/loops_client_test.rb` first to prove:
   - Existing `LoopsClient.new(token:)` and `LoopsClient.client` calls still work without a throttler.
   - Direct initialization and `.client(throttler:)` retain and invoke the supplied callable.
   - Create issues one authorized `POST /v1/contacts/create`; update issues one authorized `PUT /v1/contacts/update`.
   - Successful create/update return parsed `{success, id}` bodies.
   - `subscribed: nil` is omitted while explicit `false` and `true` are serialized.
   - Mailing-list IDs become string keys and both membership values are preserved.
   - Non-boolean memberships raise `ArgumentError` before throttling or HTTP.
   - Custom `nil` values remain present, non-reserved keys retain their supplied spelling, and conflicting string or symbol forms of `email`, `userId`, `subscribed`, or `mailingLists` cannot override explicit fields.
   - Blank create email and update calls without either identifier raise `ArgumentError` before HTTP.
   - Contact-create 409 raises `LoopsClient::Conflict`.
2. **Implement:** update `app/clients/loops_client.rb` with:
   - A reusable no-op throttler and initializer/factory keyword forwarding.
   - A private marketing-request wrapper that calls the throttler immediately before yielding to the HTTP operation.
   - Private identifier, mailing-list, and top-level-property merge helpers.
   - `create_contact` and `update_contact`, calling `.parsed_body` on successful responses.
3. **Verify:**
   `export PATH="/Users/jordan/.local/share/mise/shims:$PATH" && bin/rails test test/clients/loops_client_test.rb`

### Task 2 [subagent]: Add contact lookup, deletion, and suppression methods

**Skills:** write-tests, loops-api

**Reference:** Follow the validation, throttle, and parsed-body patterns established by Task 1 in `app/clients/loops_client.rb`; consult the official Loops find, delete, and suppression references linked in Prerequisites.

**In scope:**

- Add `find_contact`, `delete_contact`, `suppression_status`, and `remove_suppression`.
- Require exactly one nonblank `email` or `user_id` for every method.
- Map `user_id` to the `userId` API field without changing caller values.
- Use query parameters for find and both suppression endpoints.
- Use a JSON body with exactly one identifier for contact deletion.
- Invoke the throttler once immediately before each HTTP request.
- Return parsed arrays and objects unchanged, including empty find results and suppression quota data.

**NOT in scope:**

- Refusing suppression removal when quota is low.
- Changing or interpreting `contact`, `isSuppressed`, or `removalQuota`.
- Contact write behavior, mailing lists, events, retries, or calling code.
- Live Loops requests.

**Build order:**

1. **Test:** extend `test/clients/loops_client_test.rb` first with WebMock-backed behavior tests proving:
   - `find_contact` sends `GET /v1/contacts/find` with either `email` or `userId` and returns the parsed array, including `[]`.
   - `delete_contact` sends `POST /v1/contacts/delete` with exactly one identifier and returns the parsed `{success, message}` body.
   - `suppression_status` sends `GET /v1/contacts/suppression` and returns `contact`, `isSuppressed`, and nested quota values.
   - `remove_suppression` sends `DELETE /v1/contacts/suppression` and returns the updated nested quota.
   - Missing identifiers, blank identifiers, and supplying both identifiers raise `ArgumentError` before throttling or HTTP.
2. **Implement:** add the four public methods to `app/clients/loops_client.rb`, reusing Task 1's exact-one-identifier, marketing-request, and parsed-response helpers.
3. **Verify:**
   `export PATH="/Users/jordan/.local/share/mise/shims:$PATH" && bin/rails test test/clients/loops_client_test.rb`

### Task 3 [subagent]: Add mailing-list and event methods

**Skills:** write-tests, loops-api

**Reference:** Follow the patterns established in Tasks 1–2 and the official mailing-list and event references linked in Prerequisites.

**In scope:**

- Add `list_mailing_lists` and `send_event` with the design's exact signatures.
- Send `GET /v1/lists` and return its parsed array unchanged.
- Send events through `POST /v1/events/send`.
- Require `event_name` and at least one nonblank email or user ID; allow both identifiers.
- Serialize nested event properties, string-keyed mailing-list membership, and top-level contact properties.
- Ensure explicit event-owned fields win over conflicting string or symbol custom-property keys.
- Add `Idempotency-Key` only when the caller supplies a non-`nil` value.
- Return `true` for event 2xx and event-local 409 while retaining contact and transactional conflict semantics.

**NOT in scope:**

- Generating event names or idempotency keys.
- Event callers, lifecycle instrumentation, workflows, campaigns, or COV-54.
- Internal retry or pacing policy.
- Changing `send_transactional` behavior or globally treating 409 as success.

**Build order:**

1. **Test:** extend `test/clients/loops_client_test.rb` first to prove:
   - Mailing-list lookup issues one authorized `GET /v1/lists` and returns parsed `id`, `name`, `description`, and `isPublic` data.
   - Event sending issues one authorized `POST /v1/events/send` with the exact identifiers, `eventName`, `eventProperties`, string-keyed boolean `mailingLists`, and top-level contact properties.
   - Conflicting custom keys cannot replace `email`, `userId`, `eventName`, `eventProperties`, or `mailingLists`; unrelated `nil` custom values remain present.
   - The idempotency header is present with the supplied value and absent when omitted.
   - Missing or blank event names, missing both identifiers, and invalid mailing-list membership raise `ArgumentError` before HTTP.
   - Event success and event 409 return `true`.
   - Contact-create 409 still raises `LoopsClient::Conflict`.
   - Transactional 409 still returns `true`.
2. **Implement:** add both public methods to `app/clients/loops_client.rb`; rescue `Conflict` only inside `send_event`, leaving `handle_response` unchanged.
3. **Verify:**
   `export PATH="/Users/jordan/.local/share/mise/shims:$PATH" && bin/rails test test/clients/loops_client_test.rb`
4. **Review:** run `review-changes-mini` once for Checkpoint 1, covering Tasks 1–3. If the tasks were executed as a parallel batch, the master runs the review once after the entire batch returns rather than any task running it independently.

### Task 4 [Master]: Prove cross-endpoint errors, throttling, and regression safety

**Skills:** write-tests, review-changes-mini

**Reference:** Read the completed `app/clients/loops_client.rb`, `test/clients/loops_client_test.rb`, and inherited response mappings in `lib/jumpstart/app/clients/application_client.rb`.

**In scope:**

- Add table-driven regression coverage across all eight new marketing methods.
- Prove every method retains inherited 422 and 429 typed errors.
- Prove the throttler runs exactly once immediately before every marketing HTTP request.
- Prove a throttler exception propagates and prevents HTTP.
- Prove the default throttler remains a no-op.
- Run focused, full-suite, lint, diff, and worktree verification.

**NOT in scope:**

- Retrying errors inside `LoopsClient`.
- Implementing sleeps, token buckets, shared process state, or rate-limit-header parsing.
- Broad client refactors, new error classes, logging changes, live API calls, or unrelated cleanup.

**Build order:**

1. **Test:** extend `test/clients/loops_client_test.rb` first with data-driven cases covering every new public method:
   - Stub its exact verb and URL with 422, then assert `LoopsClient::UnprocessableContent`.
   - Stub it with 429, then assert `LoopsClient::RateLimit`.
   - On success, assert one throttler call and one HTTP request.
   - With a raising throttler, assert the original exception, zero HTTP requests, and no rescue or translation.
2. **Implement:** make only the smallest necessary changes in `app/clients/loops_client.rb` if the cross-endpoint matrix exposes inconsistent shared behavior. Do not modify `ApplicationClient` or transactional sending.
3. **Verify:** run in order:
   - `export PATH="/Users/jordan/.local/share/mise/shims:$PATH" && ruby -v`
   - `export PATH="/Users/jordan/.local/share/mise/shims:$PATH" && bin/rails test test/clients/loops_client_test.rb`
   - `export PATH="/Users/jordan/.local/share/mise/shims:$PATH" && bin/rails test`
   - `export PATH="/Users/jordan/.local/share/mise/shims:$PATH" && bin/rubocop`
   - `git diff --check`
   - `git status --short`
   - `git diff`
4. **Review:** run `review-changes-mini` once for Checkpoint 2, covering Task 4 and the integrated final diff.

## Task Dependencies

- Task 1 is first because it establishes the initializer compatibility, validation, payload-merging, throttling, and response-return patterns used by every later method.
- Tasks 2 and 3 depend on completed Task 1 and are independently verifiable afterward.
- Tasks 2 and 3 both modify `app/clients/loops_client.rb` and `test/clients/loops_client_test.rb`; execute their subagent assignments sequentially to avoid overlapping edits.
- Task 4 depends on all endpoint methods being complete and remains with Master because it validates shared behavior across the entire client and owns final verification.
- No task changes more than two files. Checkpoint 1 establishes all endpoint behavior; Checkpoint 2 independently hardens the shared cross-endpoint guarantees.
