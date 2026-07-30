> Ticket: COV-38
> Branch: feature/cov-38-loops-teams-domains-api-keys
> Plan created: docs/plans/cov-38-loops-setup.md

# Feature: Loops teams, sending domains, and API keys

## Problem

Cove had no Loops team. The CLI on the author's machine was authenticated to
"Thistle Book" — a different project. Loops blocks creating transactional
emails and editing drafts until a sending domain is verified, so this gated all
template authoring (COV-40, COV-41, COV-42) and the client work in COV-39.

This ticket also carries the project's most expensive-to-reverse decision:
whether transactional and marketing email share a sending reputation.

## Approach

Manual provisioning, no app code. The deliverable is this document: a runbook
of what was done, plus a findings note recording the real limits with evidence
and the domain decision with its reversal cost.

**No code, gems, credentials, or config changes are made by this ticket.**

---

## Findings

All gathered 2026-07-28 from the Loops dashboard and verified independently
with `dig` where DNS-observable.

### Loops runs on Amazon SES (us-east-1)

Every DNS record points at `amazonses.com`. The ticket did not know this. It
explains the record shapes (random 32-char DKIM selectors, a `feedback-smtp`
MX for bounce/complaint routing) and means Loops inherits SES's deliverability
behaviour rather than operating its own MTA.

### Limits, confirmed

| Question | Answer | Evidence |
| -- | -- | -- |
| Sending domains per team | **One** | Settings → Domain exposes a single `Sending domain` field; the records page is scoped to one domain id (`cms4sn00400kx0jwkndkwl204`) |
| Teams per account | **Multiple** | Team switcher → Teams → **"+ Create team"** present and unblocked on the free plan |
| API keys per team | **Multiple** | Settings → API — "Generate keys for specific tasks or integrations" |
| Free plan contacts | 1,000 subscribed | Settings → Billing |
| Free plan sends | 4,000 per rolling 30 days | Settings → Billing |
| Transactional and contact-update rate limit | 10 requests/sec | `help@loops.so`, 2026-07-29 |
| Content API rate limit | 60 requests/min for `/v1/campaigns`, `/v1/workflows`, and `/v1/transactional_email`; response headers report remaining capacity | `help@loops.so`, 2026-07-29 |

The "teams per account: multiple" answer resolves the ticket's stated
unknown #4, and it is the one that mattered — a transactional/marketing split
would **not** have forced a paid plan the way the ticket feared. The split was
declined on other grounds (see Decision 1).

### Support reply — resolved 2026-07-29

`help@loops.so` confirmed the following:

1. **Attachments are enabled** for Cove's account. They remain optional because
   COV-37 uses a linked receipt rather than an attached PDF.
2. **Transactional and marketing sends both count** against the same 4,000-send
   free-plan allowance, measured on a rolling 30-day window.
3. **CC/BCC is supported**, with one recipient enabled by default; additional
   recipients require a request to Loops support. The user must enable CC/BCC
   in Settings → Sending before use.
4. **Preview sends are capped at 100 per day.**
5. **Rate limits:** transactional sending and contact updates allow 10 requests
   per second; content endpoints (`/v1/campaigns`, `/v1/workflows`, and
   `/v1/transactional_email`) allow 60 requests per minute. Loops includes
   response headers that show remaining capacity.

### Incidental discoveries worth carrying forward

- **Settings → Account has an "Email Blocklist"** — patterns that block
  addresses "from being added to your audience **or sent transactional
  emails**." This is an account-level send kill switch that operates *inside*
  Loops, independent of anything Rails does. **COV-46 should know this
  exists**; it currently plans to rely solely on
  `config.action_mailer.perform_deliveries = false`
  (`config/environments/staging.rb:65`). The blocklist is a viable second layer
  that survives a misconfigured environment.
- Loops seeds new teams with sample drafts. Two existed here — a transactional
  ("Your payment was received — view your receipt") and a workflow ("Welcome to
  your new community hub"). Both deleted; `loops transactional list` and
  `loops workflows list` now both return `[]`.
- The free-plan "Powered by Loops" footer is accepted (Open Question 5,
  decided by the author). Not a blocker on auth-critical mail.

---

## Decisions

### Decision 1 — One sending domain for all mail: `mail.covehomeschool.com`

Transactional and marketing share one team, one domain, one sending
reputation. **This is the expensive-to-reverse decision and the reasoning is
recorded in full below, per the ticket's requirement.**

**Why.** One domain per team is a hard Loops limit, so splitting means a second
team. That is *possible* (confirmed above) but buys nothing today: marketing
volume is currently zero — COV-48 and COV-49 have not landed, and COV-53 has
not created a single list or contact. Reputation damage is caused by campaign
volume and complaint rates; with no campaigns, there is no pool to
contaminate. Splitting now would mean a second DNS round, a second warm-up, and
a second team to keep in sync, all to insulate against a risk that does not yet
have a source.

**The risk being accepted, stated plainly.** Password reset is this app's only
non-OAuth recovery path. If Cove later sends marketing campaigns that generate
spam complaints, reset deliverability degrades on the same domain, and a
spam-foldered reset locks a user out of their account. This risk is real. It is
*latent* rather than absent — it activates the moment marketing volume becomes
non-trivial.

**One mitigation is already in place.** Sending from the `mail.` subdomain
rather than the apex insulates `covehomeschool.com` itself. The apex carries a
Google site-verification TXT and is the address people type; subdomain
reputation is tracked substantially separately from apex reputation at the
major providers.

**What it would take to reverse — and why the reversal is safe.** The reversal
is *asymmetric*, and that asymmetry is what makes this decision defensible:

- **Moving marketing off later (the intended path).** Create a second team, add
  a new subdomain (e.g. `news.covehomeschool.com`), run one DNS round, generate
  a key, and re-create lists/campaigns in the new team. The expensive part is
  re-importing contacts and preserving their subscribe/consent state. But
  **transactional keeps the warm domain and its accumulated reputation, and
  password resets are never disrupted.** The auth-critical side does not move.
- **Moving transactional off later (never do this).** A new cold domain would
  have to be warmed *while carrying auth-critical mail* — which is precisely the
  deliverability exposure the split was meant to prevent.

So the escape hatch exists and it preserves the side that matters. Recorded
rule: **if this is ever split, marketing moves — transactional stays put.**

**Code impact of a future split** is contained. `config/loops.yml` (COV-37
Decision 3) currently uses a `shared:` block; a split would add a per-purpose
key and require `LoopsClient` to select a key per call site. Real work, but
bounded and not architectural.

**Trigger for revisiting:** when COV-48/COV-49 land and marketing volume
becomes real, or at the first sign of reset-email deliverability trouble
(bounce/complaint rates, user reports of missing resets).

### Decision 2 — One shared team across environments, with per-environment API keys

The ticket framed per-environment key separation as requiring a separate team,
on the assumption of one key per team. **That assumption is wrong** — keys are
unlimited per team. So the shared-team decision still yields independently
revocable, independently rotatable credentials per environment, against the
same already-warm domain.

**What this gets us.** Per-environment revocation and rotation, matching the
credentials split COV-31 established (`config/credentials/staging.yml.enc`,
`config/credentials/production.yml.enc`). A leaked staging key is revoked
without touching production.

**What it does not get us, honestly:**

- **No rate-limit isolation.** The 10 req/sec limit is per *team*, so staging
  consumes production's budget.
- **No reputation isolation** between environments.
- **No audience isolation.** This is the sharpest one: staging contacts would
  land in the *production* audience and count against the 1,000-contact free
  limit. **COV-53 must account for this** — it is the first ticket that creates
  contacts, and under a shared team there is no separate staging audience to
  create them in.

**Why that is acceptable today.** Staging sends nothing: COV-37 established
`perform_deliveries = false` at `config/environments/staging.rb:65`, verified as
a genuine kill switch (`Mail::Message#do_delivery` checks it before invoking the
delivery method). Production is not provisioned — `render.yaml`'s production
block is commented out. The account-level Email Blocklist is available as a
second layer if needed.

**Reversal cost: low.** Creating a second team later requires a new subdomain
and DNS round, but has *zero* impact on the production team's warm reputation —
the staging domain is cold either way. Unlike Decision 1, there is no
"decide while cold" urgency here.

### Decision 3 — No separate non-production subdomain

Follows from the one-domain-per-team limit plus Decision 2. Revisit only if
Decision 2 is revisited.

### Decision 4 — Two named API keys, retiring the unnamed one

Replace the single unnamed key (ending `e858`, created with the team) with:

| Key name | Consumer | Stored in |
| -- | -- | -- |
| `cove-production` | production Rails | `config/credentials/production.yml.enc` (COV-39) |
| `cove-staging` | staging Rails | `config/credentials/staging.yml.enc` (COV-39) |

**Sequencing matters.** The local CLI's active key *is* the unnamed `e858` key.
Removing it first would break the CLI mid-runbook. Generate and verify the new
keys before removing the old one.

---

## Acceptance Criteria

Status as of this document.

| # | Criterion | Status |
| -- | -- | -- |
| 1 | `loops auth status` resolves to the Cove team, not "Thistle Book" | **Done** — `teamName: Cove`, `activeKey: cove` |
| 2 | `loops api-key` reports a valid key | **Done** — `{"success": true, "teamName": "Cove"}` |
| 3 | SPF, DKIM, DMARC live at Namecheap and verified in the Loops dashboard | **Done** — "All records verified for mail.covehomeschool.com" |
| 4 | `dig TXT` and the DKIM selectors return expected values | **Done** — all 7 records verified independently, below |
| 5 | Smoke test: create a transactional email, then delete it | **Done** — created `cov-38 smoke`, confirmed it listed, then deleted it in the Loops dashboard and confirmed the list returned to `[]` |
| 6 | Attachment-enablement request sent; reply or pending status recorded | **Done** — support replied 2026-07-29; attachments enabled, with send accounting, CC/BCC, preview, and rate-limit details recorded in Findings |
| 7 | Findings note records limits with evidence | **Done** — see Findings |
| 8 | Domain decision recorded with reasoning, cost, and reversal path | **Done** — see Decision 1 |
| 9 | No API key value appears in any committed file | **Held** — keys referenced by name and last-4 only |

## Prototype

None.

## Data Model

No changes. This ticket touches no app code.

---

## Screens / Flows — the runbook

### 0. Already complete (do not redo)

- Loops account created, owner `hello@covehomeschool.com`, team **Cove**, one
  active member.
- Company name `Cove` and company address set (both appear in email footers and
  are a CAN-SPAM requirement).
- Sending domain `mail.covehomeschool.com` added and **fully verified**.
- All seven DNS records live at Namecheap (Advanced DNS, plain records — no
  Cloudflare, no nameserver move, per the COV-32 precedent).
- CLI authenticated: `loops auth login cove`, active.
- Loops' two seeded sample drafts deleted.
- Support email sent to `help@loops.so`.

### 1. DNS record inventory (reference — all live and verified)

Names are relative to `covehomeschool.com` as entered at Namecheap.

| Name | Type | Value | Priority |
| -- | -- | -- | -- |
| `envelope.mail` | MX | `feedback-smtp.us-east-1.amazonses.com` | 10 |
| `envelope.mail` | TXT | `v=spf1 include:amazonses.com ~all` | — |
| `_dmarc.mail` | TXT | `v=DMARC1; p=none;` | — |
| `_loops-verification.mail` | TXT | `2f85d56049682c6221efc42925b4e3a12566ad1b783e1626e7192c61726a69e8` | — |
| `hbu7dp3g32h3spdnprzdgtruvortdgb2._domainkey.mail` | CNAME | `hbu7dp3g32h3spdnprzdgtruvortdgb2.dkim.amazonses.com` | — |
| `oybes6is5rysn2mmggzsemo56ixt5b7y._domainkey.mail` | CNAME | `oybes6is5rysn2mmggzsemo56ixt5b7y.dkim.amazonses.com` | — |
| `vkjh5t3sgziietboqpd5kljrhghzy4bt._domainkey.mail` | CNAME | `vkjh5t3sgziietboqpd5kljrhghzy4bt.dkim.amazonses.com` | — |

None of these are secrets — all are publicly queryable by design.

**Re-verification one-liner** (AC #4), useful whenever deliverability is
suspect:

```bash
D=covehomeschool.com
dig +short MX  envelope.mail.$D
dig +short TXT envelope.mail.$D
dig +short TXT _dmarc.mail.$D
dig +short TXT _loops-verification.mail.$D
for s in hbu7dp3g32h3spdnprzdgtruvortdgb2 \
         oybes6is5rysn2mmggzsemo56ixt5b7y \
         vkjh5t3sgziietboqpd5kljrhghzy4bt; do
  dig +short CNAME $s._domainkey.mail.$D
done
```

**Gotcha for the next reader:** SPF and the bounce MX live on
`envelope.mail.covehomeschool.com`, **not** `mail.covehomeschool.com`. Querying
the sending domain directly returns nothing and looks like a broken setup. The
DKIM selectors are random SES tokens and cannot be guessed — read them from
Settings → Domain → View records.

### 2. Generate the two named API keys (Decision 4)

Order is load-bearing — the CLI is currently authenticated with the key being
retired.

1. Loops → Settings → API → **Generate key**, name `cove-production`. Copy the
   value. **Do not paste it into any file in this repo.**
2. Repeat for `cove-staging`.
3. Store both via the CLI so the author can select them later:
   `loops auth login cove-production`, `loops auth login cove-staging`.
4. Verify each resolves to the Cove team:
   `loops api-key --team cove-production` and
   `loops api-key --team cove-staging` — both must return
   `{"success": true, "teamName": "Cove"}`.
5. **Only after both verify:** Settings → API → Remove the unnamed key ending
   `e858`.
6. Confirm the retired key is dead and the CLI still works:
   `loops auth status --team cove-production`.

Hand-off to COV-39: the two values go into
`config/credentials/staging.yml.enc` and
`config/credentials/production.yml.enc` under `loops.api_key`, read as
`Rails.application.credentials.dig(:loops, :api_key)` — matching the existing
Stripe/Google pattern established by COV-31.

### 3. Smoke test (AC #5)

```bash
loops transactional create -n "cov-38 smoke" --team cove-production
loops transactional list --team cove-production  # confirm it exists
# Delete the draft in the Loops dashboard; the CLI has no transactional delete verb.
loops transactional list --team cove-production  # confirm [] again
```

This proves the verified domain actually unblocks transactional creation —
the gate this whole ticket existed to open.

### 4. Record the support reply

When `help@loops.so` responds, update the **Unresolved** subsection of Findings
with the answers, and resolve Open Question 1 below.

## Scope

**In:** Loops team, sending-domain verification, Namecheap DNS, API key
generation and CLI storage, support request, findings note, and the
transactional/marketing domain decision with its reversal cost.

**Deferred / out:**

- App code, gems, credentials wiring — COV-39.
- Template authoring — COV-40, COV-41, COV-42.
- Mailing lists, contacts, campaigns, audience config — COV-53.
- Staging email behaviour — COV-46.
- Dedicated sending IPs. DMARC enforcement beyond `p=none`.

## Open Questions

1. **Resolved — transactional counts against the free plan's 4,000 sends/30
   days.** Marketing and transactional sends share the same rolling 30-day
   allowance. **Carry forward to COV-53:** before it creates an audience or
   campaign, budget its planned sends together with COV-37's eleven
   transactional triggers and check Loops' rate-limit response headers.
2. **Should local template authoring use a third key rather than the production
   key?** Decision 4 creates two keys, both destined for server credentials. But
   COV-40/41/42 author templates from the author's laptop via the CLI, which
   means a production key sits in `~/.loops` on a personal machine. A third key
   (`cove-cli`) would keep the production credential off the laptop entirely, at
   the cost of one more key to manage. Templates are team-scoped, so any key can
   author them — this is purely a secret-handling call. Recommendation: add it
   when COV-40 starts, not now.
3. **DMARC stays at `p=none`.** Explicitly out of scope per the ticket, but it
   means no enforcement — a spoofer's mail is reported, not rejected. Worth its
   own ticket once real sending volume exists and the DMARC reports show
   legitimate sources are all aligned.

## More Info

- **Senders.** `Cove <notify@covehomeschool.com>` for notifications,
  `support@covehomeschool.com` for support. `fromEmail` on
  `POST /v1/email-messages/{id}` takes a **username only** — the team's domain
  is appended automatically — so both senders are expressible on the single
  verified domain. This is why Decision 1 costs nothing in sender flexibility.
- **Sending domain id:** `cms4sn00400kx0jwkndkwl204` (dashboard URL path, not a
  secret).
- **COV-37 dependency now resolvable.** COV-37 Decision 3 left `config/loops.yml`
  shaped conditionally on this ticket. Decision 2 answers it: use the
  **`shared:`** block, not per-environment blocks — one team means one set of
  `transactionalId`s across environments. Only the API key differs per
  environment, and that lives in credentials, not `config/loops.yml`.
- **Namecheap precedent:** `docs/designs/done/cov-32-provision-render-staging.md`
  §3 — Advanced DNS, plain subdomain records, no Cloudflare, no nameserver move.
- Production is not provisioned; `render.yaml`'s production block is commented
  out. Any per-environment split starts with an unused production half.
