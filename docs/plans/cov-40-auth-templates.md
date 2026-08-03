> Ticket: COV-40
> Branch: feature/cov-40-author-and-publish-lmx-templates

# Plan: Auth transactional email templates

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Create and verify the dedicated CLI credential; snapshot live state | Master | ✅ |
| 2 | 1 | 1 | Create and verify the shared `Cove` theme | Master | ✅ |
| 3 | 2 | 2 | Author and validate the `reset-password` draft | Master | ✅ |
| 4 | 2 | 2 | Preview, inspect, and publish `reset-password` | Master | ✅ |
| 5 | 3 | 3 | Author and validate the `password-changed` draft | Master | |
| 6 | 3 | 3 | Preview, inspect, and publish `password-changed` | Master | |
| 7 | 4 | 4 | Record the durable COV-43 handoff and final verification | Master | |

Every task remains with Master. This is sequential, external-service work
involving a user-owned login, secret entry, inbox inspection, live Loops
objects, and revision coordination; it is not suitable for subagent delegation.

## Prerequisites

- Design: `docs/designs/cov-40-auth-templates.md`
- Prototype: None — this is an approved minimal source-copy port, so the
  `loops-lmx` visual-reference/image-generation flow is intentionally skipped.
- Feature branch exists: `feature/cov-40-author-and-publish-lmx-templates`
- Loops CLI v0.9.0 is installed at `/Users/jordan/.local/bin/loops`.
- User is available to create the API key, enter it interactively, provide a
  real preview inbox, and inspect received messages.
- Temporary files go under `.context/cov-40/`; `.context/` is ignored by the
  repository and nothing there is committed.
- No Rails view, component, route, model, migration, credential, or application
  code changes.
- No Rails test exercises Loops-hosted content. Guardian, revision-safe reads,
  real-inbox checks, and published-state reads are the behavior tests for this
  ticket.

## Tasks

### Task 1 [Master]: Establish credential and live-state preflight

**Skills:** loops-cli
**Reference:** Read `docs/designs/cov-40-auth-templates.md` sections “Credential
and live-state preflight” and “Preview and publishing safeguards”; use
`docs/designs/done/cov-38-loops-setup.md` for secret-handling precedent.

**In scope:**

- User creates the named `cove-cli` key in Loops Settings → API.
- User runs `loops auth login cove-cli` and types the value only into the
  interactive prompt.
- Verify the key resolves to team `Cove`.
- Re-list themes and transactional emails immediately before creating anything.
- Save non-secret JSON snapshots under `.context/cov-40/`.
- Inspect matching objects instead of creating duplicates.

**NOT in scope:**

- Printing, exporting, committing, or pasting the API-key value.
- Reusing the production or staging server key.
- Creating themes, transactional emails, contacts, lists, audiences, campaigns,
  workflows, or components yet.

**Build order:**

1. **Test:** confirm `LOOPS_API_KEY` is not overriding named-key selection
   without printing its value. If it is set, stop and have the user unset it in
   the execution shell.
2. **Implement:** user creates and stores `cove-cli`; create `.context/cov-40/`.
3. **Verify:**
   - `loops api-key --team cove-cli -o json` must report success and
     `teamName: Cove`.
   - `loops auth list` must contain `cove-cli`.
   - Run `loops themes list --team cove-cli -o json` and
     `loops transactional list --team cove-cli -o json`.
   - If `Cove`, `reset-password`, or `password-changed` already exists, fetch it
     and reconcile its state before proceeding; do not create a duplicate.

### Task 2 [Master]: Create the shared `Cove` theme

**Skills:** loops-cli, loops-lmx
**Reference:** Read `app/assets/tailwind/theme/_tokens.css`, the approved theme
table in the design, and `.context/cov-40/` live-state snapshots.

**In scope:**

- Add `.context/cov-40/cove-theme.json` with this exact theme contract:
  - Canvas `#f5f5f5`; white body; near-black text.
  - Outer padding `16px` horizontal and `24px` vertical.
  - Body padding `24px` horizontal and `32px` vertical.
  - Arial/Helvetica/system-safe sans serif.
  - `16px` body text at `160%` line height.
  - `26px` H1; restrained H2/H3 scales.
  - `#262626` button with `#fafafa` text, `10px` radius, `20×12px` inner
    padding.
  - `#e5e5e5` one-pixel body border and dividers; `10px` body radius.
- Create exactly one `Cove` theme and capture its ID.
- If an exact matching theme already exists, adopt and verify it instead.

**NOT in scope:**

- Logos, images, Loops components, decorative cards, marketing-specific styles,
  or app CSS changes.
- Updating an existing non-matching theme without first reconciling why it
  exists.

**Build order:**

1. **Test:** validate `.context/cov-40/cove-theme.json` with `jq empty` and
   confirm it contains only supported theme fields.
2. **Implement:** run
   `loops themes create -n Cove --styles-file .context/cov-40/cove-theme.json --team cove-cli -o json`,
   unless Task 1 found an existing exact match.
3. **Verify:**
   - Save the non-secret response and capture `.id` as the durable `themeId`.
   - Run `loops themes get <themeId> --team cove-cli -o json`.
   - Compare every returned style value against the JSON contract.
   - Re-list themes and confirm there is exactly one intended `Cove` theme.
4. **Review:** run `review-changes-mini` once for Checkpoint 1, covering Tasks
   1–2. Review live-state evidence against the acceptance criteria because these
   tasks have no committed repo diff.

### Task 3 [Master]: Author and validate the `reset-password` draft

**Skills:** loops-cli, loops-lmx
**Reference:** Read
`lib/jumpstart/app/views/devise/mailer/reset_password_instructions.html.erb`,
`config/locales/devise.en.yml`, and the design’s `reset-password` section.
**Prototype:** None — preserve the approved text-first order and exact source
copy.

**In scope:**

- Create `.context/cov-40/reset-password.lmx` as a complete LMX document.
- Use one leading `<Style themeId="<confirmed themeId>" />`.
- Use one H1, four paragraphs, and one left-aligned CTA in the exact approved
  order.
- Use `{data.recipient_email}` in the greeting and
  `{data.reset_password_url}` only in the button `href`.
- Create or safely adopt the `reset-password` transactional object.
- Update its email message with the last-seen `contentRevisionId`.
- Configure subject, sender, reply-to, and styled format.
- Run Guardian and review every warning.

**NOT in scope:**

- Copy edits, preview text, expiration language, images, a manual legal footer,
  fallback syntax, `contact.*` variables, `--force`, publishing, or sending.
- `transactional send`, `--add-to-audience`, or contact creation.

**Build order:**

1. **Test:** before upload, inspect the complete LMX against the `loops-lmx`
   checklist:
   - Exact source copy and punctuation.
   - One `<Style />`, one `<H1>`, and a clickable
     `<Button href="{data.reset_password_url}">`.
   - Only `recipient_email` and `reset_password_url` variables.
   - No top-level text, unsupported tags, image dependencies, or manual footer.
   - File size below 100 KB.
2. **Implement:**
   - Run
     `loops transactional create -n reset-password --team cove-cli -o json` if
     no matching object exists.
   - Capture `transactionalId`, `emailMessageId`, and `contentRevisionId`.
   - Run
     `loops email-messages update <emailMessageId> --team cove-cli --expected-revision-id <contentRevisionId> --subject "Reset password instructions" --from-name "Cove" --from-email notify --reply-to "support@covehomeschool.com" --email-format styled --lmx-file .context/cov-40/reset-password.lmx -o json`.
   - If adopting an existing published object, create or obtain its draft first
     and use that draft’s last-seen revision.
3. **Verify:**
   - `loops email-messages get <emailMessageId> --team cove-cli -o json` must
     return the exact settings and LMX.
   - `loops email-messages guardian <emailMessageId> --team cove-cli -o json`
     must have no blocking errors.
   - Treat compilation errors as blockers and review warnings individually.
   - On a revision conflict, fetch the latest message and reconcile it; never
     switch silently to `--force`.

### Task 4 [Master]: Preview and publish `reset-password`

**Skills:** loops-cli, loops-lmx
**Reference:** Read the design’s “Preview and publishing safeguards” and
`reset-password` acceptance criteria.

**In scope:**

- Send one preview to the user’s real inbox through `email-messages preview`.
- Provide the complete variable set in that one preview.
- Use the recipient’s real address for `recipient_email`.
- Use the harmless absolute staging reset URL specified by the design.
- Pause for user confirmation of visual, link, blocked-image, and plain-text
  checks.
- Publish only after every check passes.
- Confirm published state through a fresh read.

**NOT in scope:**

- Live transactional sending, audience creation, more preview recipients,
  publishing after a failed check, or retrying a 429 repeatedly.
- Recording the object as published before the final `get` confirms it.

**Build order:**

1. **Test:** rerun Guardian immediately before preview and require no blocking
   result.
2. **Implement:** run
   `loops email-messages preview <emailMessageId> --team cove-cli --email <real-inbox> --var recipient_email=<real-inbox> --var reset_password_url=https://staging.covehomeschool.com/users/password/edit?reset_password_token=cov40-preview -o json`.
3. **Verify:** pause until the user confirms:
   - Overall rendering and hierarchy are acceptable.
   - The button is clickable and resolves to the complete absolute staging URL,
     not literal variable text.
   - The message remains complete with images blocked.
   - The generated plain-text alternative is readable and includes the reset
     URL.
4. If any check fails, fetch the latest revision, update the LMX
   revision-safely, rerun Guardian, and send a new preview. If Loops returns 429,
   stop until the rolling window resets.
5. Only after confirmation, run
   `loops transactional publish <transactionalId> --team cove-cli -o json`, then
   `loops transactional get <transactionalId> --team cove-cli -o json` and
   require published state.
6. **Review:** run `review-changes-mini` once for Checkpoint 2, covering Tasks
   3–4 and the reset template’s external-state evidence.

### Task 5 [Master]: Author and validate the `password-changed` draft

**Skills:** loops-cli, loops-lmx
**Reference:** Read
`lib/jumpstart/app/views/devise/mailer/password_change.html.erb`,
`config/locales/devise.en.yml`, and the design’s `password-changed` section.
**Prototype:** None — preserve the approved text-first order and exact source
copy.

**In scope:**

- Create `.context/cov-40/password-changed.lmx` as a complete LMX document.
- Use the confirmed theme, one H1, greeting, and source notification paragraph.
- Use only `{data.recipient_email}`.
- Create or safely adopt the `password-changed` transactional object.
- Perform a revision-safe email-message update.
- Configure subject `Password Changed`, Cove sender, reply-to, and styled format.
- Run Guardian and review every warning.

**NOT in scope:**

- A “this wasn’t me” link, support CTA, preview text, images, manual footer,
  extra variables, `--force`, publishing, or sending.
- Any security-copy changes beyond the existing Devise source.

**Build order:**

1. **Test:** inspect the complete LMX for exact source copy, one `<Style />`,
   one `<H1>`, only `recipient_email`, valid nesting, and no unsupported
   additions.
2. **Implement:** create or adopt `password-changed`, capture its IDs, then
   update its email message with `--expected-revision-id`, subject
   `Password Changed`, `--from-name Cove`, `--from-email notify`, the support
   reply-to, styled format, and `.context/cov-40/password-changed.lmx`.
3. **Verify:**
   - Fetch the email message and compare settings and LMX exactly.
   - Run Guardian and require no blocking errors.
   - Reconcile revision conflicts from a fresh `get`; do not use `--force`.

### Task 6 [Master]: Preview and publish `password-changed`

**Skills:** loops-cli, loops-lmx
**Reference:** Read the design’s `password-changed` and preview-safeguard
sections.

**In scope:**

- Send one real-inbox preview with `recipient_email`.
- Pause for visual, blocked-image, and plain-text verification.
- Publish only after all checks pass.
- Confirm published state through `transactional get`.

**NOT in scope:**

- Live sending, contacts, audiences, unrelated Loops objects, or repeated
  preview retries after a 429.
- Treating the absence of an image as permission to skip the blocked-image
  check, because the generated Loops footer must also remain acceptable.

**Build order:**

1. **Test:** rerun Guardian immediately before preview.
2. **Implement:** run
   `loops email-messages preview <emailMessageId> --team cove-cli --email <real-inbox> --var recipient_email=<real-inbox> -o json`.
3. **Verify:** pause until the user confirms the styled message, images-blocked
   result, and plain-text alternative are acceptable.
4. If a check fails, revise using a fresh revision, rerun Guardian, and preview
   again.
5. Publish with
   `loops transactional publish <transactionalId> --team cove-cli -o json`;
   fetch it with
   `loops transactional get <transactionalId> --team cove-cli -o json` and
   require published state.
6. **Review:** run `review-changes-mini` once for Checkpoint 3, covering Tasks
   5–6 and the password-changed template’s external-state evidence.

### Task 7 [Master]: Record the durable COV-43 handoff

**Skills:** loops-cli
**Reference:** Read the design’s “Handoff record,” Data Model table, acceptance
criteria, and Scope.

**In scope:**

- Re-fetch the theme and both transactional emails from Loops.
- Replace every pending ID in the design’s Data Model table.
- Record both exact `dataVariables` contracts.
- Record the preview recipient and verification date without inbox content.
- Record that Guardian, styled rendering, images-blocked, link, plain-text,
  publish, and fresh-state checks passed.
- Mark acceptance criteria complete only when supported by evidence.
- Confirm no unrelated object was created by this workflow.
- Review the final repository diff.

**NOT in scope:**

- Rails credentials/constants, COV-43 implementation, other transactional
  templates, marketing objects, contacts, audiences, lists, campaigns,
  workflows, or committing `.context/`.
- Claiming a failed or draft email is published.

**Build order:**

1. **Test:** fetch:
   - `loops themes get <themeId> --team cove-cli -o json`
   - `loops transactional get <reset-password-id> --team cove-cli -o json`
   - `loops transactional get <password-changed-id> --team cove-cli -o json`
   Both transactional reads must confirm published state.
2. **Implement:** update only `docs/designs/cov-40-auth-templates.md` with
   confirmed IDs, exact contracts, recipient/check date, verification evidence,
   and completed criteria.
3. **Verify:**
   - Re-list themes and transactional emails; confirm the intended
     one-theme/two-email result without duplicates.
   - Audit the executed command record for the absence of `transactional send`,
     `--add-to-audience`, contacts, lists, audiences, campaigns, and workflows.
   - Run `git diff` and `git status --short`.
   - Confirm `.context/cov-40/` remains ignored and absent from the diff.
4. **Review:** run `review-changes-mini` once for Checkpoint 4, covering Task 7
   and the full acceptance-criteria handoff.

## Task Dependencies

- Task 2 depends on Task 1 for the verified `cove-cli` credential and
  duplicate-safe live-state snapshot.
- Tasks 3 and 5 depend on Task 2 because both LMX documents require the
  confirmed `themeId`.
- Task 4 depends on Task 3’s valid, Guardian-checked reset draft.
- Task 6 depends on Task 5’s valid, Guardian-checked password-changed draft.
- Task 7 depends on Tasks 4 and 6 because only confirmed published IDs belong in
  the durable handoff.
- The two template tracks are technically independent after Task 2, but
  execution remains sequential to keep one active revision/preview handoff at a
  time and minimize accidental duplicate previews.
- No task is delegated because all live mutations share one Loops team and
  require user-owned credential or inbox checkpoints.
