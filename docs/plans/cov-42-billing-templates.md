> Ticket: COV-42
> Branch: feature/cov-42-author-publish-lmx-templates

# Plan: Billing transactional email templates

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Revalidate credentials, theme, and live Loops inventory | Master | |
| 2 | 1 | 1 | Author and validate receipt and refund drafts | Master | |
| 3 | 1 | 1 | Preview, approve, publish, and verify receipt and refund | Master | |
| 4 | 2 | 2 | Author and validate renewal and trial drafts | Master | |
| 5 | 2 | 2 | Preview, approve, publish, and verify renewal and trial emails | Master | |
| 6 | 3 | 3 | Author and validate payment-recovery drafts | Master | |
| 7 | 3 | 3 | Preview, approve, publish, and verify payment-recovery emails | Master | |
| 8 | 4 | 4 | Record the durable COV-45 handoff and final verification | Master | |

Every task remains with Master. Execution mutates shared live Loops objects,
coordinates revision IDs, and pauses for user-owned inbox inspection. Parallel
agents could create duplicates, overwrite newer revisions, or publish before
the complete batch is approved.

## Prerequisites

- Design: `docs/designs/cov-42-billing-templates.md`
- Prototype: None — this is an approved copy-preserving port using the existing
  `Cove` theme, so the net-new image-generation workflow is intentionally
  skipped.
- Feature branch exists: `feature/cov-42-author-publish-lmx-templates`
- Loops CLI v0.9.0 is installed and provides `transactional
  create/draft/get/publish`, revision-safe `email-messages update`, Guardian,
  and transactional previews.
- Read-only planning verification on 2026-08-03 confirmed:
  - `LOOPS_API_KEY` is unset.
  - Named credential `cove-cli` resolves to team `Cove`.
  - Theme `cmsdnxho301lh0j17qh8ltsre` exists and matches the approved `Cove`
    styles.
  - The current transactional inventory contains only the previously published
    `reset-password` and `password-changed` emails.
- Repeat that live-state verification during execution because Loops state may
  change after planning.
- User is available to provide a real preview inbox and explicitly approve each
  preview batch.
- Temporary LMX, preview variables, and non-secret response snapshots go under
  `.context/cov-42/`; `.context/` is ignored and nothing there is committed.
- The architecture diagrams and component catalog were reviewed. No Rails
  model, route, controller, view, component, JavaScript, migration, credential,
  or application code changes are required.
- Guardian, successful LMX compilation, revision-safe reads, real-inbox
  previews, and fresh published-state reads are the behavior tests for
  Loops-hosted content.

## Tasks

### Task 1 [Master]: Revalidate credentials, theme, and live inventory

**Skills:** loops-cli
**Reference:** Read `docs/designs/cov-42-billing-templates.md`,
`docs/plans/done/cov-40-auth-templates.md`, and
`docs/designs/done/cov-38-loops-setup.md`.

**In scope:**

- Confirm no environment variable overrides named-key selection.
- Verify `cove-cli` still resolves to team `Cove`.
- Fetch theme `cmsdnxho301lh0j17qh8ltsre` and compare every style value with
  the design.
- Capture baseline transactional, theme, list, campaign, and workflow
  inventories.
- Reconcile any matching COV-42 object rather than creating a duplicate.
- Save only masked/non-secret evidence under `.context/cov-42/`.

**NOT in scope:**

- Creating, updating, previewing, publishing, or deleting Loops objects.
- Printing or persisting the API key.
- Contacts, audiences, mailing lists, campaigns, workflows, themes, or
  components.

**Build order:**

1. **Test:** check whether `LOOPS_API_KEY` is set without printing its value.
   Stop and have the user unset it if present.
2. **Implement:** run:
   - `loops auth status --team cove-cli -o json`
   - `loops api-key --team cove-cli -o json`
   - `loops themes get cmsdnxho301lh0j17qh8ltsre --team cove-cli -o json`
   - `loops transactional list --team cove-cli --per-page 50 -o json`
   - Read-only list commands for themes, lists, campaigns, and workflows.
3. Save the masked auth result, theme snapshot, and combined baseline inventory
   under `.context/cov-42/`.
4. **Verify:**
   - Team name is exactly `Cove`.
   - The theme exists and remains materially identical to the approved
     contract.
   - For each of the seven names, either no matching object exists or exactly
     one safely reconcilable object exists.
   - Stop before mutation if the team/theme is wrong or any matching object is
     ambiguous.

### Task 2 [Master]: Author and validate receipt and refund drafts

**Skills:** loops-cli, loops-lmx
**Reference:** Read the receipt/refund sections in
`docs/designs/cov-42-billing-templates.md`; compare against
`$(mise exec -- bundle show pay)/app/views/pay/user_mailer/{receipt,refund}.{html,text}.erb`,
`config/locales/en.yml`, and `app/mailers/pay/user_mailer.rb`.
**Prototype:** None — follow the exact approved hierarchy and source-derived
copy.

**In scope:**

- Create complete `.context/cov-42/billing-receipt.lmx` and
  `billing-refund.lmx` documents.
- Begin each document with
  `<Style themeId="cmsdnxho301lh0j17qh8ltsre" />`.
- Use one H1 and one restrained `<Section>` with bold inline field labels.
- Use exactly the variables defined in the design.
- Configure `extra_billing_info` as the sole empty-string data fallback.
- Create or safely adopt both transactional objects and update their drafts
  using last-seen revision IDs.
- Configure literal subjects, Cove sender, support reply-to, empty preview
  text, and styled format.

**NOT in scope:**

- `receipt_url`, authenticated billing links, buttons, images, custom
  components, manual legal footers, or additional copy.
- Receipt attachment delivery; COV-45 owns the actual send payload.
- `--force`, publishing, previews, live transactional sends, or audience
  creation.
- Rails/application changes.

**Build order:**

1. **Test:** inspect both LMX files before upload:
   - Complete valid documents under 100 KB.
   - Exactly one leading `<Style />` and one `<H1>`.
   - Receipt variables: `amount`, `charged_to`, `transaction_id`, `charged_at`,
     `extra_billing_info`.
   - Refund variables: `amount_refunded`, `charged_to`, `transaction_id`,
     `charged_at`, `extra_billing_info`.
   - No unsupported tags, top-level text, inline fallback syntax, images,
     manual footer, or unresolved source ERB.
   - Follow the approved design's final period in the refund timing sentence,
     even though the vendored Pay source omits it.
2. **Implement:** for each name, create only when Task 1 found no match:
   - `loops transactional create -n <name> --team cove-cli -o json`
   - If adopting a published object without a draft, run
     `loops transactional draft <transactionalId> --team cove-cli -o json`.
3. Capture each `transactionalId`, draft `emailMessageId`, and
   `contentRevisionId`.
4. Update each message with `--expected-revision-id`, its literal subject,
   `--from-name Cove`, `--from-email notify`,
   `--reply-to support@covehomeschool.com`, `--email-format styled`, its LMX
   file, and:
   - `--data-fallback 'extra_billing_info='`
5. **Verify:**
   - Fresh `email-messages get` results match the exact subject, sender,
     reply-to, format, LMX, variable set, and complete fallback map.
   - `loops email-messages guardian <emailMessageId> --team cove-cli -o json`
     has no errors.
   - Review every warning individually.
   - Treat update failures as compilation blockers.
   - On revision conflict, fetch and reconcile the latest revision; never
     switch silently to `--force`.

### Task 3 [Master]: Preview and publish receipt and refund

**Skills:** loops-cli, loops-lmx
**Reference:** Read the design's “Real-inbox preview matrix,” receipt/refund
acceptance criteria, and “Publish and durable handoff” section.

**In scope:**

- Create four preview-variable JSON files: receipt/refund, each with and without
  `extra_billing_info`.
- Use `$10.00`, a representative card description, prefixed transaction ID,
  and localized display date.
- Send four previews through `email-messages preview`.
- Pause for explicit user approval of the complete batch.
- Revise and re-preview only failed states.
- Publish both drafts after approval and confirm publication with fresh reads.

**NOT in scope:**

- `transactional send`, attachments, `--add-to-audience`, contacts, or live
  customer data.
- Publishing either draft before all four required states are approved.
- Repeated retries after an HTTP 429.
- Treating a successful preview request as proof of correct inbox rendering.

**Build order:**

1. **Test:** rerun Guardian for both drafts immediately before preview and
   require no blocking errors.
2. **Implement:** create four JSON payloads:
   - Receipt with `amount: "$10.00"` and representative
     `extra_billing_info`.
   - Receipt with the optional key omitted.
   - Refund with `amount_refunded: "$10.00"` and representative
     `extra_billing_info`.
   - Refund with the optional key omitted.
   - Both use representative `charged_to`, `transaction_id`, and `charged_at`
     strings.
3. Send each state using:
   `loops email-messages preview <emailMessageId> --team cove-cli --email <real-inbox> --json-vars <preview-file> -o json`.
4. **Verify:** pause until the user confirms for all four:
   - Literal `[Cove] ` subject with no unresolved variables.
   - Correct theme, hierarchy, spacing, desktop layout, and mobile layout.
   - Readable generated plain-text alternative.
   - `$10.00` remains dollars-and-cents.
   - Correct transaction/date values.
   - Optional billing information appears only in the populated states.
   - No unresolved `{data.*}` text or awkward empty section remains.
5. If a check fails, fetch the latest revision, update safely, rerun Guardian,
   and preview only the affected state. On 429, stop until capacity returns.
6. After explicit batch approval:
   - `loops transactional publish <transactionalId> --team cove-cli -o json`
   - `loops transactional get <transactionalId> --team cove-cli -o json`
7. Require published state and exact returned data-variable contracts for both
   objects.
8. **Review:** run `review-changes-mini` exactly once for Checkpoint 1, covering
   Tasks 1–3. Review the external-state evidence as well as the repository
   diff.

### Task 4 [Master]: Author and validate renewal and trial drafts

**Skills:** loops-cli, loops-lmx
**Reference:** Read the corresponding design sections and Pay sources under
`$(mise exec -- bundle show pay)/app/views/pay/user_mailer/{subscription_renewing,subscription_trial_will_end,subscription_trial_ended}.{html,text}.erb`.
**Prototype:** None — preserve the approved text-first hierarchy.

**In scope:**

- Create complete LMX documents for:
  - `billing-subscription-renewing`
  - `billing-trial-will-end`
  - `billing-trial-ended`
- Use the confirmed theme, one H1, one high-contrast CTA button, supporting
  copy, and Cove Team signoff.
- Use `renews_on` only in the renewal body.
- Use `manage_subscription_url` in all three button destinations.
- Create or safely adopt each object, update revision-safely, and run Guardian.

**NOT in scope:**

- A fixed renewal lead-time claim, new marketing copy, root URLs baked into
  LMX, extra variables, images, or custom components.
- Publishing, previews, live sends, or Rails integration.
- `--force` or overwriting concurrent website edits.

**Build order:**

1. **Test:** validate each complete document against the LMX checklist:
   - One leading theme `<Style />` and one H1.
   - Exact approved copy, source punctuation, CTA label, and signoff.
   - Renewal variables are exactly `renews_on` and
     `manage_subscription_url`.
   - Each trial template uses only `manage_subscription_url`.
   - CTA variables appear only in supported button `href` attributes.
2. **Implement:** create or adopt each transactional object; ensure a draft
   exists; capture its draft message and last-seen revision.
3. Update each message with its literal subject, Cove sender, notify username,
   support reply-to, empty preview text, styled format, and correct LMX file.
4. **Verify:**
   - Fresh message reads match settings, LMX, and exact variable sets.
   - Guardian returns no errors; review all warnings.
   - Reconcile revision conflicts through a fresh read without `--force`.

### Task 5 [Master]: Preview and publish renewal and trial emails

**Skills:** loops-cli, loops-lmx
**Reference:** Read the design's renewal/trial preview requirements and
acceptance criteria.

**In scope:**

- Send one complete-variable real-inbox preview per template.
- Use a localized long-date sample for renewal.
- Use harmless, working absolute staging HTTPS management URLs.
- Pause for explicit approval of all three messages.
- Publish and freshly verify all three after approval.

**NOT in scope:**

- Live customer URLs or data, transactional sends, audience creation, or
  publishing a failed preview.
- Re-previewing unaffected messages.
- Retrying repeatedly after a 429.

**Build order:**

1. **Test:** rerun Guardian for all three drafts.
2. **Implement:** create one JSON preview payload per message:
   - Renewal: `renews_on` plus `manage_subscription_url`.
   - Trial ending: `manage_subscription_url`.
   - Trial ended: `manage_subscription_url`.
3. Send each through `email-messages preview` to the user's real inbox.
4. **Verify:** pause until the user confirms:
   - Literal subjects and no unresolved variables.
   - Existing theme, one-H1 hierarchy, spacing, mobile rendering, and generated
     plain text.
   - Renewal date renders as the supplied long-date string.
   - Each CTA is clickable and resolves to the supplied absolute HTTPS URL.
   - Copy and Cove Team signoffs match the design.
5. Safely revise and re-preview only affected messages; stop on 429.
6. After explicit batch approval, publish all three and run fresh
   `transactional get` reads.
7. Require published state and the exact design-specified variable contracts.
8. **Review:** run `review-changes-mini` exactly once for Checkpoint 2, covering
   Tasks 4–5.

### Task 6 [Master]: Author and validate payment-recovery drafts

**Skills:** loops-cli, loops-lmx
**Reference:** Read the payment-action-required/payment-failed design sections
and Pay sources under
`$(mise exec -- bundle show pay)/app/views/pay/user_mailer/{payment_action_required,payment_failed}.{html,text}.erb`.
**Prototype:** None — preserve the approved source-copy treatment.

**In scope:**

- Create complete LMX for `billing-payment-action-required` and
  `billing-payment-failed`.
- Use the confirmed theme, one H1, one high-contrast CTA, supporting copy, and
  source Cove Team signoff.
- Use only `confirm_payment_url` for payment action required.
- Use only `update_billing_url` for payment failed.
- Preserve the en dash in the payment-failed subject.
- Create/adopt, update revision-safely, fetch, and run Guardian.

**NOT in scope:**

- Payment-intent expiry hints, extra recovery copy, baked-in environment URLs,
  images, components, live sending, or application integration.
- Publishing or previewing before validation.
- `--force`.

**Build order:**

1. **Test:** validate both complete LMX files for exact copy, correct hierarchy,
   valid button `href` variables, supported tags, one theme, one H1, and no
   extra variables.
2. **Implement:** create or adopt both objects, ensuring a draft exists and
   capturing each current revision.
3. Update with their exact subjects and fixed sender/reply-to/styled settings.
4. **Verify:**
   - Fresh message reads match exact content and settings.
   - Guardian returns no errors.
   - Review warnings individually.
   - Reconcile revision conflicts through fresh reads.

### Task 7 [Master]: Preview and publish payment-recovery emails

**Skills:** loops-cli, loops-lmx
**Reference:** Read the design's payment-recovery preview requirements and
acceptance criteria.

**In scope:**

- Send one complete-variable preview for each message.
- Use harmless, working absolute staging HTTPS URLs.
- Pause for explicit user approval of both messages.
- Publish only after approval and confirm with fresh reads.

**NOT in scope:**

- Real payment-intent identifiers, live customer billing data, transactional
  sends, contacts, audiences, or repeated 429 retries.
- Publishing a draft with a failed link, unresolved variable, or rendering
  issue.

**Build order:**

1. **Test:** rerun Guardian for both drafts.
2. **Implement:** create two preview JSON files:
   - Action required: `confirm_payment_url`.
   - Payment failed: `update_billing_url`.
3. Send both through `email-messages preview`.
4. **Verify:** pause until the user confirms:
   - Literal subjects, including the payment-failed en dash.
   - Correct theme, hierarchy, desktop/mobile rendering, and plain text.
   - Both CTA labels and destinations are correct, clickable absolute HTTPS
     URLs.
   - No unresolved variables or added expiry language.
5. Safely revise and re-preview only affected messages; stop on 429.
6. After explicit approval, publish both and run fresh `transactional get`
   reads.
7. Require published state and exact one-variable contracts.
8. **Review:** run `review-changes-mini` exactly once for Checkpoint 3, covering
   Tasks 6–7.

### Task 8 [Master]: Record the durable COV-45 handoff

**Skills:** loops-cli
**Reference:** Read the design's Data Model, Receipt attachment contract,
acceptance criteria, Publish and durable handoff, Scope, and More Info sections.

**In scope:**

- Freshly fetch the theme and all seven transactional objects.
- Confirm all seven are published and expose the exact required contracts.
- Replace every `Pending` transactional ID in the design.
- Record the preview recipient and verification date without retaining inbox
  content.
- Record the completed validation, rendering, link, fallback, currency, and
  publish evidence.
- Mark only evidence-supported acceptance criteria complete.
- Compare final Loops inventories with the Task 1 baseline.
- Review the repository diff and run the Rails suite before reporting
  completion.

**NOT in scope:**

- COV-45 application integration, `Pay.mailer` configuration, receipt
  attachment encoding/sending, Rails credentials, routes, or tests for delivery
  code.
- Committing `.context/cov-42/` artifacts or inbox content.
- Claiming a draft or failed object is published.
- Creating or cleaning up unrelated Loops objects.

**Build order:**

1. **Test:** fetch:
   - `loops themes get cmsdnxho301lh0j17qh8ltsre --team cove-cli -o json`
   - `loops transactional get <id> --team cove-cli -o json` for all seven.
2. Require:
   - All seven objects have published message IDs and no unresolved failed
     publication.
   - Returned `dataVariables` exactly match the design.
   - Receipt/refund retain the exact `extra_billing_info` empty-string
     fallback.
3. **Implement:** update only `docs/designs/cov-42-billing-templates.md` with
   published IDs, preview recipient/check date, validation evidence, and
   completed acceptance criteria.
4. **Verify:**
   - Re-list transactional emails, themes, lists, campaigns, and workflows and
     compare with Task 1.
   - Audit the workflow for absence of `transactional send`,
     `--add-to-audience`, contact mutations, and unrelated object creation.
   - Confirm `.context/cov-42/` is ignored with `git check-ignore -v`.
   - Run `mise exec -- bin/rails test`.
   - Run `git diff`, `git diff --check`, and `git status --short`.
   - Confirm the only durable implementation edit is the design handoff and no
     `.context` artifact appears in the diff.
5. **Review:** run `review-changes-mini` exactly once for Checkpoint 4, covering
   Task 8 and the complete acceptance-criteria handoff.

## Task Dependencies

- Task 2 depends on Task 1's verified team, exact theme, and duplicate-safe
  inventory.
- Task 3 depends on both receipt/refund drafts passing compilation and Guardian
  in Task 2.
- Task 4 starts only after the first batch is published and Checkpoint 1 passes.
- Task 5 depends on all three lifecycle drafts passing Task 4 validation.
- Task 6 starts only after the lifecycle batch is published and Checkpoint 2
  passes.
- Task 7 depends on both payment-recovery drafts passing Task 6 validation.
- Task 8 depends on all seven templates being explicitly approved, published,
  and freshly verified.
- Execution is deliberately sequential even where LMX authoring is logically
  independent: every batch shares one live Loops team, revision stream, preview
  allowance, and user approval boundary.
