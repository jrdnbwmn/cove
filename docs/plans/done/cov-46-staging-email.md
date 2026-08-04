> Ticket: COV-46
> Branch: feature/cov-46-decide-and-apply-staging-email-behavior

# Plan: Guarded staging email delivery

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Build and test the fail-closed recipient interceptor | Master | ✅ |
| 2 | 1 | 1 | Enable guarded Loops delivery in staging | Master | ✅ |
| 3 | 1 | 1 | Declare the Render allowlist input without committing values | Master | ✅ |
| 4 | 1 | 2 | Audit staging users and configure the private allowlist | Master | ✅ |
| 5 | 1 | 2 | Deploy the feature commit and prove allowed/blocked delivery | Master | ✅ |
| 6 | 1 | 2 | Remove smoke wiring, restore Render, and run final gates | Master | ✅ |

All tasks remain with Master. The implementation touches shared mail delivery
and deployment configuration, while the remaining tasks require Render access,
secrets, or live operational judgment.

## Prerequisites

- Design: [`docs/designs/cov-46-staging-email.md`](../designs/cov-46-staging-email.md)
- Prototype: None
- Feature branch exists: `feature/cov-46-decide-and-apply-staging-email-behavior`
- Run Rails and RuboCop commands through mise using `mise exec --`.
- The design is currently untracked. Plan approval commits the design and plan
  together so execution starts from a clean worktree.
- Architecture maps and the component catalog were reviewed. No routes, models,
  migrations, persistent views, or components change.
- `config/credentials/staging.key` is currently absent locally. Task 4 restores
  it from Render without exposing it or committing it.
- `psql` and the Render CLI are installed locally.
- Free Render web services do not provide dashboard shell or one-off-job access,
  so the live-user audit uses a temporary, narrowly scoped external Postgres
  connection instead. See the Render free-service and Postgres connection docs.

## Tasks

### Task 1 [Master]: Build the fail-closed staging recipient interceptor

**Skills:** loops-api, write-tests
**Reference:** Read [`app/mailers/loops_delivery.rb`](../../app/mailers/loops_delivery.rb),
[`test/mailers/loops_delivery_test.rb`](../../test/mailers/loops_delivery_test.rb),
and [`app/jobs/loops_mail_delivery_job.rb`](../../app/jobs/loops_mail_delivery_job.rb).

**In scope:**

- Create `StagingEmailRecipientGuard` as an Action Mailer delivery interceptor.
- Add dedicated `InvalidAllowlist` and `BlockedRecipient` errors.
- Parse a comma-separated allowlist by trimming whitespace, discarding empty
  segments, normalizing case, and validating each remaining address with
  Ruby's `URI::MailTo::EMAIL_REGEXP`.
- Fail configuration when the input is missing, blank, contains no recipients,
  or contains any nonblank invalid entry.
- Check every `To`, `CC`, and `BCC` recipient before delivery.
- Use exact, case-insensitive comparison: no plus-address collapsing, aliases,
  or domain wildcards.
- Block the entire message when any destination is absent, naming only the
  rejected address rather than exposing the allowlist.
- Prove the policy error is not included in `LoopsMailDeliveryJob`'s retry
  handlers.

**NOT in scope:**

- No edits to `LoopsDelivery`, `LoopsClient`, Loops templates, contacts,
  marketing events, or retry policy for transport failures.
- No production registration.
- No silent filtering, recipient rewriting, or partial delivery.
- No new gem.

**Build order:**

1. **Test:** Create `test/mailers/staging_email_recipient_guard_test.rb` and
   extend `test/jobs/loops_mail_delivery_job_test.rb`. Cover:
   - Missing, blank, comma-only, and invalid allowlists fail configuration.
   - Valid entries are trimmed and compared case-insensitively.
   - Plus aliases and domain patterns are not inferred.
   - Allowed `To`, `CC`, and `BCC` values pass.
   - A blocked address in any field raises `BlockedRecipient`.
   - A mixed allowed/blocked message makes zero Loops HTTP requests.
   - An entirely allowed message continues through the real `LoopsDelivery`
     WebMock boundary.
   - The error exposes the rejected address but not the complete allowlist.
   - `BlockedRecipient` is absent from the delivery job's retryable exception
     list.
   Register the interceptor temporarily through `Mail.register_interceptor` and
   always unregister it in teardown/ensure so test-global state cannot leak.
2. **Implement:** Add `app/mailers/staging_email_recipient_guard.rb` with
   `configure!(raw_allowlist)` and `delivering_email(message)`. Store only the
   normalized process-local set.
3. **Verify:**
   `mise exec -- bin/rails test test/mailers/staging_email_recipient_guard_test.rb test/jobs/loops_mail_delivery_job_test.rb`

### Task 2 [Master]: Enable guarded Loops delivery in staging

**Skills:** write-tests
**Reference:** Read [`config/environments/staging.rb`](../../config/environments/staging.rb),
[`config/environments/production.rb`](../../config/environments/production.rb),
[`test/config/loops_mail_config_test.rb`](../../test/config/loops_mail_config_test.rb),
and [`test/config/job_adapter_test.rb`](../../test/config/job_adapter_test.rb).

**In scope:**

- Make staging structurally parallel with production by selecting `:loops`.
- Explicitly set staging `perform_deliveries = true`.
- Register only `"StagingEmailRecipientGuard"` through
  `config.action_mailer.interceptors`.
- During staging's `after_initialize`, configure the guard from
  `ENV["STAGING_EMAIL_RECIPIENT_ALLOWLIST"]`; invalid configuration must raise
  and abort boot.
- Remove the stale staging SMTP/provider assignment.
- Replace the existing staging email note with an `AIDEV-NOTE` stating that
  outbound email is live only for exact allowlisted recipients and that
  `perform_deliveries = false` is the emergency kill switch.
- Preserve staging's `:async` job adapter.
- Assert that `config/jumpstart.rb` still has `"email_provider" => ""`.

**NOT in scope:**

- No production delivery enablement or guard registration.
- No edits to `config/jumpstart.rb`, `Gemfile.jumpstart`, credentials,
  development, or test delivery behavior.
- Do not run the Jumpstart configuration generator or create a `Procfile`.
- No retry handling for policy rejection.

**Build order:**

1. **Test:** Update `test/config/loops_mail_config_test.rb` and
   `test/config/job_adapter_test.rb` first. Prove:
   - Staging selects `:loops`, enables delivery, registers the guard, and
     configures it from the environment during boot.
   - Staging contains no later SMTP or Jumpstart-provider override.
   - Production selects `:loops` but never references the staging guard.
   - Development remains `:mailbin`; test remains `:test`; neither registers
     the guard.
   - `config/jumpstart.rb` keeps the email provider blank.
   - The obsolete assertion that staging disables delivery is replaced by the
     guarded-live contract.
   Combined with Task 1's configuration-failure tests, these source assertions
   cover the fail-closed boot path without requiring CI to possess the staging
   encryption key.
2. **Implement:** Edit only `config/environments/staging.rb` with the delivery
   method, interceptor registration, initialization hook, explicit enablement,
   and updated safety note.
3. **Verify:**
   `mise exec -- bin/rails test test/config/loops_mail_config_test.rb test/config/job_adapter_test.rb test/mailers/staging_email_recipient_guard_test.rb`

### Task 3 [Master]: Declare the Render allowlist input safely

**Skills:** write-tests
**Reference:** Read [`render.yaml`](../../render.yaml) and
[`test/config/render_blueprint_test.rb`](../../test/config/render_blueprint_test.rb).

**In scope:**

- Add `STAGING_EMAIL_RECIPIENT_ALLOWLIST` to the active `cove-staging` service
  with `sync: false`.
- Keep the actual recipient values out of source control.
- Add a blueprint test proving the key exists, has `sync: false`, and has no
  checked-in `value`.
- Keep the dormant production service free of this staging-only variable.

**NOT in scope:**

- No recipient values, API keys, staging key, production variable, database
  changes, or Blueprint provisioning.
- No changes to the service branch, plan, commands, or active resource count.

**Build order:**

1. **Test:** Extend `test/config/render_blueprint_test.rb` with the staging-only,
   value-free environment-variable assertions and run it red.
2. **Implement:** Add the `sync: false` entry to `render.yaml`.
3. **Verify:**
   - `mise exec -- ruby test/config/render_blueprint_test.rb`
   - `mise exec -- bin/rails test test/config/`

> **Checkpoint 1 review:** After Tasks 1-3 are complete, run
> `review-changes-mini` exactly once covering the interceptor, environment
> configuration, Render declaration, tests, and the unchanged Jumpstart
> provider setting.

### Task 4 [Master]: Audit staging users and configure the private allowlist

**Skills:** chrome:control-chrome
**Reference:** Follow the manual activation boundary in
[`docs/designs/cov-46-staging-email.md`](../designs/cov-46-staging-email.md) and
the active service/database names in [`render.yaml`](../../render.yaml).

**In scope:**

- In Render, recover `RAILS_MASTER_KEY` without exposing it. The user handles
  reveal/copy and writes it locally with restrictive permissions:
  `umask 077; pbpaste > config/credentials/staging.key`.
- Verify decryption without printing credentials:
  `RAILS_MASTER_KEY=$(<config/credentials/staging.key) RAILS_ENV=staging mise exec -- bin/rails credentials:show >/dev/null`.
- In `cove-staging-db` networking, temporarily allow only Jordan's current
  public IP as a `/32`.
- Copy Render's external PSQL command into Jordan's terminal and privately run
  `SELECT id, email FROM users ORDER BY id;` with the pager disabled.
- Choose only exact inboxes Jordan controls. If none exists, create one through
  `/users/sign_up` while staging still runs `main` with deliveries disabled,
  then rerun the query.
- Remove the temporary database IP rule immediately, restoring no external
  access.
- In `cove-staging` -> Environment, have Jordan enter the comma-separated
  allowlist value. Never paste it into chat, screenshots, commits, plan notes,
  or PR text.
- Save the variable and confirm the resulting deploy of current `main` remains
  healthy before feature code is deployed.

**NOT in scope:**

- No deletion or editing of deployed users.
- No broad database IP rule, saved external connection URL, or committed
  staging key.
- No assumption that checked-in seed addresses describe the deployed database.
- No production environment variable or Loops key changes.

**Build order:**

1. **Test:** Audit every deployed user and confirm the selected allowlisted
   inboxes are controlled by Jordan.
2. **Implement:** Restore the ignored staging key, temporarily establish the
   database connection, remove it after the audit, and save the private Render
   variable.
3. **Verify:** Credential decryption exits zero; the database returns to no
   external access; Render shows the variable name as set without exposing it;
   `/up` returns 200.

### Task 5 [Master]: Deploy the feature commit and prove both delivery outcomes

**Skills:** chrome:control-chrome, loops-api
**Reference:** Read [`config/routes.rb`](../../config/routes.rb),
[`app/mailers/loops_devise_mailer.rb`](../../app/mailers/loops_devise_mailer.rb),
and [`test/controllers/users/passwords_controller_test.rb`](../../test/controllers/users/passwords_controller_test.rb).

**In scope:**

- After Checkpoint 1 is clean, commit and push the guarded-delivery
  implementation.
- Add one temporary staging-only smoke route that calls
  `LoopsDeviseMailer.password_change` for the fixed fabricated address
  `cov-46-blocked@example.invalid`.
- Mark the route `TEMPORARY` and condition it on `Rails.env.staging?`.
- Commit and push the smoke route separately.
- Use Render's "Deploy a specific commit" action for that smoke commit. This
  avoids changing the linked `main` branch; note that Render disables
  auto-deploy after a specific-commit deployment, so Task 6 must restore it.
- Confirm a missing local allowlist fails staging boot with `InvalidAllowlist`.
- Privately enter the same allowlist locally, then run the design's boot
  assertion:

  ```bash
  read -s "COV46_ALLOWLIST?Staging allowlist: "
  echo
  export STAGING_EMAIL_RECIPIENT_ALLOWLIST="$COV46_ALLOWLIST"
  RAILS_MASTER_KEY=$(<config/credentials/staging.key) RAILS_ENV=staging mise exec -- bin/rails runner "puts Rails.application.config.action_mailer.perform_deliveries"
  unset COV46_ALLOWLIST STAGING_EMAIL_RECIPIENT_ALLOWLIST
  ```

  Expected output: `true`.
- At `/users/password/new`, request a reset for the approved staging user and
  confirm the message reaches the owned inbox.
- Hit the temporary blocked-send route. Expect a loud
  `StagingEmailRecipientGuard::BlockedRecipient` failure.
- Confirm Render logs identify only the fabricated rejected address and the
  Loops dashboard contains no transactional send for it.
- Record only redacted results and timestamps, such as
  `[ALLOWLISTED_INBOX] arrived` and `[FABRICATED_ADDRESS] blocked`.

**NOT in scope:**

- No direct `LoopsClient` calls, contacts, audience mutations, marketing
  events, COV-47's eleven-message run, or production delivery.
- No parameterized smoke route or route capable of sending to arbitrary
  addresses.
- No actual inbox or allowlist values in repository artifacts.
- Do not leave the temporary route for the PR.

**Build order:**

1. **Test:** Run the missing-allowlist boot failure first, then deploy the smoke
   commit.
2. **Implement:** Add the temporary route, commit/push, and deploy that exact
   commit.
3. **Verify:** The configured boot prints `true`; the allowed reset arrives;
   the fabricated send raises before Loops; no fabricated-address transaction
   appears in Loops.

### Task 6 [Master]: Remove smoke wiring, restore Render, and run final gates

**Skills:** chrome:control-chrome, review-changes-mini
**Reference:** Re-read every acceptance criterion in
[`docs/designs/cov-46-staging-email.md`](../designs/cov-46-staging-email.md).

**In scope:**

- Delete the temporary smoke route and comment, commit, and push.
- Deploy the cleaned feature commit once and confirm the smoke URL is 404 while
  staging boots successfully with guarded delivery.
- Return Render to the latest commit from its linked `main` branch and restore
  Auto-Deploy to its previous setting.
- Reload Render settings to confirm the linked branch is `main` and auto-deploy
  is enabled.
- Confirm the allowlist environment variable remains saved for the eventual
  merge deployment.
- Run the complete Rails suite, RuboCop, whitespace checks, and final diff
  audit.
- Verify the final branch contains no smoke endpoint, recipient values,
  credentials, production guard, `config/jumpstart.rb` change, or `Procfile`.

**NOT in scope:**

- No PR creation, merge, branch deletion, production activation, COV-47
  verification, COV-51 marketing guard, or Loops template work.
- Do not remove the Render allowlist after restoring `main`; `main` still has
  the safe `perform_deliveries = false` behavior until this ticket merges.

**Build order:**

1. **Test:** Run the focused suite, then the full suite:
   - `mise exec -- bin/rails test test/mailers/staging_email_recipient_guard_test.rb test/jobs/loops_mail_delivery_job_test.rb test/config/`
   - `mise exec -- bin/rails test`
2. **Implement:** Remove the route, commit/push, deploy the cleaned commit,
   confirm 404, then restore latest `main` and Auto-Deploy.
3. **Verify:**
   - `mise exec -- bin/rails test`
   - `mise exec -- bin/rubocop`
   - `git diff --check`
   - `git diff origin/main... -- config/routes.rb config/jumpstart.rb`
   - `git status --short`
   - `git diff origin/main...`
   The routes/Jumpstart diff must be empty. Inspect the complete diff for
   secrets, actual addresses, debug artifacts, and unrelated changes.

> **Checkpoint 2 review:** After Tasks 4-6 are complete, run
> `review-changes-mini` exactly once covering the live audit/verification
> evidence, final code, tests, cleanup, and restored Render settings.

## Task Dependencies

- Task 2 depends on Task 1 because staging cannot register a guard that does
  not exist.
- Task 3 is code-independent but remains in Checkpoint 1 because it documents
  the environment input required by Task 2.
- Task 4 depends on Checkpoint 1 being complete and reviewed.
- Task 5 depends on Task 4: the audited allowlist must exist in Render before
  the enabling commit is deployed.
- Task 6 depends on Task 5 and must always run, even if live verification fails,
  because it removes the temporary route and restores Render's normal
  deployment behavior.
- No tasks run in parallel. The safety-sensitive sequence is guard ->
  configuration -> private activation -> feature deployment -> proof -> cleanup.
