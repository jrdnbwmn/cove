> Ticket: COV-53
> Branch: feature/cov-53-mailing-lists-and-audiences

# Plan: Mailing lists and audience configuration in Loops

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Validate the dedicated credential and capture the Audience/list baseline | Master | ✅ |
| 2 | 1 | 1 | Configure the public list and verify the Preference Center and footer | Master | ✅ |
| 3 | 1 | 1 | Verify saved state through the CLI and document the findings | Master | ✅ |

All tasks remain with Master because they mutate one shared external Loops team,
require a user-authenticated dashboard session, and must run sequentially to
preserve the before/after Audience count.

## Prerequisites

- Design: `docs/designs/cov-53-mailing-lists.md`
- Prototype: None — Loops owns the dashboard and Preference Center UI
- Feature branch exists: `feature/cov-53-mailing-lists-and-audiences`
- COV-40's credential checkpoint has created the local keyring entry `cove-cli`
- User available for the Loops dashboard login
- `LOOPS_API_KEY` is unset before verification; it has higher precedence than
  `--team` and could otherwise bypass the required `cove-cli` credential
- No Cove ViewComponents are involved; the component catalog was checked, but
  this ticket changes only external Loops configuration and its design record
- This ticket has no Rails behavior to test. Its acceptance tests are the live,
  contact-free dashboard checks and read-only CLI verification below.

## Tasks

### Task 1 [Master]: Validate the credential and capture the baseline

**Skills:** loops-cli
**Reference:** Read [`docs/designs/cov-53-mailing-lists.md`] for the credential
precondition, Screens/Flows steps 1–3, and duplicate-list edge case
**Prototype:** None

**In scope:**

- Without printing its value, confirm `LOOPS_API_KEY` is unset.
- As the first Loops command, run
  `loops api-key --team cove-cli -o json` and require `teamName: Cove`.
- Stop immediately if the credential is missing, invalid, or resolves to another
  team; do not substitute `cove-production` or another server credential.
- Record the current Loops Audience count in the dashboard.
- Inspect Settings → Lists for an existing equivalent `Cove updates` list and
  choose update-versus-create without creating a duplicate.

**NOT in scope:**

- Creating or rotating `cove-cli`, exposing any API-key value, changing the
  active default credential, modifying a list, creating contacts, or sending
  email.

**Build order:**

1. **Test:** Confirm `LOOPS_API_KEY` is unset, then run
   `loops api-key --team cove-cli -o json`.
2. **Implement:** Read and retain the current Audience count; inspect the list
   inventory and identify any equivalent list.
3. **Verify:** Confirm the CLI response identifies `Cove`, the baseline Audience
   count is captured, and exactly one create-or-update target is selected before
   proceeding.

### Task 2 [Master]: Configure and visually verify the public list

**Skills:** loops-cli
**Reference:** Read [`docs/designs/cov-53-mailing-lists.md`] for the approved
field values, Screens/Flows steps 4–8, and external-state edge cases
**Prototype:** None — preserve Loops' interface

**In scope:**

- Create the list only if no equivalent exists; otherwise update the existing
  list.
- Set name to `Cove updates`, description to
  `Receive occasional product news and homeschooling resources by email.`, and
  visibility explicitly to Public.
- Leave the company icon unset.
- Use only Loops' contact-free Preference Center preview to verify the rendered
  name, description, and subscription control.
- Verify the sending footer shows `Cove` and
  `307 N 990 E, Salem, UT 84653`; correct only those values if necessary.
- Stop and report the acceptance-criteria conflict if Loops offers no
  contact-free preview.

**NOT in scope:**

- Contacts, test subscribers, emails, segments, filters, extra lists, sender or
  domain changes, company-icon branding, Rails configuration, or application
  code.

**Build order:**

1. **Test:** Inspect the target list's current fields, confirm a contact-free
   Preference Center preview exists, and inspect the current footer values.
2. **Implement:** Create or minimally correct the single list and, only if
   needed, the specified company name/address.
3. **Verify:** Confirm the preview renders the exact name and description with a
   subscription control, the list is visibly Public, and the footer contains
   the approved Cove identity and address without sending email.

### Task 3 [Master]: Verify and document the final state

**Skills:** loops-cli
**Reference:** Read [`docs/designs/cov-53-mailing-lists.md`] for Acceptance
Criteria, Findings, Open Question 1, and Screens/Flows steps 9–10
**Prototype:** None

**In scope:**

- Run `loops lists list --team cove-cli -o json`.
- Confirm the saved object has the exact name and description,
  `isPublic: true`, and one stable generated list ID.
- Recheck the dashboard Audience count and require it to equal Task 1's baseline.
- Update `docs/designs/cov-53-mailing-lists.md` with the before/after counts,
  list ID, CLI result, Preference Center result, and footer result.
- Resolve Open Question 1 with the observed contact-free preview behavior and
  mark acceptance criteria complete only where directly verified.
- Preserve the shared 4,000-send-budget warning and the unresolved
  subscriber-rejoin/webhook question.

**NOT in scope:**

- Adding the list ID to `config/loops.yml` (COV-51), changing consent or webhook
  behavior, altering contacts to repair an Audience-count mismatch, or claiming
  completion when any live verification remains unresolved.

**Build order:**

1. **Test:** Run `loops lists list --team cove-cli -o json`, compare every
   specified field, and compare the final Audience count with the baseline.
2. **Implement:** Replace the pending Findings values and update only the
   directly resolved acceptance criteria/open question in
   `docs/designs/cov-53-mailing-lists.md`.
3. **Verify:** Run `git diff --check` and
   `git diff -- docs/designs/cov-53-mailing-lists.md`; confirm the final ID is
   consistent throughout and no secret, contact, app configuration, or
   unrelated setting appears in the diff.
4. **Review:** Run `review-changes-mini` once for Checkpoint 1 (Tasks 1–3) after
   all three tasks are complete. If the tasks were executed as a parallel batch,
   the master runs this review only after the whole batch returns.

## Task Dependencies

- Strictly sequential: Task 1 → Task 2 → Task 3.
- Task 2 cannot mutate the shared Loops team until Task 1 proves `cove-cli`
  resolves to Cove and captures the baseline.
- Task 3 depends on Task 2's final saved state and Preference Center result.
- No tasks should run in parallel: concurrent dashboard work could create a
  duplicate list or invalidate the Audience before/after comparison.
