> Ticket: COV-68
> Branch: feature/cov-68-transactional-account-created-email

# Plan: Transactional account-created email

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Create the account-created Loops draft | Master | ✅ |
| 2 | 1 | 1 | Author and validate the approved LMX | Master | ✅ |
| 3 | 1 | 1 | Preview, publish, and record the template | Master | ✅ |
| 4 | 2 | 2 | Add the mapping and bodyless UserMailer | Master | ✅ |
| 5 | 2 | 2 | Enqueue account-created mail after user creation | Master | ✅ |
| 6 | 2 | 3 | Verify password and invited-user registration | subagent | ✅ |
| 7 | 2 | 3 | Verify OAuth signup and audit callback blast radius | subagent | ✅ |
| 8 | 3 | 4 | Run final gates and staging inbox verification | Master | ✅ |

## Prerequisites

- Design: [`docs/designs/cov-68-account-created-email.md`](../designs/cov-68-account-created-email.md)
- Prototype: None; the approved design reuses the existing `Cove` Loops theme unchanged and specifies exact copy. This is a constrained copy implementation, so no image-generation exploration is needed.
- Feature branch exists: `feature/cov-68-transactional-account-created-email`
- Run Rails commands through mise using `mise exec --`.
- The design is currently untracked. Plan approval will commit the design and plan together so execution begins from a clean worktree.
- Architecture maps and the component catalog were reviewed. No routes, migrations, Rails views, ViewComponents, or component-library additions are required.
- Read-only Loops verification on 2026-08-25 confirmed that `cove-cli` resolves to team `Cove`, `account-created` does not exist, the `Cove` theme remains `cmsdnxho301lh0j17qh8ltsre`, and `Unsorted` remains `cms4sm6bn00mj0jyk7r6nvhmi`.
- Before Task 3, the user supplies one real preview inbox without recording its address in source control.
- Before Task 8, the user confirms two distinct addresses are on `STAGING_EMAIL_RECIPIENT_ALLOWLIST`; one must be an unused Google account suitable for OAuth signup. Reusing one address for both flows risks Loops’ content-derived idempotency suppression.
- `cove-staging` normally deploys `main`. Task 8 temporarily points it at this feature branch and restores `main` before completion.

## Tasks

**Phase 1 — Publish the Loops template**

### Task 1 [Master]: Create the account-created Loops draft

**Skills:** loops-cli, loops-lmx
**Reference:** Read [`docs/designs/cov-68-account-created-email.md`](../designs/cov-68-account-created-email.md) and inspect current state with the installed CLI’s `loops agent-context`.
**Prototype:** None; preserve the approved copy and existing `Cove` theme.

**In scope:**

- Run all commands with `LOOPS_API_KEY` unset and `--team cove-cli`.
- Validate that the key reports team `Cove`.
- Re-list transactional emails immediately before writing and stop if `account-created` already exists.
- Create exactly one `account-created` transactional email in `Unsorted`.
- Record its transactional ID, draft email-message ID, and initial revision ID in a gitignored `.context` handoff file.

**NOT in scope:**

- No second template, theme, component, contact, list, workflow, campaign, or audience change.
- Do not publish, preview, send, or add any app mapping yet.
- Do not expose or persist an API key.

**Build order:**

1. **Test:** Run `env -u LOOPS_API_KEY loops api-key --team cove-cli --output json` and `env -u LOOPS_API_KEY loops transactional list --team cove-cli --per-page 50 --output json`; require team `Cove` and no `account-created` result.
2. **Implement:** Run `env -u LOOPS_API_KEY loops transactional create --name account-created --transactional-group-id cms4sm6bn00mj0jyk7r6nvhmi --team cove-cli --output json`; save only the returned non-secret IDs in `.context/cov-68-loops-ids.md`.
3. **Verify:** Run `env -u LOOPS_API_KEY loops transactional get <transactional-id> --team cove-cli --output json`; require the correct name/group, a draft message, and no published message.

### Task 2 [Master]: Author and validate the approved LMX

**Skills:** loops-cli, loops-lmx
**Reference:** Read the template contract in [`docs/designs/cov-68-account-created-email.md`](../designs/cov-68-account-created-email.md) and the existing published auth-message pattern returned by `loops email-messages get cmsdnzdui02k30jx7j71bp0sk`.
**Prototype:** None; use the approved hierarchy and the existing theme defaults.

**In scope:**

- Create `.context/cov-68-account-created.lmx` with one `Style`, one H1, two body paragraphs, one CTA button, and the sign-off.
- Use `{data.recipient_email}` and `{data.sign_in_url}` only.
- Preserve the exact approved copy, including the bold address and sign-off.
- Update the draft with the approved subject, preview text, sender, Reply-To, language, styled format, and LMX using the recorded revision ID.
- Require zero LMX warnings and a clean Guardian result.

**NOT in scope:**

- No images, components, contact variables, fallback variables, extra links, manual legal footer, or copy changes.
- Do not use `--force`; preserve revision safety with `--expected-revision-id`.
- Do not publish or send a preview yet.

**Build order:**

1. **Test:** Validate the LMX against the skill checklist: PascalCase tags, `<Style themeId="cmsdnxho301lh0j17qh8ltsre" />`, exact `{data.*}` variables, CTA `href`, valid nesting, and no unsupported attributes.
2. **Implement:** Update the recorded draft using `loops email-messages update <draft-message-id> --expected-revision-id <revision-id>`, setting:
   - Subject: `Your Cove account is ready`
   - Preview: `Here's the address it's on, and how to sign in.`
   - From: `Cove` / `notify`
   - Reply-To: `support@covehomeschool.com`
   - Language: `en`
   - Format: `styled`
   - LMX file: `.context/cov-68-account-created.lmx`
3. **Verify:** Run `env -u LOOPS_API_KEY loops email-messages get <draft-message-id> --team cove-cli --output json` and `env -u LOOPS_API_KEY loops email-messages guardian <draft-message-id> --team cove-cli --output json`; require exact metadata, exact variables, no warnings, and a clean Guardian result.

### Task 3 [Master]: Preview, publish, and record the template

**Skills:** loops-cli, loops-lmx, review-changes-mini
**Reference:** Read the live-verification and idempotency sections in [`docs/designs/cov-68-account-created-email.md`](../designs/cov-68-account-created-email.md).
**Prototype:** The fresh Loops preview becomes the visual reference; compare it against the approved hierarchy and existing `Cove` theme.

**In scope:**

- Send one preview to a user-supplied inbox with a real staging sign-in URL and representative recipient value.
- Pause for user confirmation of styled rendering, images-blocked rendering, the plain-text alternative, and the CTA destination.
- Publish only after that confirmation.
- Verify published status and exactly `recipient_email` plus `sign_in_url`.
- Replace `recorded at execution` in the design with the real transactional ID.

**NOT in scope:**

- Do not publish if Guardian, rendering, plain text, or CTA substitution is wrong.
- Do not send a transactional delivery, add the preview recipient to the audience, or reuse a failed draft by creating another template.
- Do not place the preview address in repository files, `.context`, or the transcript.

**Build order:**

1. **Test:** Send one preview with `loops email-messages preview <draft-message-id>` using user-owned recipient input, `recipient_email`, and `sign_in_url=https://staging.covehomeschool.com/users/sign_in`; the user confirms all four render checks.
2. **Implement:** Run `env -u LOOPS_API_KEY loops transactional publish <transactional-id> --team cove-cli --output json`, then add the resulting ID to the design’s external-object table.
3. **Verify:** Re-run `transactional get` and `email-messages get`; require a published message, no remaining draft, the exact subject/sender/Reply-To/LMX, and exactly the two declared variables.
4. **Review:** After Tasks 1–3 finish, run `review-changes-mini` exactly once for Checkpoint 1, covering the external template contract and the design’s recorded ID.

**Phase 2 — Wire Rails and pin signup behavior**

### Task 4 [Master]: Add the mapping and bodyless UserMailer

**Skills:** loops-api, write-tests
**Reference:** Read [`app/mailers/account_mailer.rb`](../../app/mailers/account_mailer.rb), [`app/mailers/loops_devise_mailer.rb`](../../app/mailers/loops_devise_mailer.rb), [`app/mailers/concerns/loops_transactional.rb`](../../app/mailers/concerns/loops_transactional.rb), and [`test/mailers/account_mailer_test.rb`](../../test/mailers/account_mailer_test.rb).

**In scope:**

- Add `account_created: <published-id>` as the first transactional mapping in `config/loops.yml`.
- Update the complete-map assertion in `test/mailers/loops_devise_mailer_test.rb`.
- Add `app/mailers/user_mailer.rb` with `account_created`.
- Add `test/mailers/user_mailer_test.rb` covering the exact ID, recipient, sender, Reply-To, two-variable JSON contract, real sign-in route, empty body, non-multipart shape, skipped ERB rendering, and strict missing-mapping failure.

**NOT in scope:**

- No mailer view, subject/body copy, delivery client, job, idempotency seed, route, controller, or vendored Jumpstart changes.
- Do not duplicate tests for `addToAudience: false`; that remains hardcoded and covered in `test/mailers/loops_delivery_test.rb`.

**Build order:**

1. **Test:** Add the complete-map assertion and new mailer tests first; run them and confirm failure because the mapping and `UserMailer` are absent.
2. **Implement:** Add the YAML mapping and bodyless mailer with `X-Loops-Transactional-Id`, exact JSON `X-Loops-Data-Variables`, support metadata, and an `AIDEV-NOTE` explaining why no template renders.
3. **Verify:** `mise exec -- bin/rails test test/mailers/user_mailer_test.rb test/mailers/loops_devise_mailer_test.rb test/mailers/account_mailer_test.rb`

### Task 5 [Master]: Enqueue account-created mail after user creation

**Skills:** loops-api, write-tests, review-changes-mini
**Reference:** Read [`app/models/user/marketing_consent.rb`](../../app/models/user/marketing_consent.rb), [`app/models/user.rb`](../../app/models/user.rb), [`test/integration/loops_contact_lifecycle_test.rb`](../../test/integration/loops_contact_lifecycle_test.rb), and [`test/jobs/loops_mail_delivery_job_test.rb`](../../test/jobs/loops_mail_delivery_job_test.rb).

**In scope:**

- Add `app/models/user/account_created_email.rb`.
- Include `AccountCreatedEmail` in `User`.
- Add `test/models/user/account_created_email_test.rb`.
- Prove each newly created user enqueues exactly one `UserMailer.account_created` delivery after commit, with marketing opt-in both true and false.
- Prove an update does not resend and user creation makes no inline Loops HTTP request even when the eventual endpoint is stubbed to return 500.

**NOT in scope:**

- No condition for invitations, marketing consent, environment, OAuth provider, Madmin, or confirmation status.
- No synchronous delivery, rescue block, new job class, callback on update, or `idempotency_seed`.
- Do not change `User::MarketingConsent`.

**Build order:**

1. **Test:** Write the concern tests first and confirm they fail because no callback is registered.
2. **Implement:** Add the concern with one private `after_create_commit` callback calling `UserMailer.with(user: self).account_created.deliver_later`, then include it in `User`.
3. **Verify:** `mise exec -- bin/rails test test/models/user/account_created_email_test.rb test/integration/loops_contact_lifecycle_test.rb test/jobs/loops_mail_delivery_job_test.rb`
4. **Review:** After Tasks 4–5 finish, run `review-changes-mini` exactly once for Checkpoint 2.

### Task 6 [subagent]: Verify password and invited-user registration

**Skills:** loops-api, write-tests
**Reference:** Read [`test/controllers/users/registrations_controller_test.rb`](../../test/controllers/users/registrations_controller_test.rb), [`test/integration/account_invitations_test.rb`](../../test/integration/account_invitations_test.rb), and [`lib/jumpstart/app/models/account_invitation.rb`](../../lib/jumpstart/app/models/account_invitation.rb).

**In scope:**

- Extend the password-registration integration coverage to prove successful signup enqueues one `UserMailer.account_created` delivery.
- Stub a Loops 500 and prove the registration request succeeds without making an inline HTTP request.
- Build an invitation through `save_and_send_invite`, then register its recipient.
- Assert the combined flow enqueues exactly one `AccountMailer.invite` and one `UserMailer.account_created`, and still accepts/deletes the invitation.

**NOT in scope:**

- No controller, route, model, mailer, invitation timing, marketing-consent, queue-adapter, or vendored-code changes.
- Do not perform the queued jobs or make live Loops requests.
- If Tasks 4–5 do not satisfy these tests, report the failure to the Master instead of changing shared implementation.

**Build order:**

1. **Test:** Add focused assertions to the two existing integration test files, using Action Mailer/Active Job helpers to identify both mailer/action pairs.
2. **Implement:** Test-only setup or queue cleanup may be added within those two files; make no production changes.
3. **Verify:** `mise exec -- bin/rails test test/controllers/users/registrations_controller_test.rb test/integration/account_invitations_test.rb`

### Task 7 [subagent]: Verify OAuth signup and audit callback blast radius

**Skills:** loops-api, write-tests, review-changes-mini
**Reference:** Read [`test/integration/jumpstart/omniauth_callbacks_test.rb`](../../test/integration/jumpstart/omniauth_callbacks_test.rb), [`test/integration/loops_contact_lifecycle_test.rb`](../../test/integration/loops_contact_lifecycle_test.rb), and [`test/models/user_test.rb`](../../test/models/user_test.rb).

**In scope:**

- Extend the existing social-registration test to prove the first OAuth callback enqueues exactly one `UserMailer.account_created`.
- Prove a later login through the same connected account creates no user and enqueues no second account-created email.
- Run the identified callback-sensitive tests and confirm their class-filtered job assertions still describe the intended marketing behavior.
- Record that fixtures do not run creation callbacks.

**NOT in scope:**

- No OAuth controller, connected-account, fixture, callback, or marketing behavior changes.
- Do not weaken assertions merely to tolerate unrelated jobs.
- Pre-flight found no all-job-count assertion in the audit files; if that assumption is wrong, stop and report the exact failure before editing outside the OAuth test.

**Build order:**

1. **Test:** Add the OAuth enqueue/no-resend assertions first and confirm failure before Tasks 4–5 are present.
2. **Implement:** Make test-only changes in `test/integration/jumpstart/omniauth_callbacks_test.rb`; no production implementation is expected.
3. **Verify:** `mise exec -- bin/rails test test/integration/jumpstart/omniauth_callbacks_test.rb test/integration/loops_contact_lifecycle_test.rb test/models/user_test.rb test/models/user/marketing_consent_test.rb`
4. **Review:** After the parallel Tasks 6–7 both return, the Master runs `review-changes-mini` exactly once for Checkpoint 3. The subagent does not run a duplicate review.

**Phase 3 — Final and staging verification**

### Task 8 [Master]: Run final gates and staging inbox verification

**Skills:** loops-cli, write-tests, review-changes-mini
**Reference:** Re-read the acceptance criteria, live-verification recipe, and idempotency warning in [`docs/designs/cov-68-account-created-email.md`](../designs/cov-68-account-created-email.md), plus [`render.yaml`](../../render.yaml) and [`config/environments/staging.rb`](../../config/environments/staging.rb).

**In scope:**

- Run all focused tests, the complete Rails suite, RuboCop, whitespace checks, status, and final diff.
- Push the feature branch and have the user temporarily point Render’s `cove-staging` service at it, deploy, and confirm the exact deployed SHA.
- Using two distinct allowlisted addresses, complete one email/password signup and one Google OAuth signup.
- Confirm both accounts succeed, both emails arrive, each CTA resolves to the real staging sign-in page, and Loops has no contact for either address.
- Record secret-safe evidence in the design, then restore Render’s branch to `main` and verify that setting stuck.

**NOT in scope:**

- No production deployment, PR creation, merge, allowlist disclosure, recipient disclosure, contact deletion, resend, template redesign, or unrelated cleanup.
- Do not reuse an address across the two staging flows.
- Do not leave Render pointed at the feature branch.
- The user performs Render, inbox, Google, and Loops-dashboard interactions one action at a time; Codex does not type secrets or recipient addresses.

**Build order:**

1. **Test:** Run:
   - `mise exec -- bin/rails test test/mailers/user_mailer_test.rb test/models/user/account_created_email_test.rb test/controllers/users/registrations_controller_test.rb test/integration/account_invitations_test.rb test/integration/jumpstart/omniauth_callbacks_test.rb`
   - `mise exec -- bin/rails test`
   - `mise exec -- bin/rubocop`
2. **Implement:** After local gates pass, push and deploy the exact feature SHA to staging through the temporary Render branch setting. Guide the user through each signup, inbox check, CTA check, and Audience contact search separately. Add only non-sensitive outcomes and the deployed SHA to the design.
3. **Verify:** Run:
   - `env -u LOOPS_API_KEY loops transactional get <transactional-id> --team cove-cli --output json`
   - `git diff --check`
   - `git status --short`
   - `git diff origin/main...`
   Confirm the template remains published with exactly two variables; both staging flows passed; Render is restored to `main`; no secrets, addresses, unrelated changes, or files under `lib/jumpstart/` entered the diff.
4. **Review:** Run `review-changes-mini` exactly once for Checkpoint 4 after all local, external, cleanup, and diff verification is complete.

## Task Dependencies

- Task 2 depends on Task 1 for the transactional, draft-message, and revision IDs.
- Task 3 depends on Task 2’s clean Guardian result and user confirmation of the preview; publication must precede app wiring.
- Task 4 depends on Task 3 for the published transactional ID.
- Task 5 depends on Task 4 for `UserMailer` and the configuration mapping.
- Tasks 6–7 depend on Task 5 and can run in parallel because they modify independent test files.
- Task 8 depends on Tasks 6–7 and remains with the Master for full-suite verification, staging deployment, user-owned inbox/dashboard checks, Render cleanup, evidence recording, and final review.
