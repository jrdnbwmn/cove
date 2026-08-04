> Ticket: COV-45
> Branch: feature/cov-45-wire-pay-billing-emails-to-loops

# Plan: Wire Pay billing emails to Loops

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add seven billing template IDs | Master | ✅ |
| 2 | 1 | 1 | Extend Loops client for seeds and attachments | Master | ✅ |
| 3 | 1 | 1 | Fan out and validate Loops mail delivery | Master | ✅ |
| 4 | 2 | 2 | Add receipt and refund Pay mail actions | Master | |
| 5 | 2 | 2 | Add subscription and payment Pay mail actions | Master | |

## Prerequisites

- Design: [docs/designs/cov-45-wire-pay-billing-emails-to-loops.md](../designs/cov-45-wire-pay-billing-emails-to-loops.md)
- Prototype: None
- Feature branch exists (run /prompts:branch first if needed)

## Tasks

### Task 1 [Master]: Add published billing template configuration

**Skills:** write-tests
**Reference:** Read [`config/loops.yml`](../../config/loops.yml) and [`test/mailers/loops_devise_mailer_test.rb`](../../test/mailers/loops_devise_mailer_test.rb) for checked-in transactional-ID conventions.

**In scope:**

- Add the seven COV-45 transactional IDs under the shared `transactional` map.
- Assert the complete nine-entry map: the two existing Devise IDs plus all seven billing IDs.

**NOT in scope:**

- Credentials, Loops templates, delivery-method configuration, or changes to existing IDs.

**Build order:**

1. **Test:** Extend `test/mailers/loops_devise_mailer_test.rb` to assert the exact billing action-to-ID mappings and complete key set.
2. **Implement:** Update `config/loops.yml` with the seven published billing transactional IDs.
3. **Verify:** `mise exec -- bin/rails test test/mailers/loops_devise_mailer_test.rb`

### Task 2 [Master]: Make transactional sends seed- and attachment-aware

**Skills:** write-tests
**Reference:** Read [`app/clients/loops_client.rb`](../../app/clients/loops_client.rb) and [`test/clients/loops_client_test.rb`](../../test/clients/loops_client_test.rb).

**In scope:**

- Add optional `idempotency_seed:` and `attachments:` inputs to `LoopsClient#send_transactional`.
- Derive seeded keys from transactional ID, recipient, and stable seed; retain the existing canonical data-variable key when no seed is supplied.
- Include Loops-compatible attachment objects in the request and retain existing `409` duplicate suppression.

**NOT in scope:**

- Recipient fan-out, mail-header parsing, Pay mailers, retries, or changes to non-transactional client APIs.

**Build order:**

1. **Test:** Add client tests for backward-compatible unseeded keys, recipient-specific seeded keys, exact attachment payload forwarding, `409` suppression, and hard failures for `400`, `413`, `422`, and transient responses.
2. **Implement:** Extend `app/clients/loops_client.rb` without changing existing callers’ unseeded behavior.
3. **Verify:** `mise exec -- bin/rails test test/clients/loops_client_test.rb`

### Task 3 [Master]: Validate, deduplicate, and fan out Loops mail

**Skills:** write-tests
**Reference:** Read [`app/mailers/loops_delivery.rb`](../../app/mailers/loops_delivery.rb), [`test/mailers/loops_delivery_test.rb`](../../test/mailers/loops_delivery_test.rb), and Task 2’s client contract.

**In scope:**

- Require and validate `X-Loops-Idempotency-Seed` for billing messages.
- Convert ActionMailer attachments to Loops `filename`, `contentType`, and strict-base64 `data` objects.
- Normalize display-name recipients to addresses, remove exact duplicates, and send each remaining recipient once.
- Assert exact different recipient keys, replay behavior, no second request after a same-key conflict, malformed-header failures before HTTP, and attachment-generation/payload failures.

**NOT in scope:**

- Pay action variable construction, webhook handler changes, delivery-job retry policy, or staging configuration.

**Build order:**

1. **Test:** Extend `test/mailers/loops_delivery_test.rb` for seed/attachment headers, address deduplication, two-recipient exact-key requests, conflict behavior, and no-request validation failures.
2. **Implement:** Update `app/mailers/loops_delivery.rb` to parse headers, map attachments, and call the expanded client API once per unique address.
3. **Verify:** `mise exec -- bin/rails test test/mailers/loops_delivery_test.rb`
4. **Review:** Once Tasks 1–3 are complete, run `/prompts:review-changes-mini` exactly once for Checkpoint 1.

### Task 4 [Master]: Add Loops-backed receipt and refund actions

**Skills:** write-tests
**Reference:** Read [`config/initializers/pay.rb`](../../config/initializers/pay.rb), [`app/mailers/loops_devise_mailer.rb`](../../app/mailers/loops_devise_mailer.rb), and Pay 11.6.2’s `app/mailers/pay/user_mailer.rb`.

**In scope:**

- Create the host `Pay::UserMailer` shadow inheriting from `Pay.parent_mailer.constantize`.
- Implement bodyless `receipt` and `refund` actions with Pay’s unchanged `mail_arguments` recipient behavior.
- Supply exact receipt/refund variables, optional 500-character inline billing information, stable seeds, and the required receipt PDF attachment.
- Add compatibility coverage that proves the shadow begins exposing Pay’s required action contract.

**NOT in scope:**

- Remaining five Pay actions, changing `Pay.mail_to`, vendored Pay files, template rendering, or authenticated receipt URLs.

**Build order:**

1. **Test:** Create `test/mailers/pay/user_mailer_test.rb` covering empty non-multipart messages, the receipt/refund headers and exact variables, truncated inline billing info, full strict-base64 PDF attachment, and failed/missing receipt generation before delivery.
2. **Implement:** Create `app/mailers/pay/user_mailer.rb` with a private shared Loops helper and explicit `receipt`/`refund` methods.
3. **Verify:** `mise exec -- bin/rails test test/mailers/pay/user_mailer_test.rb`

### Task 5 [Master]: Add the remaining five Pay billing actions and final verification

**Skills:** write-tests
**Reference:** Read [`app/mailers/pay/user_mailer.rb`](../../app/mailers/pay/user_mailer.rb), [`test/mailers/pay/user_mailer_test.rb`](../../test/mailers/pay/user_mailer_test.rb), and Pay 11.6.2’s Stripe webhook call sites.

**In scope:**

- Implement `subscription_renewing`, `payment_action_required`, `payment_failed`, `subscription_trial_will_end`, and `subscription_trial_ended`.
- Use the exact data-variable contracts, absolute billing URLs, Pay payment-confirmation URL, localized dates, and action-specific stable seeds.
- Complete the seven-method Pay-shadow compatibility test and distinct-event/replay coverage.
- Run the focused suite, full Rails suite, RuboCop, and inspect the final diff.

**NOT in scope:**

- Changes to Pay webhook handlers or `Pay.emails.*`, non-Stripe processor behavior, live inbox verification, or Loops template edits.

**Build order:**

1. **Test:** Extend `test/mailers/pay/user_mailer_test.rb` for every remaining action’s exact ID, variables, URL, seed, bodyless rendering, replay stability, and distinct renewal/refund/attempt/trial-event seeds.
2. **Implement:** Complete the five explicit methods and private helper validations in `app/mailers/pay/user_mailer.rb`.
3. **Verify:** `mise exec -- bin/rails test test/mailers/pay/user_mailer_test.rb && mise exec -- bin/rails test && mise exec -- bin/rubocop`; inspect `git diff origin/main...`.
4. **Review:** Once Tasks 4–5 are complete, run `/prompts:review-changes-mini` exactly once for Checkpoint 2.

## Task Dependencies

- Tasks 1 and 2 can begin independently.
- Task 3 depends on Task 2’s expanded client API.
- Task 4 depends on Tasks 1–3.
- Task 5 depends on Task 4 because both modify the same Pay mailer and test file.
