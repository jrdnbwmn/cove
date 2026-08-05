> Ticket: COV-47
> Branch: feature/cov-47-e2e-transactional-email-verification

# Plan: Free-tier staging verification bridge

## Why this addendum exists

Render's Free web-service plan has no Shell or one-off-job access, so the
existing COV-47 operational plan cannot use `bin/rails console`. This addendum
temporarily provides only the console-only COV-47 operations through
staging-only, authenticated, fixed-purpose HTTP actions. It is deployed to the
staging service for the verification run, then removed before the branch is
merged. It does not expose a general console, database query endpoint, raw
credentials, raw allowlist, or arbitrary-recipient mail sender.

The original plan remains the source of truth for the eleven sends, inbox
checks, Stripe actions, Loops/Honeybadger checks, results table, and cleanup.
Where it says "staging console," use the corresponding bridge action below.

## Security contract

- Routes and controller are available only in `Rails.env.staging?`.
- Every action requires an authenticated Devise session and an exact match
  between `current_user.email` and private Render variable
  `STAGING_VERIFICATION_OPERATOR_EMAIL`.
- The operator variable and recipient allowlist values stay in Render; neither
  belongs in source control, request parameters, logs, screenshots, or docs.
- Recipient addresses are always derived from `current_user` or its account;
  no request accepts a `to`, `cc`, or `bcc` parameter.
- Each operation is a named POST action. There is no generic method dispatch,
  query endpoint, model lookup by request id, or arbitrary mailer selection.
- Responses contain only the minimum non-secret operational evidence (boolean
  mail configuration, masked/count-based user audit, created Stripe price id,
  and named action outcome). Credentials and the raw allowlist are never
  returned.

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Define route/controller contract with failing tests | Master | ✅ |
| 2 | 1 | 1 | Implement the staging-only authenticated bridge | Master | ✅ |
| 3 | 1 | 2 | Deploy bridge and configure private Render inputs | Master | ✅ |
| 4 | 2 | 2 | Run COV-47 through all eleven sends using bridge actions | Master | |
| 5 | 3 | 3 | Complete dashboard checks and record COV-47 evidence | Master | |
| 6 | 3 | 3 | Remove bridge, restore staging deployment, and verify | Master | |

## Tasks

### Task 1 [Master]: Define route/controller contract with failing tests

**Skills:** write-tests

1. Add integration tests for every bridge action before implementation:
   unauthenticated requests redirect; an authenticated non-operator receives
   `404`; production/development do not expose routes; an operator can invoke
   each named action; no action accepts recipient/model-selection parameters.
2. Add controller-level tests for the non-delivery operations: configuration
   response is redacted, audit response is aggregate/masked, a `price_` id is
   the only accepted plan input, and cleanup touches only COV-47 named records.
3. Stub mail delivery at the mailer boundary in tests; assert the intended
   mailer/action and current user's records are used without making network
   calls.
4. Run the focused failing tests and record the red result.

### Task 2 [Master]: Implement the staging-only authenticated bridge

**Skills:** write-tests

Implement no more than these focused files in one batch: a controller under
`app/controllers/staging/`, a staging-gated route block, and its integration
test(s).

- Use `before_action :authenticate_user!` and a private `operator!` guard that
  compares the current email to `ENV.fetch("STAGING_VERIFICATION_OPERATOR_EMAIL")`.
  Treat a missing/blank variable as unavailable (`404`), not as access.
- Provide named POST actions for: status/audit; create the one COV-47 plan from
  a supplied `price_` id; invite the current user; send the three Tier-B Pay
  messages while always restoring `trial_ends_at`; send the cancellation
  fallback; enqueue the deliberately-invalid Loops send; and COV-47 cleanup.
- Status reports only `loops_delivery_enabled`, `perform_deliveries`, whether
  both operator addresses are allowlisted, and count/masked audit findings.
- Derive all user/account/customer/subscription data from `current_user`.
  Return a clear `unprocessable_entity` when a prerequisite does not exist.
- Keep controller actions thin and place each fixed operation in a focused
  service object only if it cannot stay straightforward; do not create a
  general-purpose executor.
- Add `# AIDEV-NOTE:` comments explaining the staging-only, temporary security
  boundary and removal requirement.
- Run focused tests, then `mise exec -- bin/rails test --fail-fast` and
  `mise exec -- bin/rubocop`; inspect `git diff`.

> **Checkpoint 1:** run `/review-changes-mini` once after Tasks 1–2. Confirm
> the bridge cannot be reached outside staging or by a non-operator, exposes no
> recipient/credential data, and has no generic execution path.

### Task 3 [Master]: Deploy bridge and configure private Render inputs

1. Commit and push the bridge separately; deploy that exact commit to
   `cove-staging` through Render. Record that a specific-commit deploy disables
   auto-deploy and therefore requires restoration in Task 6.
2. In Render Environment, set the comma-separated exact
   `STAGING_EMAIL_RECIPIENT_ALLOWLIST` and set
   `STAGING_VERIFICATION_OPERATOR_EMAIL` to the verification login address.
   Do not paste either value into source control or the COV-47 document.
3. Wait for the deploy/restart. Sign up or sign in as the verification user,
   then call the status action. Confirm Loops delivery is enabled, both
   addresses are allowlisted, and the audit has no actionable third-party
   recipient. Record only redacted audit evidence for Task 5.
4. If a non-operator or non-staging check fails, stop and remediate the bridge
   before any mail-triggering action.

### Task 4 [Master]: Run COV-47 using UI/Stripe and bridge substitutions

Follow original COV-47 Tasks 2–12 in their existing order, with these exact
substitutions for console-only steps:

- Task 2 credential confirmation: bridge status proves the configured staging
  mail leg only; validate Stripe key mode and endpoint secret match in the
  Stripe dashboard. Do not expose key prefixes in the response.
- Task 3 plan creation: invoke `create_plan` with the newly created test-mode
  yearly `price_` id, then verify the plan on the staging pricing page.
- Task 7: invoke the three fixed Tier-B send actions and confirm the bridge
  reports `trial_ends_at` restored before checking Gmail.
- Task 9: invoke the fixed invitation action, then open the emailed link.
- Task 10 fallback only: invoke the fixed cancellation action if the one-hour
  timer did not arrive; record its Tier B status honestly.
- Task 12: invoke the enqueue-failure action and verify one Honeybadger
  `LoopsClient::BadRequest` occurrence with the required stack.

Use the staging UI for sign-up, billing email, checkout, cancellation, and
password reset; use Stripe test mode for subscriptions/refund/replay; and
continue to record timestamps, event ids, inbox placement, attachments, and
links as the original plan requires. Never deploy/restart staging during the
one-hour cancellation window.

> **Checkpoint 2:** run `/review-changes-mini` after the original plan's Tasks
> 4–12 are complete. Confirm no scope beyond the bridge was added and all
> evidence needed for the results tables is captured.

### Task 5 [Master]: Complete dashboard checks and record COV-47 evidence

1. Perform original COV-47 Task 13 in Loops and Task 14 in the design document.
   The document records all eleven result rows, six link checks, eight behavior
   checks, webhook endpoint status, and every issue with a follow-up ticket.
2. Leave no empty cell: record an unperformed check with its reason rather than
   guessing. Do not put private environment values or passwords in the document.
3. Use the bridge cleanup action for the database-only part of original Task
   15; archive the Stripe product in test mode; record the decision on retaining
   the verification user/subscriptions.

### Task 6 [Master]: Remove bridge, restore staging deployment, and verify

1. Delete the bridge route/controller/tests and all bridge-only configuration
   references from the branch. Commit and push the removal separately.
2. Deploy the removal commit to staging, confirm bridge URLs return `404`, then
   return Render to the latest linked `main` commit and re-enable auto-deploy.
   Preserve the standing recipient allowlist; remove only the temporary
   operator variable.
3. Run `mise exec -- bin/rails test`, `mise exec -- bin/rubocop`,
   `git diff --check`, and inspect `git diff origin/main...` to confirm that
   only COV-47's completed design document remains. Confirm no temporary route,
   controller, tests, tokens, credentials, or recipient addresses remain.

> **Checkpoint 3:** run `/review-changes-mini` once after Tasks 5–6. The final
> branch must contain the completed COV-47 design document only. Then run
> `/prompts:review-changes` for the full branch review.

## Dependencies

- Tasks 1 → 2 → 3 are serial; the bridge cannot deploy before its security
  contract is tested and reviewed.
- Task 4 depends on Task 3.
- Task 5 depends on all sends in Task 4.
- Task 6 is mandatory after Task 5, even if a verification result fails.
- Nothing parallelises safely: this is one authenticated operator, one staging
  service, and one cancellation timer.
