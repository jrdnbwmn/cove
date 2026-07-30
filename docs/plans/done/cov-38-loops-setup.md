> Ticket: COV-38
> Branch: feature/cov-38-loops-teams-domains-api-keys

# Plan: Loops teams, sending domains, and API keys

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Generate + store + verify `cove-production` and `cove-staging` keys | Master | ✅ |
| 2 | 1 | 1 | Retire the unnamed `e858` key and clean up local CLI state | Master | ✅ |
| 3 | 1 | 1 | Transactional smoke test (AC #5) + correct the runbook's delete step | Master | ✅ |
| 4 | 2 | 2 | Record the `help@loops.so` reply (or pending status) and close the AC table | Master | ✅ |

Every task is Master. This ticket ships no app code — it is sequential, browser-
and CLI-driven ops requiring user logins and secret handling, so there is nothing
to fan out to clones.

## Prerequisites

- Design: `docs/designs/cov-38-loops-setup.md`
- Prototype: None
- Feature branch exists: `feature/cov-38-loops-teams-domains-api-keys` (current)
- Loops CLI installed at `/Users/jordan/.local/bin/loops`, authenticated as `cove`
- User available for the Loops dashboard login and for typing key values

**Already complete — do not redo** (design §0): team `Cove`, company name/address,
`mail.covehomeschool.com` verified, all 7 Namecheap DNS records live, CLI
authenticated, seeded sample drafts deleted, support email sent.

**Live state verified 2026-07-28, before planning:**

- `loops auth list` → `thistle` (`…07da`), `cove` (`…e858`, active)
- `loops auth status` → `teamName: Cove`
- `loops transactional list` → `[]`; `loops workflows list` → `[]`

---

## Tasks

### Task 1 [Master]: Generate, store, and verify the two named API keys

**Skills:** loops-cli
**Reference:** design §2 "Generate the two named API keys", Decision 4

**In scope:**

- Loops dashboard → Settings → API → Generate key, name `cove-production`. Repeat
  for `cove-staging`.
- **The user stores each key themselves, in their own terminal** —
  `loops auth login cove-production` then `loops auth login cove-staging`. The
  command prompts for the key value interactively, so it never enters shell
  history and Claude never sees it. This is what holds AC #9.
- Verify each: `loops api-key --team cove-production -o json` and
  `loops api-key --team cove-staging -o json` — both must return
  `{"success": true, "teamName": "Cove"}`.
- Confirm `loops auth list` now shows four entries: `thistle`, `cove`,
  `cove-production`, `cove-staging`.

**NOT in scope:**

- Removing the old key — that is Task 2, and order is load-bearing (the CLI is
  currently authenticated *with* the key being retired).
- Writing either value into `config/credentials/*.yml.enc` — that is COV-39.
- A third `cove-cli` key. Open Question 2 defers this to COV-40. Accepted
  consequence: after Task 2 the production key sits in `~/.loops` on a personal
  laptop.

**Build order:**

1. Drive the dashboard to Settings → API (user handles login).
2. Generate both keys; user runs the two `loops auth login` commands.
3. **Verify:** `loops api-key --team cove-production -o json` and
   `loops api-key --team cove-staging -o json`; both must report team `Cove`. Do
   not proceed to Task 2 unless both pass.

---

### Task 2 [Master]: Retire the unnamed key and clean up local CLI state

**Skills:** loops-cli
**Reference:** design §2 steps 5–6

**In scope:**

- Only after both Task 1 verifications pass: Loops → Settings → API → remove the
  unnamed key ending `e858`.
- Clean up the now-dead local entry — the design omits this:
  `loops auth logout cove` (removes the stale `e858` entry), then
  `loops auth use cove-production` to set the active key.
- Confirm the retired key is genuinely dead and the CLI still works:
  `loops auth status` should show `activeKey: cove-production`,
  `teamName: Cove`, and a key ending in the production key's last 4 (not `e858`).
- Leave the unrelated `thistle` entry alone — it belongs to a different project.

**NOT in scope:**

- Deleting the `thistle` credential, rotating anything else, or touching the
  Loops team/domain settings.

**Build order:**

1. Remove `e858` in the dashboard (user login).
2. `loops auth logout cove` && `loops auth use cove-production`.
3. **Verify:** `loops auth status -o json` — assert `activeKey` is
   `cove-production` and the key fingerprint is not `…e858`. Report the resolved
   team.

---

### Task 3 [Master]: Transactional smoke test (AC #5)

**Skills:** loops-cli
**Reference:** design §3

**In scope:**

- `loops transactional create -n "cov-38 smoke" --team cove-production` — this is
  the actual gate the whole ticket existed to open. If the verified domain
  weren't accepted, creation fails here.
- `loops transactional list -o json` — confirm the record exists; capture its id.
- **Delete it via the Loops dashboard, not the CLI.**
  `loops transactional delete` does not exist — the CLI exposes only
  `create / draft / get / list / publish / send / update`. The design's §3 code
  block is wrong on this point and must be corrected in the doc as part of this
  task.
- `loops transactional list -o json` → back to `[]`.
- Update `docs/designs/cov-38-loops-setup.md`: mark AC #5 **Done**, and replace
  the §3 smoke-test block with the corrected create → list → dashboard-delete →
  list sequence, with a one-line note that the CLI has no delete verb.

**NOT in scope:**

- Publishing or *sending* the smoke email. Creating a draft proves the domain
  gate; sending would burn free-plan quota against an unresolved Open Question 1.
- Authoring any real template — COV-40/41/42.

**Build order:**

1. Run create + list; record the id.
2. Delete in the dashboard (user login); re-run list and confirm `[]`.
3. Edit the design doc: AC #5 → Done, §3 corrected.
4. **Review:** run review-changes-mini covering Checkpoint 1 (Tasks 1–3). If
   these tasks were executed as a parallel batch, the master runs this review
   once the whole batch returns rather than the task running it itself — either
   way it runs exactly once, after every task in the checkpoint is done. The only
   diff is the design-doc edit; Tasks 1 and 2 produce no repo changes and are
   verified against their ACs instead, per the COV-32 precedent.

---

### Task 4 [Master]: Record the support reply and close the AC table

**Reference:** design §4, Findings → "Unresolved", Open Question 1

**In scope:**

- **Blocked on an external reply from `help@loops.so`** (sent 2026-07-28). If no
  reply has arrived when the rest of the plan is done, do not stall the ticket —
  record "no reply as of `<date>`" and ship.
- When the reply lands, update the **Unresolved** subsection of Findings with the
  answers to all four questions (free-plan send accounting, attachments, CC/BCC,
  preview cap).
- Resolve Open Question 1 in the doc. If transactional **does** draw down the
  4,000/30-day allowance, add an explicit carry-forward note to COV-53 — it is
  the first ticket to create an audience and would be spending from the same
  budget as the eleven COV-37 transactional triggers.
- Update AC #6 status with the actual outcome.

**NOT in scope:**

- Changing Decision 1 or Decision 2. Neither turns on the support answers —
  Decision 1 was declined on volume grounds, and the free-plan accounting
  question affects budgeting, not domain topology.
- Acting on the attachment answer. COV-37 already removed that dependency by
  choosing a linked receipt over an attached PDF.

**Build order:**

1. Check for the reply.
2. Update Findings, Open Question 1, and AC #6 in
   `docs/designs/cov-38-loops-setup.md`.
3. **Review:** run review-changes-mini over Checkpoint 2 (Task 4).

---

## Task Dependencies

- Strictly sequential: **1 → 2 → 3**. Task 2 must not start until both Task 1
  keys verify, or the CLI is left with no working credential mid-runbook. Task 3
  needs `cove-production` to exist (Task 1) — it does not need Task 2, but
  running it after keeps the runbook linear.
- Task 4 is gated on an external email reply, not on Tasks 1–3. It can be done at
  any point after the reply arrives, including after the others are finished.
- No parallelism — which is why every task is Master.
