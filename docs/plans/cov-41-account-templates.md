> Ticket: COV-41
> Branch: feature/cov-41-author-publish-lmx-templates-account-group

# Plan: Account transactional email templates

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Verify the CLI credential, shared theme, and duplicate-safe live state | Master | |
| 2 | 2 | 2 | Author and Guardian-check the `account-invite` draft | Master | |
| 3 | 2 | 2 | Preview, inspect, and publish `account-invite` | Master | |
| 4 | 3 | 3 | Author and Guardian-check the `cancellation-survey` draft | Master | |
| 5 | 3 | 3 | Preview, inspect, and publish `cancellation-survey` | Master | |
| 6 | 4 | 4 | Record the durable COV-44 handoff and final inventory | Master | |

Every task remains with Master. This is sequential external-service work
involving live Loops objects, revision coordination, and user-owned inbox
inspection, so subagent delegation would introduce conflicting state and
duplicate-preview risk.

## Prerequisites

- Design: `docs/designs/cov-41-account-templates.md`
- Prototype: None — this is an approved copy-only migration using the existing
  `Cove` theme, so image generation is intentionally skipped.
- Feature branch exists:
  `feature/cov-41-author-publish-lmx-templates-account-group`
- COV-38's verified Cove sending domain and COV-40's retained `cove-cli`
  credential remain available.
- COV-40's published `Cove` theme exists with ID
  `cmsdnxho301lh0j17qh8ltsre`.
- Loops CLI v0.9.0 is installed at `/Users/jordan/.local/bin/loops`.
- User is available to provide a real preview inbox and inspect received
  rendering, links, and headers.
- Temporary LMX and non-secret response files go under `.context/cov-41/`;
  `.context/` is ignored and must not be committed.
- No Rails view, component, route, model, migration, credential, configuration,
  or application-code change is included.
- No Rails test can exercise Loops-hosted content. LMX contract inspection,
  Guardian, revision-safe reads, real-inbox checks, and published-state reads
  are the behavior tests for this ticket.
- The Rails component catalog was scanned; no app ViewComponent is needed
  because all rendered content lives in Loops.

## Tasks

### Task 1 [Master]: Verify credential, theme, and live-state baseline

**Skills:** loops-cli
**Reference:** Read `docs/designs/cov-41-account-templates.md` sections
"Credential and live-state preflight" and "Preview and publishing safeguards";
use `docs/designs/done/cov-40-auth-templates.md` for the established theme and
secret-handling precedent.

**In scope:**

- Confirm `LOOPS_API_KEY` is unset without printing its value.
- Verify the named `cove-cli` key resolves to team `Cove`.
- Create `.context/cov-41/`.
- Re-fetch the `Cove` theme and compare its ID and style contract with COV-40.
- Snapshot all listable relevant Loops inventories before mutation.
- Inspect and safely reconcile either intended transactional name if it already
  exists.
- Establish the command/evidence record used by the final no-unrelated-object
  audit.

**NOT in scope:**

- Printing, exporting, rotating, or committing any API key.
- Creating or updating transactional emails, themes, components, contacts,
  lists, audiences, campaigns, or workflows.
- Duplicating `account-invite` or `cancellation-survey` when a matching object
  exists.
- Updating an unexpected existing object until its ownership and state have
  been reconciled.

**Build order:**

1. **Test:** check only whether `LOOPS_API_KEY` is set. If it is, stop and have
   the user unset it in the execution shell; never print the value.
2. **Implement:** create `.context/cov-41/` and save non-secret JSON responses
   there.
3. **Verify:**
   - `loops api-key --team cove-cli -o json` reports success and
     `teamName: Cove`.
   - `loops themes get cmsdnxho301lh0j17qh8ltsre --team cove-cli -o json`
     returns the published COV-40 `Cove` theme and its approved style contract.
   - Capture baseline output from:
     - `loops themes list --team cove-cli -o json`
     - `loops transactional list --team cove-cli -o json`
     - `loops lists list --team cove-cli -o json`
     - `loops audience-segments list --team cove-cli -o json`
     - `loops campaigns list --team cove-cli -o json`
     - `loops workflows list --team cove-cli -o json`
     - `loops components list --team cove-cli -o json`
   - If either intended name exists, fetch it with `loops transactional get`,
     obtain or create its draft with `loops transactional draft` when
     appropriate, and inspect its email message before proceeding.
   - Do not overwrite a concurrent revision with `--force`.
4. **Review:** run `review-changes-mini` exactly once for Checkpoint 1, covering
   Task 1's credential, theme, duplicate-safety, and baseline-inventory
   evidence.

### Task 2 [Master]: Author and validate the `account-invite` draft

**Skills:** loops-cli, loops-lmx
**Reference:** Read `lib/jumpstart/app/views/account_mailer/invite.html.erb`,
`lib/jumpstart/app/mailers/account_mailer.rb`, `config/locales/en.yml` under
`account_mailer.invite`, and the design's `account-invite` section.
**Prototype:** None — preserve the exact approved copy order and reuse the
existing theme without visual additions.

**In scope:**

- Create `.context/cov-41/account-invite.lmx` as a complete LMX document.
- Use exactly one leading
  `<Style themeId="cmsdnxho301lh0j17qh8ltsre" />`.
- Add one paragraph containing
  `{data.inviter_name} has invited you to collaborate on ` followed by
  `<Strong>{data.account_name}</Strong>`.
- Add one left-aligned themed button labeled `View invitation` with
  `href="{data.invitation_url}"`.
- Create or safely adopt exactly one `account-invite` transactional object.
- Capture its `transactionalId`, `emailMessageId`, and last-seen
  `contentRevisionId`.
- Configure its subject, Cove sender, styled format, no preview text, and unset
  Reply-To.
- Update only through `--expected-revision-id`.
- Run Guardian and review every warning.

**NOT in scope:**

- A heading, image, decorative card, custom component, manual footer, fallback
  expression, extra copy, or explicit theme-style overrides.
- `contact.*` variables, optional invite variables, or app-side fallback logic.
- `--force`, live transactional sending, audience creation, previewing, or
  publishing.
- Changing the COV-40 theme.

**Build order:**

1. **Test:** inspect the complete LMX before upload and require:
   - Exact source copy and punctuation.
   - One `<Style />`, one `<Paragraph>`, and one clickable `<Button>`.
   - Only `inviter_name`, `account_name`, and `invitation_url`.
   - `{data.invitation_url}` appears only in the button `href`.
   - No top-level text, unsupported tags, inline button formatting, manual
     footer, or extra content.
   - File size below 100 KB.
2. **Implement:**
   - If Task 1 found no matching object, run
     `loops transactional create -n account-invite --team cove-cli -o json`.
   - If adopting a published object, use
     `loops transactional draft <transactionalId> --team cove-cli -o json` and
     then fetch the draft message.
   - Update with:
     `loops email-messages update <emailMessageId> --team cove-cli --expected-revision-id <contentRevisionId> --subject '{data.inviter_name} invited you to {data.account_name}' --from-name Cove --from-email support --email-format styled --lmx-file .context/cov-41/account-invite.lmx -o json`.
   - Omit `--reply-to` and `--preview-text`; verify both remain unset. If an
     adopted object contains values that the CLI cannot safely clear through
     its documented path, stop rather than publishing the wrong contract.
3. **Verify:**
   - `loops email-messages get <emailMessageId> --team cove-cli -o json`
     returns the exact settings and LMX.
   - The message is Styled and references theme
     `cmsdnxho301lh0j17qh8ltsre`.
   - The sender settings resolve to `Cove <support@covehomeschool.com>`.
   - The exact detected data-variable contract is `inviter_name`,
     `account_name`, and `invitation_url`.
   - `loops email-messages guardian <emailMessageId> --team cove-cli -o json`
     has no blocking errors.
   - On a revision conflict, fetch the latest message and reconcile it; never
     switch to `--force`.

### Task 3 [Master]: Preview and publish `account-invite`

**Skills:** loops-cli, loops-lmx
**Reference:** Read the design's `account-invite` acceptance criteria and
"Preview and publishing safeguards" section.

**In scope:**

- Rerun Guardian immediately before previewing.
- Send one preview to the user's real inbox with all three variables.
- Use representative inviter/account values and a harmless absolute staging
  URL with no invitation secret.
- Pause for received-message inspection.
- Revise through a fresh revision and preview again if any required check
  fails.
- Publish only after every inbox check passes.
- Confirm publication through a fresh transactional read.

**NOT in scope:**

- `transactional send`, `loops send`, `--add-to-audience`, contacts, or live
  invitation delivery.
- More than one recipient or incomplete variable sets.
- Repeated retries after a 429 response.
- Publishing after a failed interpolation, sender, rendering, or link-target
  check.

**Build order:**

1. **Test:** run
   `loops email-messages guardian <emailMessageId> --team cove-cli -o json` and
   require no blocking result.
2. **Implement:** send one preview with:
   `loops email-messages preview <emailMessageId> --team cove-cli --email <real-inbox> --var inviter_name=Jordan --var account_name='Cove Homeschool' --var invitation_url=https://staging.covehomeschool.com/account_invitations/cov41-preview -o json`.
3. **Verify:** pause until the user confirms:
   - The subject interpolates both `Jordan` and `Cove Homeschool`.
   - The inviter and bold account name render correctly in the body.
   - The sender is `Cove <support@covehomeschool.com>`.
   - The message has the existing Styled `Cove` presentation.
   - The button is visibly themed and left-aligned.
   - Inspecting/clicking the button shows the complete supplied staging URL,
     not literal `{data.invitation_url}`.
4. If any check fails, fetch the latest message, reconcile through
   `--expected-revision-id`, rerun Guardian, and send a new preview. If Loops
   returns 429, stop until the shared rolling window resets.
5. Only after confirmation, run:
   - `loops transactional publish <transactionalId> --team cove-cli -o json`
   - `loops transactional get <transactionalId> --team cove-cli -o json`
   The fresh read must report published state and exactly the three required
   variables.
6. **Review:** run `review-changes-mini` exactly once for Checkpoint 2, covering
   Tasks 2–3 and all `account-invite` external-state evidence.

### Task 4 [Master]: Author and validate the `cancellation-survey` draft

**Skills:** loops-cli, loops-lmx
**Reference:** Read
`lib/jumpstart/app/views/account_mailer/cancellation_reason.html.erb`,
`lib/jumpstart/app/mailers/account_mailer.rb`, `config/locales/en.yml` under
`account_mailer.cancellation_reason`, and the design's `cancellation-survey`
section.
**Prototype:** None — preserve the three source paragraphs and intentionally
use Loops Plain format.

**In scope:**

- Create `.context/cov-41/cancellation-survey.lmx` as a complete LMX document.
- Include exactly three `<Paragraph>` elements in source order:
  1. `Thanks so much for giving Cove a try.`
  2. `Quick question, what made you cancel?`
  3. `I'd really appreciate your feedback to help us make Cove better.`
- Create or safely adopt exactly one `cancellation-survey` transactional
  object.
- Capture its `transactionalId`, `emailMessageId`, and last-seen
  `contentRevisionId`.
- Configure subject `Quick question`, Cove support sender, explicit support
  Reply-To, Plain format, no preview text, and no theme.
- Update only through `--expected-revision-id`.
- Run Guardian and review every warning.

**NOT in scope:**

- `<Style />`, a theme reference, heading, button, link, form, callout,
  variable, manual footer, or extra copy.
- Styled format, previewing, publishing, live sending, contacts, or audiences.
- `--force` or any Rails mailer change.

**Build order:**

1. **Test:** inspect the complete LMX before upload and require:
   - Exactly three top-level paragraphs in the approved order.
   - Exact source copy and punctuation.
   - No variables, `<Style />`, theme ID, unsupported tag, manual footer, or
     additional content.
   - File size below 100 KB.
2. **Implement:**
   - If Task 1 found no matching object, run
     `loops transactional create -n cancellation-survey --team cove-cli -o json`.
   - If adopting a published object, obtain its draft and fetch the draft
     message first.
   - Update with:
     `loops email-messages update <emailMessageId> --team cove-cli --expected-revision-id <contentRevisionId> --subject 'Quick question' --from-name Cove --from-email support --reply-to support@covehomeschool.com --email-format plain --lmx-file .context/cov-41/cancellation-survey.lmx -o json`.
   - Omit `--preview-text` and verify it remains unset.
3. **Verify:**
   - `loops email-messages get <emailMessageId> --team cove-cli -o json`
     returns the exact settings and three-paragraph LMX.
   - The format is Plain with no theme reference.
   - From resolves to `Cove <support@covehomeschool.com>`.
   - Reply-To is exactly `support@covehomeschool.com`.
   - The detected data-variable contract is empty.
   - `loops email-messages guardian <emailMessageId> --team cove-cli -o json`
     has no blocking errors.
   - Reconcile revision conflicts through a fresh read; never use `--force`.

### Task 5 [Master]: Preview and publish `cancellation-survey`

**Skills:** loops-cli, loops-lmx
**Reference:** Read the design's `cancellation-survey` acceptance criteria and
"Preview and publishing safeguards" section.

**In scope:**

- Rerun Guardian immediately before previewing.
- Send one preview with no data variables to the same real inbox.
- Pause for Plain rendering and message-header inspection.
- Revise through a fresh revision and preview again if any check fails.
- Publish only after every check passes.
- Confirm publication and the empty variable contract through a fresh read.

**NOT in scope:**

- `transactional send`, `loops send`, `--add-to-audience`, contacts, or live
  cancellation delivery.
- Adding test variables, links, buttons, or Styled presentation.
- Retrying repeatedly after a 429.
- Publishing without confirming the received Reply-To header.

**Build order:**

1. **Test:** run
   `loops email-messages guardian <emailMessageId> --team cove-cli -o json` and
   require no blocking result.
2. **Implement:** run
   `loops email-messages preview <emailMessageId> --team cove-cli --email <real-inbox> -o json`
   with no `--var` or `--json-vars`.
3. **Verify:** pause until the user confirms:
   - The message has the intended restrained Plain presentation.
   - All three paragraphs appear in the approved order with exact copy.
   - The sender is `Cove <support@covehomeschool.com>`.
   - The received headers contain
     `Reply-To: support@covehomeschool.com`.
4. If any check fails, fetch the latest revision, update safely, rerun Guardian,
   and preview again. If Loops returns 429, stop until the rolling window
   resets.
5. Only after confirmation, run:
   - `loops transactional publish <transactionalId> --team cove-cli -o json`
   - `loops transactional get <transactionalId> --team cove-cli -o json`
   The fresh read must report published state and an empty data-variable
   contract.
6. **Review:** run `review-changes-mini` exactly once for Checkpoint 3, covering
   Tasks 4–5 and all `cancellation-survey` external-state evidence.

### Task 6 [Master]: Record the durable COV-44 handoff

**Skills:** loops-cli
**Reference:** Read the design's "Handoff record," Data Model table, acceptance
criteria, Scope, and the execution-verification format in
`docs/designs/done/cov-40-auth-templates.md`.

**In scope:**

- Re-fetch the theme and both transactional emails from Loops.
- Replace both pending IDs in the design's Data Model table.
- Record the exact published data-variable contracts.
- Record the preview recipient and verification date without retaining inbox
  content.
- Record Guardian, format, interpolation, link-target, sender, Reply-To,
  publish, and fresh-read evidence.
- Complete acceptance criteria only when each item has supporting evidence.
- Compare final listable inventories with Task 1's baseline.
- Audit the executed command record for the absence of unrelated mutations.
- Review the final repository diff.

**NOT in scope:**

- `config/loops.yml`, Rails credentials, COV-44 implementation, mailer tests, or
  application delivery wiring.
- Other account, billing, authentication, or marketing templates.
- Committing `.context/cov-41/` or inbox content.
- Claiming an object is published when its final read is missing or reports
  draft state.

**Build order:**

1. **Test:** fetch:
   - `loops themes get cmsdnxho301lh0j17qh8ltsre --team cove-cli -o json`
   - `loops transactional get <account-invite-id> --team cove-cli -o json`
   - `loops transactional get <cancellation-survey-id> --team cove-cli -o json`
   Both transactional reads must confirm published state and their exact
   contracts.
2. **Implement:** update only `docs/designs/cov-41-account-templates.md` with
   confirmed IDs, exact contracts, recipient/check date, verification evidence,
   final inventory evidence, and supported acceptance-criteria completion.
3. **Verify:**
   - Repeat the baseline inventory commands from Task 1.
   - Confirm the only intended changes are the two new transactional emails;
     the `Cove` theme remains unchanged and unique.
   - Confirm no mailing list, audience segment, campaign, workflow, or component
     was created.
   - Audit the command record to confirm no contact mutation,
     `transactional send`, `loops send`, or `--add-to-audience` occurred.
   - Run `git diff` and `git status --short`.
   - Confirm `.context/cov-41/` remains ignored and absent from the diff.
4. **Review:** run `review-changes-mini` exactly once for Checkpoint 4, covering
   Task 6 and the full COV-44 handoff against every acceptance criterion.

## Task Dependencies

- Task 2 depends on Task 1 for verified credential selection, the confirmed
  COV-40 theme, and duplicate-safe live state.
- Task 3 depends on Task 2's revision-safe, Guardian-checked `account-invite`
  draft.
- Task 4 depends on Task 3 so only one transactional draft/preview/publish
  handoff is active at a time.
- Task 5 depends on Task 4's revision-safe, Guardian-checked
  `cancellation-survey` draft.
- Task 6 depends on Tasks 3 and 5 because only fresh, confirmed published IDs
  belong in the COV-44 handoff.
- The two template tracks are technically independent after Task 1, but
  execution remains sequential to prevent shared-team revision mistakes,
  duplicate previews, and crossed user confirmations.
- No task is delegated because all live mutations share one Loops team and both
  publishing checkpoints require user-owned inbox verification.
