> Ticket: COV-67
> Branch: chore/cov-67-pre-launch-audit-loops-email
> Plan created: docs/plans/cov-67-loops-system-audit.md

# Feature: Pre-launch audit of the Loops email system

## Problem

Thirteen tickets (COV-37 through COV-54, plus COV-47's verification pass and
COV-68's twelfth template) built Cove's entire email system on Loops. Each was
verified in isolation, on staging, against its own acceptance criteria. Nothing
has ever audited the whole system as one thing.

**Production does not exist yet.** `render.yaml`'s production block is still
commented out — COV-58 fixed its four config defects but explicitly deferred
provisioning. DNS agrees: `covehomeschool.com` has no A record; only
`staging.covehomeschool.com` resolves, to `cove-staging.onrender.com`.

COV-67 was therefore rewritten to cover only what is verifiable without a running
production service — roughly 70% of the original checklist. Those findings are
cheap to fix now and expensive to discover on launch day. Everything needing a
live production deploy moved to **COV-70**, which additionally depends on COV-65
(webhook registration).

This document designs *how* that audit runs. The audit's own output is a separate
file, `docs/designs/cov-67-loops-system-audit.md`.

## Approach

**Audit only. Nothing is fixed on this branch** beyond a narrowly defined
trivial-fix exception (below), each one logged. Every finding gets a table row
and, if real, a drafted follow-up ticket.

### Execution model — three clones plus master

| Lane | Who | Checks |
| -- | -- | -- |
| **A1 — Templates** | Clone | 3.1–3.6 |
| **A2 — Delivery path** | Clone | 4.1–4.8 |
| **A3 — Repo hygiene** | Clone | 5.1–5.4 |
| **B — Runtime config** | Master | 1.3, 1.4 |
| **C — Secrets and inbox** | Master | 1.1, 1.2, 1.5, 1.6, 1.7, 2.1, 2.2, 2.4 |
| **D — Judgment calls** | Master | 2.3, and the decision halves of 4.4, 4.6, 5.2 |

The three clone lanes touch disjoint files, need no credentials, and each emits
one self-contained findings table. §1 and §2 are not delegable — they need the
production master key and the author's Gmail. Lane D runs last, because several
decisions depend on what the clones surface first (4.4's retry-class divergence is
only decidable once A2 reports what it actually is).

**Clones gather evidence; master decides.** For 4.4, 4.6, and 5.2 the clone
records what is true and stops. The judgment is master's and lands in "Decisions
recorded."

**Parallelising is unusually safe here** because the no-fix rule means no clone
writes app code. Each appends one markdown table and nothing else — there is no
merge-conflict surface.

**The trivial-fix exception is master-only.** A clone that spots a typo reports it
as a row and does not fix it. This keeps every inline fix under one decision.

### Evidence standard

Check IDs map 1:1 to the ticket's checkboxes — `1.1`–`1.7`, `2.1`–`2.4`,
`3.1`–`3.6`, `4.1`–`4.8`, `5.1`–`5.4`. A missing ID is visible; follow-up tickets
cite a stable address ("COV-67 §4.2").

**Four verdicts.** The ticket names three; Lane D's rows are not assertions that
can pass or fail.

- **Pass** — checked, correct
- **Fail** — checked, wrong; gets a follow-up ticket
- **Blocked** — cannot be checked before production exists; names what unblocks it
- **Decided** — a judgment call, with reasoning recorded

**Four evidence classes.** The ticket asks to reuse COV-47's vocabulary, but
COV-47's A/B axis measured *trigger fidelity for live sends* and most of this
ticket is not a send. Tier B keeps its name and meaning; two classes are added
that A/B does not cover.

| Class | Means |
| -- | -- |
| **Observed** | From the artifact itself — CLI output, a decrypted credential, a runtime boot readback, a real message header |
| **Tier B** | Sampled from staging. Representative because team, domain, SES pool, and reputation are shared (COV-38 Decisions 1–2), but not a production measurement |
| **Inferred** | Reasoned from code or config without observing behaviour. Correct reasoning, unobserved conclusion |
| **Decision** | No evidence; a recorded choice |

**Inferred earns its place.** 4.5 (throttler burst exposure) and 4.7 (whether the
blueprint's `startCommand` dispatches the recurring job) cannot be observed before
production runs. Marking those "Pass" without a class meaning "reasoned, not seen"
is precisely the overclaiming COV-47's fidelity ladder existed to prevent. Every
Inferred row carries a one-line note on what would confirm it; most point at
COV-70.

Evidence is verbatim and reproducible: each row records the command or source
alongside the output, with long dumps in an appendix.

Row shape:

| ID | Check | Verdict | Class | Evidence | Follow-up |
| -- | -- | -- | -- | -- | -- |

### Findings document structure

`docs/designs/cov-67-loops-system-audit.md`:

```
## Verdict              ← written last, read first
## Method               ← lanes, evidence classes, when it ran, tooling
## Corrections to the ticket's stated premises
## 1–5. Findings        ← one table per ticket section
## Decisions recorded   ← Lane D, in prose
## Follow-up tickets    ← drafted, ready to paste
## Inline fixes applied ← the trivial-fix log
## Appendices           ← long dumps
```

- **The verdict splits blocking from non-blocking and states what moved to
  COV-70.** "Launch-ready-except-these" is only actionable if "these" is a list
  with check IDs, and a reader months later needs to see that deferrals were
  chosen rather than missed. The verdict carries an as-of date.
- **§3 gets two tables.** Twelve templates × six checks is 72 cells in one grid.
  One summary row per template, plus a variable-diff table listing only
  mismatches — which is empty on a clean run, the clearest possible result.
- **Decisions get prose, not table cells.** COV-38's Decision 1 is the most
  valuable part of that document because it recorded reasoning, cost, and
  reversal path in sentences. COV-70 and whoever tightens DMARC will read these.
- **Follow-up tickets are drafted inline, ready to paste**, in the format used for
  COV-70. The doc is where they live until filed in Linear.
- **Inline fixes get their own log** — what, why it qualified, the diff. The
  acceptance criterion says "each noted"; scattering them across five tables makes
  that unverifiable.
- **Appendices** hold the twelve-template JSON, the raw header dump, and the
  production boot readback.

## Acceptance Criteria

- [ ] All 29 checks carry a verdict, an evidence class, and verbatim evidence
- [ ] `docs/designs/cov-67-loops-system-audit.md` exists, with the verdict at top
      and an as-of date
- [ ] **2.1 is answered definitively from a real message's headers**, not inferred
      from `fromEmail: "notify"`. Highest-risk item in the ticket
- [ ] All twelve template IDs confirmed published and variable-matched
- [ ] Every Fail has a drafted follow-up ticket in the doc
- [ ] Every Blocked row names what unblocks it and distinguishes
      blocked-on-production from blocked-on-access
- [ ] Every inline fix appears in the inline-fix log
- [ ] `git diff` shows no behaviour change beyond logged trivial fixes

## Prototype

None. Operational audit, no Cove UI work.

## Data Model

No schema, model, or migration changes.

## Screens / Flows

No UI. The flow is the audit run: master completes setup, launches A1–A3
concurrently, runs Lane B while they work, runs Lane C against the key file and
the Gmail dump, then Lane D on assembled results, then writes the document.

## Scope

**In:** static configuration and credentials, sender identity and DNS, the twelve
templates as they exist in Loops today, delivery-path integrity at code and
blueprint level, repo hygiene. The findings document. Drafted follow-up tickets.

**Deferred:**
- Everything requiring a live production service → **COV-70**
- Building COV-52's reconciliation sweep (its amendment explains why not)
- A standing regression test asserting mailer `dataVariables` match the Loops
  templates. 3.2 makes this obvious and it would be genuinely useful — it is
  still scope creep. Note it as a candidate follow-up ticket; do not build it
- The first marketing campaign send; dedicated sending IPs
- DMARC enforcement beyond deciding *when*
- Any fix arising from this audit, excepting logged trivial fixes

## Open Questions

1. **Does the author have Outlook/Hotmail and Apple Mail addresses for 2.4?**
   COV-46's staging allowlist is exact-match and fail-closed, so each address must
   be added to `STAGING_EMAIL_RECIPIENT_ALLOWLIST` in Render, and changing that
   variable restarts the service. The ticket does not mention this prerequisite.
   If the addresses don't exist, 2.4 is Blocked-on-access, not Blocked-on-production.

Resolved during brainstorm:

2. ~~Unpublished or stale template — blocker or follow-up?~~ **Blocker.** A hard
   send failure, unlike spam placement.
3. ~~Is the From/DMARC fix allowed inline?~~ **No — follow-up ticket.** It is a
   deliverability decision with a DNS component, not a typo.
4. ~~Who files follow-up tickets?~~ Drafted in the doc; the author files them.

## More Info

### Setup already verified (do not redo)

- **Loops CLI is authed to the Cove team.** `loops auth status` →
  `teamName: Cove`, `activeKey: cove-cli`, key ending `b192`. v0.10.1; an upgrade
  to v0.11.0 is offered and has not been taken.
- **`config/credentials/production.key` exists in this worktree** (33 bytes,
  `chmod 600`, gitignored at `.gitignore:78`). It was originally created in the
  main checkout at `/Users/jordan/Documents/Repos/cove/` and copied across.
  Credentials decrypt successfully.

### Gotchas that would otherwise produce wrong findings

- **`ActionMailer::Base.delivery_job` is the authoritative read for 1.4, not
  `config.action_mailer.delivery_job`.** The railtie consumes the config option at
  boot, so the config object reports `nil` after boot and would yield a confident,
  wrong **Fail** on the retry-loss check. Verified:
  `config.action_mailer.delivery_job` → `nil`;
  `ActionMailer::Base.delivery_job` → `LoopsMailDeliveryJob`.
- **`RAILS_ENV=production bin/rails runner` cannot boot unaided.** Production's
  `database.yml` wants a `jumpstart` Postgres role that does not exist locally.
  Pass `DATABASE_URL="postgres://$(whoami)@localhost/jumpstart_development"`.
- **Always set `HONEYBADGER_REPORT_DATA=false` on production-boot commands.**
  Production credentials carry a live Honeybadger key; two real faults were
  reported to the production project during setup.
- **Prepend mise shims** before any `bin/rails` / `bin/rubocop`:
  `export PATH="$HOME/.local/share/mise/shims:$PATH"` (see AGENTS.md).
- **Do not run RuboCop directly on `.erb` paths** — use project-wide `bin/rubocop`.

### Evidence already gathered

**DNS (2026-09-11, `dig`) — all seven COV-38 records resolve. Covers 2.2.**

| Name | Type | Value |
| -- | -- | -- |
| `envelope.mail` | MX | `10 feedback-smtp.us-east-1.amazonses.com` |
| `envelope.mail` | TXT | `v=spf1 include:amazonses.com ~all` |
| `_dmarc.mail` | TXT | `v=DMARC1; p=none;` |
| `_loops-verification.mail` | TXT | `2f85d56049682c6221efc42925b4e3a12566ad1b783e1626e7192c61726a69e8` |
| `hbu7dp3g32h3spdnprzdgtruvortdgb2._domainkey.mail` | CNAME | `…dkim.amazonses.com` |
| `oybes6is5rysn2mmggzsemo56ixt5b7y._domainkey.mail` | CNAME | `…dkim.amazonses.com` |
| `vkjh5t3sgziietboqpd5kljrhghzy4bt._domainkey.mail` | CNAME | `…dkim.amazonses.com` |

Also confirmed: `_dmarc.covehomeschool.com` (apex) **does not exist**, and the
apex has no A record.

**Templates (2026-09-11, `loops transactional list`).** All twelve IDs in
`config/loops.yml` resolve. Every one has a published message and an empty draft
column. Partial evidence for 3.1 — the remaining work is confirming each ID maps
to the template the mailer intends, not merely that it exists.

**`loops email-messages get <publishedMsgId> -o json` returns everything 3.2–3.5
needs** — `subject`, `previewText`, `fromName`, `fromEmail`, `replyToEmail`,
`emailFormat`, and the full `lmx` body. Variable references appear as
`{data.some_key}`, so the 3.2 diff is mechanical: extract `{data.*}` from LMX,
extract `dataVariables` keys from the mailers, compare.

### Two leads the audit must resolve, not assume

**2.1 — the from-domain premise may be inverted.** `account_created` returns
`"fromEmail": "notify"` — a bare local part, not a full address. Loops appends the
verified sending domain, which implies the From recipients see is
`notify@mail.covehomeschool.com`, **not** the apex the ticket's premise assumes.
If so, DMARC resolves to `_dmarc.mail.covehomeschool.com`, which exists at
`p=none`, and COV-38's apex-insulation mitigation *is* in effect.

The finding does not disappear, it changes shape:
`config/jumpstart.rb`'s `default_from_email = "Cove <notify@covehomeschool.com>"`
would be **dead config**, since Loops' per-template From wins and the app's header
is discarded. That is a different follow-up than the ticket anticipates.

**This must be confirmed from a real `Authentication-Results` header, not
inferred from the JSON.** COV-47's 2026-08-19 Gmail sends are the evidence; the
author still has them and will supply one "Show original" dump. Record `From:`,
`Return-Path:`, and `Authentication-Results:` verbatim in Appendix B.

**1.2 — the API key inventory has drifted from COV-38.** Decision 4 recorded
exactly two keys, `cove-production` and `cove-staging`, with the unnamed `e858`
key retired. The CLI authenticates as `cove-cli` (…`b192`), a third key no design
doc mentions. 1.2 should inventory the team's keys rather than only confirm that
production's is production's.

### Reference

- **Check 4.2's real target.** `app/views/` has no mailer directories, but the
  Jumpstart engine ships nine mailer templates on the view path:
  `lib/jumpstart/app/views/account_mailer/` (`invite`, `cancellation_reason`, html
  and text) and `lib/jumpstart/app/views/devise/mailer/` (five templates). "Both
  directories are empty" is true of the app, not the engine — so 4.2 must prove
  `mail(to:, body: "")` short-circuits template lookup, not assert it.
- **Check 4.4's divergence.** `LoopsMailDeliveryJob` declares its own `retry_on`
  and does **not** include the `LoopsRetryable` concern, which adds `SocketError`,
  `Errno::ECONNREFUSED`, and `Errno::ECONNRESET` for the contact and event jobs.
  Whether that is intentional is a Lane D decision.
- **Check 4.8's constant.** `LoopsWebhookEvent::RETENTION` is `30.days`; Loops'
  retry window is 24 hours.
- **Check 4.5's constant.** `LoopsClient` defaults to `NO_OP_THROTTLER`; only
  `LoopsContactBackfillJob` passes a real throttler. The budget is 10 req/sec,
  shared with staging (COV-38).
- **Check 1.7's value.** `contact_sync_mailing_list_id` is
  `cmsdo8ncl02wc0j0j4rxwhy4l`, expected to be the live `Cove updates` list.
- **Escalation.** A Fail that blocks launch — a template ID that 404s, say — is
  reported to the author in-session immediately, then recorded. It does not wait
  for the finished document.
