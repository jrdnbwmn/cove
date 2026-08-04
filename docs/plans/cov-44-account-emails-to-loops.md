> Ticket: COV-44
> Branch: feature/cov-44-wire-account-emails-to-loops

# Plan: Wire account emails to Loops

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add the account transactional mappings | Master | |
| 2 | 1 | 1 | Build the bodyless Loops-backed AccountMailer | Master | |
| 3 | 1 | 2 | Verify the account invitation delivery boundary | subagent | |
| 4 | 1 | 2 | Verify delayed cancellation delivery | subagent | |
| 5 | 1 | 2 | Remove the obsolete preview and run final verification | Master | |

## Prerequisites

- Design: [`docs/designs/cov-44-account-emails-to-loops.md`](../designs/cov-44-account-emails-to-loops.md)
- Prototype: None; Loops owns the already-published email presentation, and no application UI changes
- Feature branch exists: `feature/cov-44-wire-account-emails-to-loops`
- Run Rails commands through mise using `mise exec --`
- The user-specified design is already present identically in this workspace but is untracked. Plan approval will commit the design and plan together so execution starts from a clean worktree.
- Architecture maps and the component catalog were reviewed. No routes, models, migrations, views, components, or component-library additions are required.
- COV-39 and COV-43 already provide `LoopsClient`, stable content-derived idempotency, `LoopsDelivery`, `LoopsMailDeliveryJob`, production delivery registration, and the bodyless mailer pattern.

## Tasks

### Task 1 [Master]: Add the account transactional mappings

**Skills:** loops-api, write-tests
**Reference:** Read [`config/loops.yml`](../../config/loops.yml) and [`test/mailers/loops_devise_mailer_test.rb`](../../test/mailers/loops_devise_mailer_test.rb) for the existing checked-in mapping contract.

**In scope:**

- Add `invite: cmsdr01rw02s00j3ozshehy4f`.
- Add `cancellation_reason: cmsdrmznp040g0jzsnkt9hpsa`.
- Preserve the existing reset-password and password-change IDs.
- Update the configuration assertion to require exactly all four mappings.

**NOT in scope:**

- No credentials, environment configuration, delivery-method selection, staging enablement, Loops API calls, template publication, or IDs for Pay mailers.
- No edits under `lib/jumpstart/`.

**Build order:**

1. **Test:** Update the mapping assertion in `test/mailers/loops_devise_mailer_test.rb` first to require the exact four keys and IDs. Run it and confirm it fails because the account mappings are absent.
2. **Implement:** Add the two account-mailer mappings under `shared.transactional` in `config/loops.yml`.
3. **Verify:** `mise exec -- bin/rails test test/mailers/loops_devise_mailer_test.rb`

### Task 2 [Master]: Build the bodyless Loops-backed AccountMailer

**Skills:** loops-api, write-tests
**Reference:** Read [`app/mailers/loops_devise_mailer.rb`](../../app/mailers/loops_devise_mailer.rb), [`lib/jumpstart/app/mailers/account_mailer.rb`](../../lib/jumpstart/app/mailers/account_mailer.rb), [`config/routes/accounts.rb`](../../config/routes/accounts.rb), and [`test/mailers/account_mailer_test.rb`](../../test/mailers/account_mailer_test.rb).

**In scope:**

- Add the host-app shadow at `app/mailers/account_mailer.rb`.
- Override only `invite` and `cancellation_reason`.
- Use strict `fetch` lookup for both transactional mappings.
- Attach `X-Loops-Transactional-Id` and JSON-encoded `X-Loops-Data-Variables`.
- Give `invite` exactly `inviter_name`, `account_name`, and the absolute `account_invitation_url`.
- Preserve the `"Someone"` inviter fallback.
- Give `cancellation_reason` an empty variables object.
- Preserve recipient, support sender, and cancellation Reply-To metadata.
- Pass `body: ""` and document why the vendored templates are intentionally unreachable.

**NOT in scope:**

- No HTTP client, delivery job, controller, model, route, template, subject, copy, layout, staging, production, or vendored-file changes.
- Do not add variables such as recipient email that the published templates do not declare.
- No fallback to another template or provider when configuration is missing.

**Build order:**

1. **Test:** Replace the legacy body/subject assertions in `test/mailers/account_mailer_test.rb` first. Prove:
   - `invite` carries the account-invite ID and exactly the three required variables.
   - Its URL equals `account_invitation_url`, resolves through the real invitation route, and contains the invitation token.
   - A missing inviter produces `"Someone"`.
   - `cancellation_reason` carries the cancellation-survey ID and `{}`.
   - Recipients and existing support From/Reply-To metadata are preserved.
   - Both messages are empty and non-multipart.
   - A test-only subclass whose renderer raises can still build both messages.
   - Missing mappings raise rather than producing a fallback message.
   Run the test and confirm the new assertions fail before implementation.
2. **Implement:** Add `app/mailers/account_mailer.rb`, following the existing `LoopsDeviseMailer` header and bodyless-delivery pattern.
3. **Verify:** `mise exec -- bin/rails test test/mailers/account_mailer_test.rb test/mailers/loops_devise_mailer_test.rb`
4. **Review:** After Tasks 1–2 are complete, run `review-changes-mini` exactly once for Checkpoint 1.

### Task 3 [subagent]: Verify the account invitation delivery boundary

**Skills:** loops-api, write-tests
**Reference:** Read [`lib/jumpstart/app/models/account_invitation.rb`](../../lib/jumpstart/app/models/account_invitation.rb), [`test/models/account_invitation_test.rb`](../../test/models/account_invitation_test.rb), and the WebMock delivery pattern in [`test/controllers/users/passwords_controller_test.rb`](../../test/controllers/users/passwords_controller_test.rb).

**In scope:**

- Exercise `AccountInvitation#save_and_send_invite`, not a controller or plain `create`.
- Prove one valid invitation enqueues and performs exactly one `LoopsMailDeliveryJob`.
- Assert the real request recipient, transactional ID, and exact variables.
- Verify the invitation URL’s route and token.
- Assert the request’s idempotency key matches `LoopsClient#idempotency_key`.
- Prove an invalid invitation enqueues no mail and issues no request.
- Temporarily use `:loops` only for this mailer test path and restore global state afterward.

**NOT in scope:**

- No changes to `AccountInvitation`, invitation controllers, routes, account-type gating, invitation UI, fixtures, or vendored code.
- No synchronous replacement for `deliver_later`.
- No live Loops request.

**Build order:**

1. **Test:** Extend `test/models/account_invitation_test.rb` with valid and invalid `save_and_send_invite` cases, using WebMock at the Loops boundary and performing the real queued mail job.
2. **Implement:** Add only the scoped test setup/helpers needed to capture the request, perform the job, and safely restore `AccountMailer.delivery_method`. If the production behavior from Task 2 does not satisfy the test, stop and return the failure to the Master rather than modifying shared implementation.
3. **Verify:** `mise exec -- bin/rails test test/models/account_invitation_test.rb`

### Task 4 [subagent]: Verify delayed cancellation delivery

**Skills:** loops-api, write-tests
**Reference:** Read [`lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb`](../../lib/jumpstart/app/controllers/billing/subscriptions/cancels_controller.rb), [`test/integration/subscriptions_test.rb`](../../test/integration/subscriptions_test.rb), and [`test/fixtures/pay/subscriptions.yml`](../../test/fixtures/pay/subscriptions.yml).

**In scope:**

- Exercise the authenticated billing cancellation endpoint as an account admin.
- Prove cancellation schedules exactly one `LoopsMailDeliveryJob` approximately one hour later.
- Prove no request occurs before the scheduled job is performed.
- Perform the scheduled job and assert exactly one cancellation-survey request.
- Assert the recipient, transactional ID, empty variables object, and matching content-derived idempotency key.
- Preserve the existing redirect and subscription-cancellation behavior.
- Temporarily use `:loops` for this mailer path and restore global state afterward.

**NOT in scope:**

- No controller, route, billing model, Pay behavior, delay, queue-adapter, or environment changes.
- No live delivery or cancellation email content changes.
- No edits under `lib/jumpstart/`.

**Build order:**

1. **Test:** Extend `test/integration/subscriptions_test.rb` with a focused cancellation-delivery case using the existing fake processor, Active Job assertions, time helpers, and WebMock.
2. **Implement:** Add only the scoped test setup/helpers needed to inspect and perform the scheduled job. If the existing controller contract does not satisfy the test, stop and report the discrepancy to the Master rather than editing vendored code.
3. **Verify:** `mise exec -- bin/rails test test/integration/subscriptions_test.rb`

### Task 5 [Master]: Remove the obsolete preview and run final verification

**Skills:** review-changes-mini
**Reference:** Re-read the acceptance criteria in [`docs/designs/cov-44-account-emails-to-loops.md`](../designs/cov-44-account-emails-to-loops.md) and the bodyless-message assertions in [`test/mailers/account_mailer_test.rb`](../../test/mailers/account_mailer_test.rb).

**In scope:**

- Delete `test/mailers/previews/account_mailer_preview.rb`.
- Verify exact mappings, payloads, URLs, metadata, bodyless messages, enqueue boundaries, one-hour scheduling, request counts, and idempotency.
- Run the complete test suite and RuboCop.
- Review the final diff for scope, secrets, dead debug code, and any changes under `lib/jumpstart/`.

**NOT in scope:**

- Do not delete vendored ERB views or their locale keys.
- No new preview replacement, live inbox send, template edit, staging enablement, production activation, Pay mailer work, Devise work, or unrelated cleanup.

**Build order:**

1. **Test:** Run the focused mailer, invitation, and subscription tests together before deleting the preview to establish that shipped content no longer depends on it: `mise exec -- bin/rails test test/mailers/account_mailer_test.rb test/models/account_invitation_test.rb test/integration/subscriptions_test.rb`
2. **Implement:** Delete `test/mailers/previews/account_mailer_preview.rb`; make no replacement because Loops owns previewing for these templates.
3. **Verify:** Run:
   - `mise exec -- bin/rails test`
   - `mise exec -- bin/rubocop`
   - `git diff --check`
   - `git status --short`
   - `git diff`
   Confirm no file under `lib/jumpstart/` changed and no secret or unrelated change entered the diff.
4. **Review:** Run `review-changes-mini` exactly once for Checkpoint 2, covering Tasks 3–5. Because Tasks 3–4 are a parallel batch, the Master runs this review only after both subagents return and Task 5 verification is complete.

## Task Dependencies

- Task 2 depends on Task 1 because the new mailer strictly fetches the two account mappings.
- Tasks 3–4 depend on Task 2 and can run in parallel after the focused mailer contract passes.
- Task 5 depends on Tasks 3–4 and remains with the Master for deletion, full-suite verification, diff review, and the checkpoint review.
- Tasks 3–4 are delegated because each changes one independent test file with a precise external boundary. Tasks 1–2 and 5 modify shared configuration, establish the production pattern, or own final review.
