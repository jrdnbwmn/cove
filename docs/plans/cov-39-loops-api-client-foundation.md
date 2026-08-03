> Ticket: COV-39
> Branch: feature/cov-39-loops-api-client-foundation

# Plan: Loops API client foundation and per-environment credentials

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Build and test the transactional Loops API client | Master | ✅ |
| 2 | 1 | 1 | Add and wire the retrying Action Mailer delivery job | Master | ✅ |
| 3 | 2 | 2 | Add staging and production Loops credentials safely | Master | ✅ |

## Prerequisites

- Design: `docs/designs/cov-39-loops-api-client-foundation.md`
- Prototype: None
- Feature branch exists: `feature/cov-39-loops-api-client-foundation`
- Backend-only: no views, components, routes, models, migrations, or UI work
- Before every Rails command:
  `export PATH="$HOME/.local/share/mise/shims:$PATH"`
- The design is currently untracked; plan approval must commit the design and plan
  together so `/prompts:execute-plan` starts from a clean worktree.
- Credential state verified 2026-08-03:
  - `config/credentials/staging.key` and `production.key` are absent from this
    checkout, the main checkout, and sibling Cove worktrees.
  - `RAILS_MASTER_KEY` is unset.
  - `production.yml.enc` is a substantial existing encrypted credential set, not
    an empty disposable file. Never delete or replace it without separate explicit
    approval.
  - Staging's matching key should be recovered from Render's `cove-staging`
    `RAILS_MASTER_KEY`.
  - Production credential work requires recovering its matching key. If it cannot
    be recovered, report that acceptance criterion as blocked; do not regenerate
    the encrypted file automatically.

## Tasks

### Task 1 [Master]: Build the transactional Loops API client

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/clients/application_client.rb`,
`test/clients/application_client_test.rb`, and
`lib/jumpstart/lib/generators/api_client/templates/client.rb.tt` for inheritance,
HTTP, credential-factory, and WebMock patterns.

**In scope:**

- Add `app/clients/loops_client.rb` and `test/clients/loops_client_test.rb`.
- Send transactional email through
  `POST https://app.loops.so/api/v1/transactional`.
- Authenticate with the `loops.api_key` environment credential.
- Generate deterministic, recipient-specific SHA-256 idempotency keys.
- Map Loops-specific 400, 409, and 413 responses while delegating all existing
  status handling to `ApplicationClient`.
- Suppress transactional-send 409 conflicts as successful duplicate sends.
- Set two-second open and five-second read timeouts.

**NOT in scope:**

- Gems, initializers, `config/loops.yml`, attachments, contacts, campaigns,
  delivery methods, mailer changes, or live Loops calls.
- Globally suppressing 409 responses; only `send_transactional` treats a conflict
  as success.
- Nested `dataVariables` canonicalization; Loops transactional variables are flat.

**Build order:**

1. **Test:** create `test/clients/loops_client_test.rb` first, with user-facing
   behavior tests proving:
   - A successful call returns `true` and issues exactly one authorized POST with
     `email`, `transactionalId`, `addToAudience: false`, `dataVariables`, and the
     idempotency header.
   - Passing `data_variables: {addToAudience: true}` cannot override the top-level
     `false`.
   - Identical logical sends—including hashes with different key order—use the
     same key; different recipients use different keys; every key is at most 100
     characters.
   - A 409 returns `true` without raising.
   - 400 and 413 raise the new Loops-specific classes; 422, 429, and 500 retain
     the inherited Loops subclasses.
   - The credential-backed factory passes the configured token, and the client
     exposes the specified timeouts.
2. **Implement:** add `LoopsClient < ApplicationClient` with:
   - `BASE_URI`, credential-backed `.client`, timeout overrides, and
     `send_transactional`.
   - `BadRequest`, `Conflict`, and `PayloadTooLarge` subclasses.
   - A deterministic SHA-256 key over the transactional ID, email, and
     stringified/sorted variables.
   - An `# AIDEV-NOTE:` warning callers not to include retry-varying values such
     as `Time.current` or `SecureRandom`.
   - `handle_response` branches for 400/409/413 followed by `super`.
3. **Verify:**
   `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/clients/loops_client_test.rb`

### Task 2 [Master]: Add and wire the retrying mail delivery job

**Skills:** write-tests
**Reference:** Read `app/jobs/application_job.rb`, `config/application.rb`, and
the retry rationale in `docs/designs/cov-37-loops-architecture.md`.

**In scope:**

- Add `app/jobs/loops_mail_delivery_job.rb`.
- Add `test/jobs/loops_mail_delivery_job_test.rb`, creating `test/jobs/` as needed.
- Configure all Action Mailer `deliver_later` calls to use the custom job.
- Retry `LoopsClient::RateLimit`, `LoopsClient::InternalError`,
  `Net::OpenTimeout`, and `Net::ReadTimeout` with polynomial backoff and Active
  Job's default five attempts.
- Use `"LoopsMailDeliveryJob"` in application configuration. Rails 8.1's Action
  Mailer railtie constantizes this configuration value during boot before mail
  delivery calls `.set`, resolving the design's first open question.

**NOT in scope:**

- Changing `ApplicationJob`, queue adapters, retry attempt counts, queue names, or
  production/staging delivery methods.
- End-to-end Loops delivery testing; no Loops mail delivery method exists until
  COV-43.
- Retrying every error from `ApplicationClient::NET_HTTP_ERRORS`.

**Build order:**

1. **Test:** create `test/jobs/loops_mail_delivery_job_test.rb` first and prove:
   - `LoopsMailDeliveryJob` inherits from `ActionMailer::MailDeliveryJob`.
   - The configured `ActionMailer::Base.delivery_job` resolves to
     `LoopsMailDeliveryJob`.
   - Its rescue-handler declarations include all four retryable exception classes.
2. **Implement:** add the delivery job with one `retry_on` declaration and wire
   `config.action_mailer.delivery_job = "LoopsMailDeliveryJob"` in
   `config/application.rb`.
3. **Verify focused test:**
   `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/jobs/loops_mail_delivery_job_test.rb`
4. **Verify phase:** run, in this order:
   - `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test`
   - `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rubocop`
   - `git diff` and `git status --short`
5. **Review:** run `review-changes-mini` once for Checkpoint 1, covering Tasks
   1–2. If these tasks were executed as a parallel batch, the master runs the
   review after the whole batch returns rather than either task running it
   independently.

### Task 3 [Master]: Add the per-environment Loops credentials safely

**Skills:** loops-cli, conductor
**Reference:** Read the design's "Blocked: the credentials ACs are a manual
handoff" section, `.gitignore`, `.conductor/settings.toml`, and
`docs/designs/done/cov-38-loops-setup.md`.

**In scope:**

- Keep all decryption keys and Loops API-key values in the user's terminal/editor;
  never paste them into chat.
- Recover `config/credentials/staging.key` from Render's `cove-staging`
  `RAILS_MASTER_KEY`, then add the `cove-staging` Loops key at `loops.api_key`.
- Recover the matching production decryption key from secure storage or backup,
  then add the `cove-production` Loops key at `loops.api_key`.
- Preserve all existing encrypted credential values.
- Store decryption keys durably outside the disposable worktree; Conductor's
  current setup script does not copy staging or production keys.
- Verify the encrypted files round-trip and that no `.key` file is stageable.

**NOT in scope:**

- Printing, logging, committing, or sending any secret to an agent.
- Deleting or replacing `production.yml.enc`.
- Regenerating production credentials without a separately reviewed and
  explicitly approved rotation plan.
- Editing `.conductor/settings.toml`, provisioning production, or changing Render
  environment variables.
- Assuming the Loops CLI can export raw stored keys; it masks them. Use the
  original securely saved COV-38 values or rotate them through the Loops dashboard
  if they are unavailable.

**Build order:**

1. **Test:** before editing:
   - Confirm the matching environment key decrypts with
     `bin/rails credentials:show --environment <environment> >/dev/null`.
   - Verify the named Loops profile with
     `loops api-key --team cove-staging -o json` or `--team cove-production`.
   - If production cannot decrypt, stop that environment's work and report the
     blocker. Do not modify its encrypted file.
2. **Implement:** for each decryptable environment, the user runs:
   - `VISUAL="zed --wait" bin/rails credentials:edit --environment staging`
   - `VISUAL="zed --wait" bin/rails credentials:edit --environment production`
   Add only:
   ```yaml
   loops:
     api_key: <environment-specific value>
   ```
   while preserving every existing entry.
3. **Verify:** for each edited environment:
   - Run `bin/rails credentials:show --environment <environment> | grep -c loops`
     and require exactly one match without printing the secret.
   - Reopen and exit `credentials:edit` to prove the round trip.
   - Run
     `git diff --stat -- config/credentials/staging.yml.enc config/credentials/production.yml.enc`.
   - Run `git status --short` and
     `git check-ignore config/credentials/staging.key config/credentials/production.key`;
     no `.key` file may be staged.
4. **Review:** run `review-changes-mini` once for Checkpoint 2 after both
   credential outcomes are settled. If executed as a parallel batch, the master
   runs this review once after the whole batch returns.

## Task Dependencies

- Task 1 establishes `LoopsClient` and its exception classes.
- Task 2 depends on Task 1 because its retry declarations reference those classes.
- Task 3 is operationally independent of the client code but follows Checkpoint 1
  so the tested foundation can ship even if production credential recovery
  remains blocked.
- No implementation task should be delegated: Task 1 sets the pattern, Task 2
  modifies shared application configuration, and Task 3 requires user-owned
  secrets and recovery decisions.
- Phase 1 is independently deployable because no delivery method invokes Loops
  yet. Phase 2 completes the environment credential acceptance criteria when the
  matching decryption keys are available.
