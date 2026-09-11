> Ticket: COV-67
> Branch: chore/cov-67-pre-launch-audit-loops-email

# Plan: Pre-launch audit of the Loops email system

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Scaffold the findings document and secret-safe evidence workspace | Master | ✅ |
| 2 | 2 | 2 | Audit all twelve Loops transactional templates, checks 3.1–3.6 | subagent | ✅ |
| 3 | 2 | 2 | Audit delivery-path integrity, checks 4.1–4.8 | subagent | ✅ |
| 4 | 2 | 2 | Audit repository hygiene and design drift, checks 5.1–5.4 | subagent | ✅ |
| 5 | 3 | 3 | Verify production mail configuration through a local production boot, checks 1.3–1.4 | Master | ✅ |
| 6 | 3 | 3 | Audit production credentials and contact-sync configuration, checks 1.1–1.2 and 1.6 | Master | ✅ |
| 7 | 3 | 3 | Verify the Render allowlist, mailing-list ID, and recorded DNS evidence, checks 1.5, 1.7, and 2.2 | Master | ✅ |
| 8 | 4 | 4 | Resolve sender identity, DMARC, and inbox placement, checks 2.1, 2.3, and 2.4 | Master | ✅ |
| 9 | 5 | 5 | Make the remaining judgment calls and draft follow-up tickets | Master | ✅ |
| 10 | 6 | 6 | Assemble the findings document, write the verdict, and run final verification | Master | ✅ |

## Prerequisites

- Design: `docs/designs/cov-67-loops-system-audit-design.md`
- Prototype: None
- Feature branch exists: `chore/cov-67-pre-launch-audit-loops-email`
- Ticket source: `.context/tickets/cov-67-rewrite.md`
- Launch-day handoff: `.context/tickets/cov-launch-day-verification.md` for COV-70
- `config/credentials/production.key` remains local, mode `0600`, and gitignored.
  Never print or commit its value.
- The existing Loops CLI remains at v0.10.1 for this audit. Do not take the
  offered v0.11.0 upgrade.
- Every Loops command unsets `LOOPS_API_KEY` and explicitly passes
  `--team cove-cli`. Do not change the active stored key.
- Private verification addresses live only in `.context/cov-67/private.env`,
  mode `0600`, under variables such as `COV67_TEST_EMAIL`,
  `COV67_GMAIL_EMAIL`, `COV67_OUTLOOK_EMAIL`, and `COV67_APPLE_EMAIL`. Never
  print, commit, or paste them into findings.
- Browser verification is AI-owned whenever practical. Use the available
  browser for Render, Loops dashboard-only or visual state, staging flows, and
  signed-in webmail. Prefer CLI/API for structured bulk records.
- If the selected browser lacks authentication, try an already-authenticated
  available browser. If none is authenticated, ask the author to sign in and
  continue once they confirm it is ready. The author enters passwords, 2FA,
  API keys, and private recipient addresses; the agent performs navigation,
  checks, and non-secret capture.
- Never inspect cookies, browser storage, password stores, or session internals.
  Do not save screenshots containing secrets or private recipient addresses.
- Full raw message source is never committed. Keep any temporary copy under
  `.context/cov-67/`; the committed appendix includes only the relevant
  `From`, `Return-Path`, and `Authentication-Results` headers, with unrelated
  personal data omitted.
- Because Conductor subagents share one filesystem, the three parallel lanes
  write separate files under `.context/cov-67/`. Only Master edits the committed
  findings document, preventing concurrent-write loss.
- All Rails and lint commands begin with:
  ```bash
  export PATH="/Users/jordan/.local/share/mise/shims:$PATH"
  ruby -v
  ```
  `ruby -v` must report 4.0.5 before results are trusted.
- No application behavior is changed. A subagent reports every issue without
  fixing it. Master may apply only a genuinely trivial typo or stale-comment
  correction, and must log its exact diff.
- Follow-up tickets are drafted in the findings document only. Do not create
  them in Linear or change ticket status.
- The six phases are independently safe to pause or deploy because they add
  audit documentation only. The audit is not complete until Phase 6.

## Tasks

### Task 1 [Master]: Scaffold the audit and evidence workspace

**Skills:** review-changes-mini
**Reference:** Read `docs/designs/cov-67-loops-system-audit-design.md`, especially
“Evidence standard” and “Findings document structure”; read
`.context/tickets/cov-67-rewrite.md` for the canonical checkbox text
**Prototype:** None

**In scope:**

- Create `docs/designs/cov-67-loops-system-audit.md` with `## Verdict` first,
  followed by Method, Corrections, findings sections 1–5, Decisions recorded,
  Follow-up tickets, Inline fixes applied, and Appendices.
- Create exactly one findings row for every ID: 1.1–1.7, 2.1–2.4, 3.1–3.6,
  4.1–4.8, and 5.1–5.4.
- Add the four allowed verdicts and evidence classes from the design.
- Create `.context/cov-67/README.md` describing lane outputs and redaction.
- Reserve scratch outputs for lanes A1, A2, A3, B, C, and D.

**NOT in scope:**

- Filling findings before evidence is gathered.
- Calling Loops, Render, DNS, browser, or inbox services.
- Editing application code or prior design documents.

**Build order:**

1. **Test:** derive the canonical 29-ID list from the ticket and confirm the
   planned skeleton contains every ID exactly once.
2. **Implement:** create the committed scaffold and gitignored lane protocol
   using `apply_patch`.
3. **Verify:** run a Ruby readback asserting 29 unique findings rows, followed
   by `git diff --check`.

After Task 1, run `review-changes-mini` exactly once for Checkpoint 1.

### Task 2 [subagent]: Audit the twelve transactional templates

**Skills:** loops-cli, loops-api, loops-email-sending-best-practices,
browser:control-in-app-browser
**Reference:** Read `config/loops.yml`; the four mailers under `app/mailers/`;
and the COV-40, COV-41, COV-42, COV-55, and COV-68 completed designs
**Prototype:** None

**In scope:**

- Write only `.context/cov-67/lane-a1-templates.md`.
- Run a fresh structured inventory:
  ```bash
  env -u LOOPS_API_KEY loops transactional list \
    --team cove-cli --per-page 50 --output json
  ```
- For every configured ID, read its freshly returned published message ID:
  ```bash
  env -u LOOPS_API_KEY loops email-messages get <published-message-id> \
    --team cove-cli --output json
  ```
- Complete checks 3.1–3.6: intended template and publication state; exact
  case-sensitive app/template variables; subject and preview text; missing-value
  behavior; transactional audience/footer behavior; and equal scrutiny for
  `account_created`.
- Inspect dynamic fields as well as LMX when extracting `{data.*}` references.
  Treat `extra_billing_info` as conditional for receipt/refund.
- Send one bounded preview for each variable-bearing template with one selected
  value omitted and representative values supplied for the others. Record
  cancellation survey as not applicable because its variable contract is empty.
- Stop rather than retry if Loops returns 429.
- After previews are sent, hand Master a structured message checklist. Master
  uses the signed-in browser to inspect the received previews and supplies the
  recipient-visible missing-value results before Checkpoint 2 closes. If sign-in
  is needed, pause for the author rather than substituting static inference.
- Use the browser for Loops dashboard visual state only where the API response is
  ambiguous; do not replace the structured CLI inventory.
- Reuse the dated observed COV-55 marketing-footer evidence. Do not claim a
  preview proves Loops' generated footer.
- Record that COV-68 already verified `account_created` twice on staging on
  2026-09-09; production verification remains in COV-70.
- Produce the twelve-row template table, mismatches-only variable table, and
  sanitized Appendix A evidence.

**NOT in scope:**

- Editing, publishing, renaming, or creating Loops templates.
- Updating LMX or sender settings.
- Retrying a failed preview without Master approval.
- Editing the final findings document or application files.

**Build order:**

1. **Test:** confirm the live list contains all twelve configured IDs and flag
   any missing, unpublished, draft-only, or unexpectedly renamed template
   before sending previews.
2. **Implement:** gather message JSON, compare contracts, perform the bounded
   previews, complete the browser handoff, and write the §3 evidence packet.
3. **Verify:** run the user, Devise, account, Pay, and client mailer tests; then
   confirm 3.1–3.6 each have a verdict, class, evidence, and follow-up value.

### Task 3 [subagent]: Audit delivery-path integrity

**Skills:** loops-api
**Reference:** Read `app/mailers/loops_delivery.rb`, all four Loops-backed
mailers, `app/clients/loops_client.rb`, the Loops jobs and retry concern,
`config/initializers/pay.rb`, `config/puma.rb`, `config/queue.yml`,
`config/recurring.yml`, and `render.yaml`
**Prototype:** None

**In scope:**

- Write only `.context/cov-67/lane-a2-delivery.md`.
- Gather checks 4.1–4.8 from current source and tests.
- For 4.1, audit all four mailer classes and twelve methods; confirm both common
  headers and all seven billing seeds.
- For 4.2, prove `body: ""` prevents template rendering despite engine-owned
  ERB files; confirm no app mailer views or previews have appeared.
- For 4.3, trace owner/billing-email fan-out, normalization, deduplication, and
  recipient-specific idempotency keys.
- For 4.4, record the exact retry sets. Correct the ticket premise: 400, 413,
  and inherited 422 propagate without retry; transactional 409 is deliberately
  absorbed as duplicate success. Leave intentionality to Task 9.
- For 4.5, record the inferred unthrottled transactional-burst exposure.
- For 4.6, record persisted Solid Queue terminal failures, Honeybadger's Active
  Job reporting, missing dedicated exhaustion monitoring, and any synchronous
  Pay delivery path. Leave sufficiency to Task 9.
- For 4.7, trace the dormant embedded worker through Puma, queue, recurring
  configuration, and pruning dispatch; mark it Inferred with COV-70 as the live
  confirmation.
- For 4.8, compare 30-day retention with Loops' 24-hour retry window.
- Produce evidence rows and decision packets for 4.4, 4.5, and 4.6.

**NOT in scope:**

- Calling Loops or changing external state.
- Deciding 4.4, 4.5, or 4.6.
- Adding retries, throttling, monitoring, tests, or job infrastructure.
- Editing the final findings document or application files.

**Build order:**

1. **Test:** search for headers, body suppression, views/previews, retry
   handlers, throttlers, recurring configuration, and retention.
2. **Implement:** write the 4.1–4.8 evidence table and decision packets.
3. **Verify:** run the focused mailer, client, job, model, account, and Render
   blueprint tests named by the checks; confirm every ID appears once.

### Task 4 [subagent]: Audit repository hygiene and design drift

**Skills:** review-changes-mini
**Reference:** Read `config/locales/en.yml`, current Loops implementation files,
active COV-37/COV-48 architecture designs, and shipped Loops designs under
`docs/designs/done/`
**Prototype:** None

**In scope:**

- Write only `.context/cov-67/lane-a3-repo-hygiene.md`.
- Complete 5.1 with `bin/rails test`, project-wide `bin/rubocop -f github`, and
  `bin/erb_lint --lint-all -f compact`; record exit codes and verbatim summaries.
- Wait for Task 3's Rails test process before starting the full Rails suite.
- For 5.2, establish that AccountMailer subjects remain, Pay's subject path is
  gem-owned and transport-dead, `LoopsDelivery` does not read `mail.subject`,
  and COV-37 retained subjects as documentation. Hand the decision to Task 9.
- For 5.3, dynamically inventory every Loops-related `AIDEV-NOTE` and validate
  each claim against implementation, callers, tests, and ownership tickets.
- Preserve COV-65 as registration ownership and COV-70 as post-launch
  verification.
- For 5.4, audit all 18 completed Loops designs against current source and tests.
  Preserve COV-52's explicit reconciliation-sweep amendment.
- Produce the §5 table and a doc-by-doc drift appendix.

**NOT in scope:**

- Fixing test/lint failures, stale notes, or design drift.
- Making the 5.2 decision.
- Editing completed designs or the final findings document.
- Running system tests or unrelated security tooling.

**Build order:**

1. **Test:** run the three repository gates and dynamic note/design inventories.
2. **Implement:** write evidence for 5.1–5.4 with exact locations and suggested
   wording for any stale documentation.
3. **Verify:** confirm all four IDs occur once and every real drift item has a
   proposed disposition.

Task 4 ends Checkpoint 2. If Tasks 2–4 ran in parallel, Master runs
`review-changes-mini` once after the whole batch returns; subagents do not run it.

### Task 5 [Master]: Verify production mail runtime configuration

**Skills:** none
**Reference:** Read `config/environments/production.rb`, `config/application.rb`,
`config/jumpstart.rb`, and the approved design's production-boot gotchas
**Prototype:** None

**In scope:**

- Write `.context/cov-67/lane-b-runtime.md`.
- Complete 1.3 and 1.4 with one local production boot:
  ```bash
  DATABASE_URL="postgres://$(whoami)@localhost/jumpstart_development" \
  HONEYBADGER_REPORT_DATA=false \
  RAILS_ENV=production \
  bin/rails runner '
    puts({
      delivery_method: Rails.application.config.action_mailer.delivery_method,
      default_url_options: Rails.application.config.action_mailer.default_url_options,
      jumpstart_domain: Jumpstart.config.domain,
      delivery_job: ActionMailer::Base.delivery_job.name
    }.inspect)
  '
  ```
- Require `:loops`, `covehomeschool.com`, and `LoopsMailDeliveryJob`.
- Use `ActionMailer::Base.delivery_job`, not the consumed config setting.
- Record the exact non-secret output and evidence class.

**NOT in scope:**

- Connecting to production or reading credentials.
- Sending mail.
- Allowing Honeybadger reports during the local production boot.

**Build order:**

1. **Test:** boot production with the safe database override and Honeybadger off.
2. **Implement:** record 1.3 and 1.4 in the lane file.
3. **Verify:** repeat only an assertion-specific read if needed; do not broadly
   retry an unexplained boot failure.

### Task 6 [Master]: Audit credentials and contact-sync configuration

**Skills:** loops-cli, browser:control-in-app-browser
**Reference:** Read `config/credentials/production.yml.enc`, `config/loops.yml`,
and COV-38 Decision 4
**Prototype:** None

**In scope:**

- Write `.context/cov-67/lane-c-credentials.md`.
- Load `RAILS_MASTER_KEY` from the local ignored key without printing it.
- Complete 1.1 with a production runner that prints only API-key presence,
  API-key last four, and webhook-secret presence.
- Use the browser to open Loops → Settings → API and inspect key names and
  masked endings. Do not click a reveal control or capture a complete key. If
  masked endings are unavailable without revealing, pause for the author to
  perform that secret-bearing comparison and return confirmation only.
- Inventory `cove-production`, `cove-staging`, and the later `cove-cli` key;
  record the COV-38 premise correction.
- Confirm the decrypted production ending matches `cove-production`.
- Complete 1.6 from the exact `config/loops.yml` environment matrix.

**NOT in scope:**

- Printing or recording full keys or webhook secrets.
- Rotating, creating, deleting, or renaming keys.
- Editing credentials or `config/loops.yml`.
- Falling back to the production server credential for CLI work.

**Build order:**

1. **Test:** perform the redacted credentials read, browser key inventory, and
   static environment-matrix inspection.
2. **Implement:** record 1.1, 1.2, and 1.6 using booleans, names, and endings only.
3. **Verify:** scan the lane file and repository diff for credential-shaped
   values; remove any accidental secret before continuing.

### Task 7 [Master]: Verify Render, mailing-list, and DNS evidence

**Skills:** loops-cli, loops-email-sending-best-practices,
browser:control-in-app-browser, review-changes-mini
**Reference:** Read `render.yaml`, `test/config/render_blueprint_test.rb`,
`config/loops.yml`, COV-53's list findings, and the DNS evidence in the design
**Prototype:** None

**In scope:**

- Write `.context/cov-67/lane-c-dashboard.md`.
- Use the browser to open Render → `cove-staging` → Environment and confirm
  `STAGING_EMAIL_RECIPIENT_ALLOWLIST` exists without exposing its value.
- If Task 8's three private addresses are available, let the author enter them
  in the masked field. The agent then saves, waits for restart, and verifies
  observable service behavior and the exact deployed SHA; do not trust the
  masked editor alone.
- Confirm locally that dormant production does not declare the staging guard.
- Run `env -u LOOPS_API_KEY loops lists list --team cove-cli --output json` and
  confirm the configured ID is the public `Cove updates` list.
- Use the browser to corroborate the current Loops list name/visibility where
  those are visually available; do not replace the CLI record.
- Transfer the already-gathered 2026-09-11 seven-record DNS evidence verbatim;
  do not rerun DNS.
- Record whether Task 8 is ready or Blocked-on-access.

**NOT in scope:**

- Revealing or replacing the complete allowlist without preserving entries.
- Provisioning production or changing DNS.
- Creating or modifying a Loops list.
- Retrying a Render mutation before confirming observable state.

**Build order:**

1. **Test:** inspect the blueprint, perform the read-only list lookup, and use
   the browser to inspect current Render/Loops state.
2. **Implement:** record 1.5, 1.7, 2.2, and Task 8 access readiness.
3. **Verify:** run `bin/rails test test/config/render_blueprint_test.rb` and scan
   the lane file for private data.

After Tasks 5–7, run `review-changes-mini` exactly once for Checkpoint 3.

### Task 8 [Master]: Resolve sender identity, DMARC, and inbox placement

**Skills:** loops-email-sending-best-practices,
browser:control-in-app-browser, review-changes-mini
**Reference:** Read the approved design's “Two leads” section, COV-38's domain
decisions, COV-55's footer evidence, and COV-68's staging record
**Prototype:** None

**In scope:**

- Write `.context/cov-67/lane-c-deliverability.md`.
- Use the browser to perform the actual staging and inbox verification. The
  author only signs in or enters private addresses/passwords/2FA when needed.
- Use one consistent staging transactional template across Gmail,
  Outlook/Hotmail, and Apple Mail: prefer password-reset requests if all three
  addresses already have staging accounts; otherwise use three unused private
  addresses/aliases and the `account_created` signup path. If neither uniform
  route exists, mark 2.4 Blocked-on-access.
- Inspect each received message in the browser and record Inbox/Promotions/
  Junk/Spam placement plus visible rendering. Do not save sensitive screenshots.
- Open Gmail's “Show original” view in the browser and capture only `From`,
  `Return-Path`, and `Authentication-Results` into the redacted lane evidence.
- Determine the recipient-visible From domain and SPF/DKIM/DMARC alignment.
- If Loops appends `mail.covehomeschool.com` to the `notify` local part, record
  `config/jumpstart.rb`'s apex default sender as transport-dead rather than active.
- Decide 2.3: whether apex DMARC should be added before launch and when the
  sending-subdomain policy should tighten from `p=none`; record evidence, risk,
  cost, and reversal path.
- Keep production inbox verification assigned to COV-70.

**NOT in scope:**

- Changing DNS, sender settings, DMARC, or templates.
- Inspecting browser session internals or committing private mailbox data.
- Substituting a preview for real inbox-placement evidence.
- Claiming staging is production verification.

**Build order:**

1. **Test:** perform the three real staging deliveries or establish the exact
   access blocker; inspect the received messages and authentication headers.
2. **Implement:** record 2.1, 2.3, and 2.4 plus decision reasoning.
3. **Verify:** confirm all provider outcomes or a precise Blocked row, then scan
   the evidence for private recipient data.

After Task 8, run `review-changes-mini` exactly once for Checkpoint 4.

### Task 9 [Master]: Make delivery and dead-weight decisions

**Skills:** loops-api, loops-email-sending-best-practices, review-changes-mini
**Reference:** Read the Task 3–4 decision packets, COV-37's subject decision,
COV-51's retry precedent, and COV-58's monitoring decision
**Prototype:** None

**In scope:**

- Write `.context/cov-67/lane-d-decisions.md`.
- Decide 4.4: whether mail delivery's narrower network retry set is intentional.
- Decide 4.5: whether unthrottled transactional bursts are acceptable at launch.
- Decide 4.6: whether Honeybadger attempt reporting plus persisted failures is
  sufficient without dedicated exhaustion monitoring.
- Decide 5.2: retain or remove transport-dead subject metadata.
- Classify every lane finding and draft a ready-to-paste follow-up ticket for
  every Fail, plus the requested variable-contract regression-test candidate.
- Apply only master-approved trivial typo/stale-comment corrections: no behavior
  changes, at most three corrected files, and every diff logged. Defer anything
  larger to a follow-up.

**NOT in scope:**

- Adding retries, throttlers, monitoring, tests, DNS, or other behavior.
- Filing tickets in Linear.
- Treating missing production observation as Pass.
- Applying a subagent-proposed fix without Master review.

**Build order:**

1. **Test:** verify the decision packets' factual premises against cited evidence.
2. **Implement:** record decisions, classifications, ticket drafts, and any
   bounded inline-fix log.
3. **Verify:** run focused tests for any touched source file, `git diff --check`,
   and a diff review proving no behavior change.

After Task 9, run `review-changes-mini` exactly once for Checkpoint 5.

### Task 10 [Master]: Assemble and verify the final audit

**Skills:** review-changes-mini
**Reference:** Read all `.context/cov-67/lane-*.md` files and the approved
findings-document structure
**Prototype:** None

**In scope:**

- Transfer sanitized evidence into `docs/designs/cov-67-loops-system-audit.md`.
- Fill all 29 findings rows.
- Record premise corrections: twelve templates; COV-68's prior staging proof;
  four mailer classes; transactional 409 duplicate success; and nuanced failed-
  job visibility.
- Write `## Verdict` last with an as-of date, exact blocking/non-blocking check
  IDs, and the work deliberately deferred to COV-70.
- Include prose decisions, follow-up drafts, inline-fix log, and appendices.
- Ensure every Fail has a follow-up, every Blocked row names its unblocker, and
  every Inferred row names its COV-70 confirmation.
- Keep raw private browser/inbox evidence under `.context/` only.

**NOT in scope:**

- New fixes or decisions discovered while formatting.
- Creating Linear tickets, changing ticket status, opening a PR, or merging.
- Claiming readiness while a launch-blocking Fail remains.

**Build order:**

1. **Test:** validate exactly 29 unique IDs and nonblank Verdict, Class,
   Evidence, and Follow-up cells.
2. **Implement:** assemble the final document and top-level verdict.
3. **Verify:** in the current message, run:
   ```bash
   export PATH="/Users/jordan/.local/share/mise/shims:$PATH"
   ruby -v
   bin/rails test
   bin/rubocop -f github
   bin/erb_lint --lint-all -f compact
   git diff --check
   git diff origin/main...
   git status --short
   ```
   Report the actual outputs and confirm no behavior change beyond logged
   trivial fixes.

After Task 10, run `review-changes-mini` exactly once for Checkpoint 6.

## Task Dependencies

- Task 1 must finish before any evidence lane.
- Tasks 2–4 are independent and run in parallel after Task 1.
- Task 2's CLI preview work is subagent-owned; Master completes its browser inbox
  inspection before Checkpoint 2 closes.
- Task 4 may run static/design work and linting in parallel, but its full Rails
  suite waits for Task 3's focused Rails process to exit.
- Task 5 depends only on Task 1 and may run while Tasks 2–4 are active.
- Task 6 depends on the local production key and browser access to Loops.
- Task 7 depends on private inbox readiness only for the allowlist preparation;
  its DNS and list checks are independent.
- Task 8 depends on Task 7's allowlist/restart confirmation. Missing mailbox
  access becomes Blocked-on-access after the browser sign-in handoff is exhausted.
- Task 9 depends on Tasks 2–8.
- Task 10 depends on all earlier tasks and is the only task that assembles lane
  output into the committed findings document.
- Subagents never commit. Master owns later commit boundaries during execution.
- No task exceeds the audit/no-fix scope except the explicitly logged trivial-
  correction allowance.
