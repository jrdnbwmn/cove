> Ticket: COV-79
> Branch: feature/cov-79-staging-seed-guard-superadmin-bootstrap

# Plan: Staging seed guard and superadmin bootstrap

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Implement and test the idempotent admin bootstrap service | Master | |
| 2 | 1 | 1 | Add and test the thin `admin:bootstrap` rake task | subagent | |
| 3 | 1 | 1 | Restrict demo seeds to local environments and add regression coverage | subagent | |
| 4 | 1 | 2 | Wire bootstrap into Render commands, test the blueprint, and prepare staging | Master | |

## Prerequisites

- Design: [`docs/designs/cov-79-staging-seed-guard-superadmin-bootstrap.md`](../designs/cov-79-staging-seed-guard-superadmin-bootstrap.md)
- Prototype: None
- Feature branch exists: `feature/cov-79-staging-seed-guard-superadmin-bootstrap`
- Before Rails verification, prepend `$HOME/.local/share/mise/shims` to `PATH` and confirm `ruby -v` reports 4.0.5.
- Browser-assisted operations use an available authenticated browser session. Private admin-email and password values are entered by Jordan and are never copied into chat, source control, screenshots, or task notes.

## Tasks

### Task 1 [Master]: Implement the admin bootstrap service

**Skills:** write-tests, fix-bug
**Reference:** Read [`app/services/loops_webhook_event_processor.rb`](../../app/services/loops_webhook_event_processor.rb) and [`test/services/loops_webhook_event_processor_test.rb`](../../test/services/loops_webhook_event_processor_test.rb) for the service/test structure; [`lib/jumpstart/lib/jumpstart.rb`](../../lib/jumpstart/lib/jumpstart.rb) for `grant_system_admin!`; and the `User::Authenticatable`, `User::Agreements`, `User::Profile`, and `User::AccountCreatedEmail` concerns for normalization, required attributes, names, and callbacks.

**In scope:**

- Add `app/services/admin_bootstrap.rb` with `AdminBootstrap.call(email:, name:)` as its only public API.
- For a blank email, emit `[admin:bootstrap] skipped: BOOTSTRAP_ADMIN_EMAIL unset` through both `puts` and `Rails.logger`, then return without writes.
- Find an existing normalized email first. Only a missing user may be created, using `Devise.friendly_token(32)`, `terms_of_service: "1"`, and `confirmed_at: Time.current`.
- Normalize the supplied name with `squish`, default blank input to `Cove Admin`, and split once into `first_name` plus the remaining `last_name`.
- Preserve every existing user's password, name, and marketing-consent fields. Grant admin only when `user.admin?` is false.
- Log created/found and granted/already-admin outcomes with an `[admin:bootstrap]` prefix, without logging the generated password. Rescue `StandardError`, log its class/message at error level and through `puts`, and return normally.

**NOT in scope:**

- Reading `ENV` inside the service.
- Changing user validations, callbacks, mail delivery, marketing consent, or `Jumpstart.grant_system_admin!`.
- Adding migrations, fixtures, stored plaintext passwords, or production-specific behavior.

**Build order:**

1. **Test:** create `test/services/admin_bootstrap_test.rb` covering the six design cases: blank email no-op; new default-named confirmed admin; repeated calls create no duplicate and preserve the encrypted password/name; existing non-admin promotion without profile/password/consent changes; already-admin no-op without another grant; and invalid email logging without a raised exception. Stub the generated token where needed and assert it appears neither in the return value nor captured stdout/logger output.
2. **Implement:** add `app/services/admin_bootstrap.rb` with private name-splitting and dual-output logging helpers. Return the created/found `User` on success and `nil` for skip/error paths; never return the generated plaintext password.
3. **Verify:** `PATH="$HOME/.local/share/mise/shims:$PATH" bin/rails test test/services/admin_bootstrap_test.rb`

### Task 2 [subagent]: Add the bootstrap rake task

**Skills:** write-tests
**Reference:** Read [`lib/tasks/loops_contacts.rake`](../../lib/tasks/loops_contacts.rake) and [`test/tasks/loops_contacts_test.rb`](../../test/tasks/loops_contacts_test.rb) for task loading, invocation, output capture, and Rake application cleanup.

**In scope:**

- Add `lib/tasks/admin.rake` defining `admin:bootstrap` with the exact description and `:environment` dependency from the design.
- Delegate once to `AdminBootstrap.call`, passing `ENV["BOOTSTRAP_ADMIN_EMAIL"]` and `ENV["BOOTSTRAP_ADMIN_NAME"]`.
- Add isolated task tests that restore `Rake.application` and any temporarily changed environment variables.

**NOT in scope:**

- User lookup, creation, admin-grant, rescue, or logging logic in the rake task.
- New command-line arguments or additional environment variables.
- Invoking the task during tests against staging or any external service.

**Build order:**

1. **Test:** create `test/tasks/admin_test.rb`. Assert exact email/name keyword forwarding with a stubbed service, then invoke the real service with both variables unset and assert no `User` is created and the tested skip message is printed. Restore environment keys in `ensure`.
2. **Implement:** add `lib/tasks/admin.rake` as the thin environment-variable wrapper specified by the design.
3. **Verify:** `PATH="$HOME/.local/share/mise/shims:$PATH" bin/rails test test/tasks/admin_test.rb`

### Task 3 [subagent]: Guard demo seeds outside local environments

**Skills:** write-tests, fix-bug
**Reference:** Read [`db/seeds.rb`](../../db/seeds.rb) for the complete guarded demo-data block and existing AIDEV note.

**In scope:**

- Add regression coverage proving staging and production do not create demo users, accounts, memberships, or plans when the seed file is loaded.
- Replace only the outer `unless Rails.env.production?` guard with `if Rails.env.local?`.

**NOT in scope:**

- Editing, renaming, or removing individual development/test seed records.
- Resetting or otherwise mutating the real staging database.
- Changing seed callbacks, fake subscriptions, or the seeded admin grant.

**Build order:**

1. **Test:** create `test/config/seeds_test.rb`. For both `staging` and `production`, stub `Rails.env` with an `ActiveSupport::EnvironmentInquirer`, load `db/seeds.rb`, assert no differences in `User`, `Account`, `AccountUser`, or `Plan` counts, and assert no `@cove.test` demo user appears.
2. **Implement:** change the single outer guard in `db/seeds.rb` to `if Rails.env.local?`, leaving the guarded body untouched.
3. **Verify:** `PATH="$HOME/.local/share/mise/shims:$PATH" bin/rails test test/config/seeds_test.rb`
4. **Checkpoint 1 review:** after Tasks 1-3 are complete, run `review-changes-mini` once over the entire checkpoint. Because Tasks 2 and 3 may run as a parallel batch, the master runs this review after both subagents return.

### Task 4 [Master]: Wire bootstrap into Render and prepare the pre-merge environment

**Skills:** write-tests, browser:control-in-app-browser
**Reference:** Read [`render.yaml`](../../render.yaml) and [`test/config/render_blueprint_test.rb`](../../test/config/render_blueprint_test.rb), which already parse the active staging service and safely reconstruct the commented production service. Re-read the ordered operator runbook in the approved design before any browser action.

**In scope:**

- Extend the blueprint test to require staging's exact command: `bundle exec rails db:prepare admin:bootstrap && bundle exec rails server`.
- Update the dormant-production assertion to require `bundle exec rails db:prepare admin:bootstrap` as its exact `preDeployCommand`.
- Change those two commands in `render.yaml`, preserving the production block's dormant/commented structure and every unrelated setting.
- Before merge, use an available authenticated browser to navigate to the `cove-staging` Render environment settings. Prepare the `BOOTSTRAP_ADMIN_EMAIL`, optional `BOOTSTRAP_ADMIN_NAME`, and `STAGING_EMAIL_RECIPIENT_ALLOWLIST` fields; pause for Jordan to enter private values, then save without reproducing them in chat or evidence.
- If browser control is unavailable or Render is not authenticated, stop only the browser portion and give Jordan exact numbered fallback steps. Do not claim the environment is prepared without observable confirmation.

**NOT in scope:**

- Adding actual admin email/name values to `render.yaml` or source control.
- Merging the pull request or activating/deploying the production service.
- Resetting staging before the merged bootstrap code has deployed successfully.
- Reading Jordan's inbox, viewing or storing a reset token, or choosing/storing the admin password.
- Using a throwaway database-wipe commit or changing any Render resource other than the explicitly named staging service/database.

**Build order:**

1. **Test:** update `test/config/render_blueprint_test.rb` with the exact staging `startCommand` assertion and adjusted dormant-production `preDeployCommand` assertion. Retain the existing proof that production resources remain commented out.
2. **Implement:** update only the staging `startCommand` and dormant production `preDeployCommand` in `render.yaml`.
3. **Verify:** run `PATH="$HOME/.local/share/mise/shims:$PATH" ruby -v`, then `PATH="$HOME/.local/share/mise/shims:$PATH" bin/rails test test/config/render_blueprint_test.rb`, followed by `PATH="$HOME/.local/share/mise/shims:$PATH" bin/rails test` and `git diff`.
4. **Prepare staging before merge:** through the browser, open the named staging service's environment settings, let Jordan privately supply the bootstrap identity and allowlist update, save them, and verify the settings change through Render's resulting observable service/deploy state. A redeploy of the current `main` may occur, but do not reset the database and do not expect bootstrap logs until the new code is merged.
5. **Checkpoint 2 review:** run `review-changes-mini` once over Task 4 after code verification and the pre-merge environment preparation are complete, or record the browser preparation as an explicit access blocker if browser/authentication is unavailable.

## Task Dependencies

- Task 1 goes first and establishes the service contract consumed by the rake task.
- Task 2 depends on Task 1.
- Task 3 has no code dependency on Tasks 1-2 and can run in parallel with Task 2 after Task 1 is established; their file sets do not overlap.
- Task 4 depends on Task 2 so the deployment command never references a missing task, and begins only after checkpoint 1 review.
- Jordan reviews and merges the pull request. No agent may merge it.
- After Jordan reports the merge and explicitly asks to continue, the master uses an available authenticated browser for the remaining runbook: watch the automatic `cove-staging` deploy; require successful `[admin:bootstrap]` create/grant evidence while the old seeded admin still exists; stop on missing/error output; inspect the exact reset/recreation controls for `cove-staging-db`; and ask Jordan for explicit confirmation immediately before the destructive action.
- After that confirmation, the master may reset/recreate only `cove-staging-db`, verify that `DATABASE_URL` relinks (using blueprint sync if the UI requires it), redeploy, and require a second successful bootstrap log on the clean database. If Render cannot prove the relink, stop and ask rather than improvising a code-based wipe.
- The master then opens staging's existing forgot-password flow. Jordan privately enters the email, uses the email link, and chooses the password. After Jordan returns an authenticated browser session, the master verifies `/admin/plans` loads and that no `@cove.test` users appear under `/admin/users`.
- If browser control or authentication is unavailable during any post-merge step, give numbered instructions only for the unresolved portion and treat the corresponding acceptance evidence as blocked rather than inferred.
