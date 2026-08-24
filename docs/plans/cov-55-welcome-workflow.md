> Ticket: COV-55
> Branch: feature/cov-55-welcome-sequence

# Plan: First lifecycle workflow — welcome sequence

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Validate live state, create the test contact, and register the event pattern | Master | ✅ |
| 2 | 1 | 1 | Create the inactive workflow and author the welcome email in LMX | Master | ✅ |
| 3 | 1 | 1 | Run Guardian and verify the preview in a real inbox | Master | ✅ |
| 4 | 2 | 2 | Activate once, trigger the workflow, and verify delivery and unsubscribe | Master | ✅ |
| 5 | 2 | 2 | Delete the test contact, deactivate the workflow, and document findings | Master | ✅ |

All tasks remain with Master because they mutate one shared Loops team, depend
on sequential external state, and require user-owned dashboard and inbox
interactions.

## Prerequisites

- Design: `docs/designs/cov-55-welcome-workflow.md`
- Prototype: None — this is an approved minimal text-first email using the
  existing `Cove` theme, so image generation and visual exploration are
  intentionally skipped
- Feature branch exists: `feature/cov-55-welcome-sequence`
- User is available to provide a real verification inbox, inspect received
  email, and perform Loops dashboard actions one at a time
- The verification address remains user-owned in a shell variable such as
  `COV55_TEST_EMAIL`; never print, persist, or commit it
- `LOOPS_API_KEY` is unset because it takes precedence over `--team`; every CLI
  command explicitly selects `--team cove-cli`
- Temporary non-secret LMX, event-property, and redacted response files live
  under `.context/cov-55/` and are not committed
- No Rails view, component, route, model, migration, configuration, credential,
  or application code changes
- The component catalog was checked; no Cove component applies because Loops
  owns the workflow, email renderer, and preference-center UI
- No Rails test can exercise Loops-hosted behavior. CLI reads, Guardian,
  revision-safe updates, real-inbox inspection, Audience counts, and final
  external-state reads are the behavior tests

## Tasks

### Task 1 [Master]: Establish the live-state baseline and event pattern

**Skills:** loops-cli, loops-email-sending-best-practices
**Reference:** Read [`docs/designs/cov-55-welcome-workflow.md`] for “Order of
operations” steps 1–3 and the test-contact contract; use
[`docs/plans/done/cov-53-mailing-lists.md`] for credential and Audience-count
precedent
**Prototype:** None

**In scope:**

- Confirm `LOOPS_API_KEY` is unset without displaying its value.
- Run `loops version` and `loops agent-context`; do not upgrade the CLI unless
  an expected command is unavailable, in which case stop and request approval.
- Run `loops api-key --team cove-cli -o json` and require `teamName: Cove`.
- Record the dashboard Audience baseline, current From address, and workflow
  inventory.
- Require no existing workflow for this ticket and no existing contact with
  `userId: cov55-verification`; stop on unexpected state rather than deleting
  or adopting it.
- Have the user set `COV55_TEST_EMAIL` without exposing it in the transcript.
- Create exactly one subscribed contact with `userId: cov55-verification` and
  membership in `Cove updates` (`cmsdo8ncl02wc0j0j4rxwhy4l`).
- Fire `user_signed_up` once before any workflow exists, including a fresh
  `signed_up_at` ISO-8601 event property matching `LoopsEventEmitter`.
- Omit `--idempotency-key`, then verify `user_signed_up` appears in
  `loops event-patterns list`.

**NOT in scope:**

- Creating a workflow or email, sending a preview, activating anything,
  changing sender settings, using a server credential, creating another
  contact, or clicking unsubscribe.

**Build order:**

1. **Test:** Validate the credential and inspect
   `loops workflows list --team cove-cli -o json`,
   `loops contacts find --user-id cov55-verification`, the dashboard Audience
   count, and the configured `notify@mail.covehomeschool.com` sender.
2. **Implement:** Run `loops contacts create` with the verification email,
   non-numeric user ID, `--subscribed true`, and
   `--list cmsdo8ncl02wc0j0j4rxwhy4l=true`; then run
   `loops events send user_signed_up --user-id cov55-verification --props
   .context/cov-55/event-props.json` without an idempotency key.
3. **Verify:** Confirm the contact has the intended user ID, subscribed state,
   and list membership; confirm the Audience count is baseline plus one;
   confirm the event pattern exists; confirm no email was sent because no
   workflow existed.

### Task 2 [Master]: Create the inactive workflow and author the LMX email

**Skills:** loops-cli, loops-lmx, loops-email-sending-best-practices
**Reference:** Read [`docs/designs/cov-55-welcome-workflow.md`] for the approved
structure, fields, body, and Open Questions; use
[`docs/designs/done/cov-40-auth-templates.md`] for the shared theme, sender,
revision-safe LMX, and temporary-file precedent
**Prototype:** None — preserve the approved single-column hierarchy and
existing `Cove` theme

**In scope:**

- Reconfirm no matching workflow appeared after Task 1.
- Create exactly one inactive workflow named `Welcome to Cove`, associated
  with mailing list `cmsdo8ncl02wc0j0j4rxwhy4l`.
- Guide the user through dashboard-only trigger configuration one action at a
  time, selecting event `user_signed_up`.
- Inspect and record the workflow re-entry rule without changing it beyond what
  is required for this one-trigger verification.
- Use `loops workflows get` to capture the workflow ID, revision, and node IDs.
- Add exactly one `SendEmailAction`, using revision-safe
  `loops workflows nodes create` when the graph exposes safe insertion points;
  otherwise have the user add that one node in the dashboard and record the
  limitation.
- Write `.context/cov-55/welcome.lmx` with one
  `<Style themeId="cmsdnxho301lh0j17qh8ltsre" />`, one `<H1>`, and the four
  approved paragraphs verbatim.
- Preserve the source em dashes, add no personalization, CTA, links, images,
  components, timer, or manual legal footer.
- Update the generated email message using its last-seen `contentRevisionId`,
  not `--force`.
- Set subject `Welcome to Cove`, preview text
  `A quick note on what to expect in your inbox.`, From
  `Cove <notify@mail.covehomeschool.com>`, reply-to
  `support@covehomeschool.com`, and styled format.

**NOT in scope:**

- Activating the workflow, firing another event, changing the shared theme,
  adding a timer or second email, creating a campaign, adding personalization,
  or authoring Loops’ automatic unsubscribe/address footer.

**Build order:**

1. **Test:** Fetch theme `cmsdnxho301lh0j17qh8ltsre`, confirm it remains the
   expected `Cove` theme, and recheck the workflow inventory for duplicates.
2. **Implement:** Create the workflow, configure its event trigger, add the
   single email node, write the temporary LMX, fetch the email-message revision,
   and apply the revision-safe message update.
3. **Verify:** Fetch the workflow and email message again; require the exact
   mailing-list ID, trigger → `SendEmailAction` structure, no timer, exact
   theme/subject/preview/sender/reply-to/body, styled format, no LMX warnings,
   and inactive workflow state. Record which actions were CLI-reproducible
   versus dashboard-only.

### Task 3 [Master]: Validate Guardian and the real-inbox preview

**Skills:** loops-cli, loops-lmx, loops-email-sending-best-practices
**Reference:** Read [`docs/designs/cov-55-welcome-workflow.md`] for preview
requirements and the “Preview does not render the real footer” edge case; use
[`docs/designs/done/cov-40-auth-templates.md`] for Guardian and inbox-inspection
precedent
**Prototype:** None

**In scope:**

- Have the user run Guardian in the Loops dashboard; compilation errors,
  warnings requiring action, or Guardian failures are blockers.
- Run
  `loops email-messages preview <emailMessageId> --email "$COV55_TEST_EMAIL"
  --team cove-cli -o json`.
- Inspect the received styled email, images-blocked state, and generated
  plain-text alternative.
- Confirm subject, preview text, sender, reply-to, copy, hierarchy, spacing, and
  continuity with the COV-40 theme.
- Treat images-blocked behavior as structurally satisfied only after confirming
  the body contains no image dependency.
- Confirm the preview did not add another Audience contact.
- Do not count footer address or unsubscribe behavior as proven by the preview.

**NOT in scope:**

- Activating the workflow, firing the real trigger, clicking unsubscribe,
  editing copy after approval, adding visual decoration, or claiming the real
  footer is verified.

**Build order:**

1. **Test:** Run Guardian and require a clean result before sending any preview.
2. **Implement:** Send one preview to the user-owned inbox and guide the user
   through styled, images-blocked, and plain-text inspection.
3. **Verify:** Re-fetch the email message and workflow, confirm they remain
   unchanged and inactive, and confirm the Audience count remains baseline plus
   one.
4. **Review:** Run `review-changes-mini` once for Checkpoint 1, covering Tasks
   1–3, after all three tasks are complete. If the tasks were executed as a
   parallel batch, the master runs this review only after the whole batch
   returns.

### Task 4 [Master]: Trigger the live workflow and verify unsubscribe behavior

**Skills:** loops-cli, loops-email-sending-best-practices
**Reference:** Read [`docs/designs/cov-55-welcome-workflow.md`] for “Order of
operations” steps 6–7 and live-send edge cases; use
[`docs/designs/done/cov-52-loops-unsubscribe-webhook.md`] for list-level
unsubscribe semantics
**Prototype:** None

**In scope:**

- Reconfirm the exact workflow graph, mailing-list association, message
  settings, verification contact, and clean preview result.
- Have the user activate the workflow in the dashboard one action at a time.
- Confirm activation before firing the event.
- Generate a fresh `signed_up_at` value and fire `user_signed_up` once with
  `userId: cov55-verification`, again omitting `--idempotency-key`.
- Record the event timestamp and inbox-arrival timestamp to calculate elapsed
  delivery time.
- Verify the actual triggered email’s styled, images-blocked, and plain-text
  rendering; shared theme; physical address
  `307 N 990 E, Salem, UT 84653`; and preference-center unsubscribe link.
- Only after every other rendering check passes, have the user click
  unsubscribe.
- Run `loops contacts find --user-id cov55-verification` and confirm the
  `Cove updates` membership records the list-level opt-out.
- If delivery fails, inspect workflow activity and report rather than blindly
  re-firing or creating another contact.

**NOT in scope:**

- Proving app-originated production emission, COV-52 reconciliation into Rails,
  non-consenting or OAuth signup behavior, replaying with an idempotency key,
  adding a second contact without approval, or changing the provisional email.

**Build order:**

1. **Test:** Fetch the workflow and contact immediately before activation;
   require exact structure, inactive state, valid list membership, and no
   unresolved Guardian/preview issue.
2. **Implement:** Activate, fire exactly one event, record timing, inspect the
   delivered message, and click unsubscribe last.
3. **Verify:** Confirm elapsed time, rendering modes, sender/theme/footer
   details, and the Loops-side list opt-out through a fresh contact read.

### Task 5 [Master]: Clean up and record the durable result

**Skills:** loops-cli
**Reference:** Read [`docs/designs/cov-55-welcome-workflow.md`] for Acceptance
Criteria, Findings, cleanup order, and Open Questions; use
[`docs/plans/done/cov-53-mailing-lists.md`] for before/after documentation
precedent
**Prototype:** None

**In scope:**

- Delete only the contact with `userId: cov55-verification`.
- Confirm the contact is absent and the Audience count returns exactly to Task
  1’s baseline.
- Have the user deactivate, but never delete, the `Welcome to Cove` workflow.
- Confirm the workflow still exists and is inactive pending JOR-1.
- Update `docs/designs/cov-55-welcome-workflow.md` with workflow and
  email-message IDs, event-pattern result, CLI-versus-dashboard findings,
  re-entry rule, elapsed time, rendering results, footer result, unsubscribe
  result, contact deletion, before/after counts, and final inactive state.
- Mark acceptance criteria complete only where directly verified.
- Leave production emission, app-side unsubscribe reconciliation, OAuth
  consent, timer behavior, final copy, CTA, and additional sequence emails
  explicitly deferred.

**NOT in scope:**

- Deleting the workflow, changing unrelated Loops objects, altering contacts to
  force an Audience-count match, adding Rails code, exposing the verification
  address, or claiming unobserved production behavior.

**Build order:**

1. **Test:** Capture the final pre-cleanup contact, Audience, workflow, and
   activation state needed for the Findings record.
2. **Implement:** Delete the test contact, verify the Audience baseline,
   deactivate the workflow, and update only the design’s Findings, Open
   Questions, and directly proven acceptance criteria.
3. **Verify:** Run `git diff --check`,
   `git diff -- docs/designs/cov-55-welcome-workflow.md
   docs/plans/cov-55-welcome-workflow.md`, and `git status --short`; confirm no
   email address, API key, secret, application code, unrelated setting, or
   extra Loops object appears in the diff or final inventory.
4. **Review:** Run `review-changes-mini` once for Checkpoint 2, covering Tasks
   4–5, after both tasks are complete. If the tasks were executed as a parallel
   batch, the master runs this review only after the whole batch returns.

## Approved Retry Amendment (2026-08-24)

This amendment supersedes the original Task 4 live-send execution steps only.
The initial verification delivered successfully, but the recipient clicked the
preference center's page-wide **Unsubscribe** control while `Cove updates`
remained enabled. The observed result was an audience-wide opt-out
(`subscribed: false`) rather than the required list-level opt-out. Do not mark
Task 4 complete from that run.

Retry remains strictly sequential and Master-owned because it mutates the same
Loops team and needs a different verification recipient.

1. **Contain and reset:** Deactivate `Welcome to Cove` first, then delete only
   `cov55-verification`. Confirm the contact is absent and the dashboard
   Audience count returns to the original baseline of `0`. Do not attempt to
   re-subscribe or otherwise repair the globally unsubscribed email.
2. **Create one approved fresh verifier:** Require a genuinely different
   verification inbox (not a `+alias`) and create exactly one subscribed
   contact with user ID `cov55-list-optout-verification` on `Cove updates`.
   Confirm the new contact is globally subscribed and list-subscribed before
   proceeding. This new identity is required because the workflow is
   one-time-per-contact and the original address may be email-suppressed.
3. **Re-run the live proof:** Reconfirm the unchanged Draft workflow and clean
   Guardian/preview evidence, activate it, generate a fresh `signed_up_at`,
   and fire one `user_signed_up` event without an idempotency key. Record the
   event and arrival times; inspect all rendering/footer requirements again.
4. **Perform the correct preference-center action:** In the preference center,
   turn **Cove updates** off and save that list preference. Do **not** click the
   page-wide **Unsubscribe** control. Fetch the contact and require
   `subscribed: true` with `mailingLists[cmsdo8ncl02wc0j0j4rxwhy4l]: false`.
   Stop on any other shape rather than changing the contact through the API.
5. **Clean up and document both runs:** Delete only
   `cov55-list-optout-verification`, confirm Audience returns to `0`, and
   deactivate (never delete) the workflow. The design Findings must distinguish
   the initial accidental global opt-out from the retry result; acceptance is
   complete only for directly observed behavior.

**Not in scope:** Reusing the original email, force-setting subscription state,
creating more than the one newly approved verifier, adding a second workflow or
email, changing copy/theme/trigger/re-entry settings, or app-code changes.

## Task Dependencies

- Strictly sequential: Task 1 → Task 2 → Task 3 → Task 4 → Task 5.
- Task 1 must create and verify the contact before any event can safely target
  it.
- Task 2 depends on Task 1’s event-pattern registration and verified empty
  workflow inventory.
- Task 3 depends on Task 2’s inactive compiled draft.
- Task 4 cannot activate or fire until Guardian and all preview checks pass.
- Task 5 depends on Task 4’s one-shot unsubscribe evidence.
- No tasks should run in parallel because they share one workflow, one contact,
  one inbox, one Audience baseline, and revision-sensitive external state.
