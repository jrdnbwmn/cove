> Ticket: COV-67
> Branch: chore/cov-67-pre-launch-audit-loops-email
> As of: 2026-09-11

# Pre-launch audit of the Loops email system — findings

## Verdict

Launch-ready except for **4.4** (mail-job transient-network retries) and **4.6** (an owned terminal-failure alert). **2.4** and **3.4** are blocked on private-recipient access, not production. Production-only observations are deferred to COV-70.

## Method

Evidence is Observed (direct artifact/runtime), Tier B (staging), Inferred (source/config reasoning pending COV-70), or Decision. Verdicts are Pass, Fail, Blocked, and Decided. Secrets, private recipients, and raw message sources remain in `.context/`.

## Corrections to the ticket's stated premises

- Twelve templates and four Loops-backed mailer classes exist.
- COV-68 proved `account_created` twice on staging on 2026-09-09.
- Transactional 409 is duplicate success; 400, 413, and 422 fail fast.
- Persisted failures/Honeybadger attempts are not an owned exhaustion alert.

## 1. Configuration and credentials

| ID | Check | Verdict | Class | Evidence | Follow-up |
| -- | -- | -- | -- | -- | -- |
| 1.1 | Credentials | Pass | Observed | Production runner: API key and webhook secret present. | None |
| 1.2 | Production key | Pass | Observed | Suffix `af73` matched Loops `cove-production`; `cove-staging` and `cove-cli` also exist. | None |
| 1.3 | Mail runtime | Pass | Observed | Production boot: `:loops`, `covehomeschool.com`. | None |
| 1.4 | Delivery job | Pass | Observed | Production boot: `LoopsMailDeliveryJob`. | None |
| 1.5 | Staging allowlist | Pass | Observed | Render shows masked allowlist; dormant production has none. | None |
| 1.6 | Contact sync matrix | Pass | Inferred | Enabled only in production in `config/loops.yml`. | COV-70 live confirmation |
| 1.7 | Mailing list | Pass | Observed | Configured ID is public `Cove updates` in CLI and dashboard. | None |

## 2. Sender identity and deliverability

| ID | Check | Verdict | Class | Evidence | Follow-up |
| -- | -- | -- | -- | -- | -- |
| 2.1 | From/authentication | Pass | Tier B | Real Gmail header: `notify@mail.covehomeschool.com`; DKIM/SPF/DMARC pass. | None |
| 2.2 | DNS | Pass | Observed | Seven COV-38 records observed resolving on 2026-09-11. | None |
| 2.3 | DMARC policy | Decided | Decision | Add apex `p=none` reporting before launch; retain `mail.` `p=none` until report review. | DNS follow-up |
| 2.4 | Inbox placement | Blocked | Blocked-on-access | No private Gmail/Outlook/Apple recipient file; no send/mutation. | Supply addresses, allowlist, inspect one staging send |

## 3. Transactional templates

| ID | Check | Verdict | Class | Evidence | Follow-up |
| -- | -- | -- | -- | -- | -- |
| 3.1 | Published templates | Pass | Observed | Fresh CLI inventory matched all 12 configured IDs; no drafts. | None |
| 3.2 | Variable contracts | Pass | Observed | All app keys exactly match live LMX/dynamic fields. | Candidate regression ticket |
| 3.3 | Subject/preview | Pass | Observed | All live subjects/previews match completed designs. | None |
| 3.4 | Missing values | Blocked | Blocked-on-access | No approved preview recipient; zero previews sent. | Supply recipient and run 11-preview checklist |
| 3.5 | Audience/footer | Pass | Inferred / Tier B | Current LMX and prior real marketing/account-created evidence support intended split. | COV-70 production confirmation |
| 3.6 | `account_created` | Pass | Observed / Tier B | Fresh live inspection plus two COV-68 staging deliveries. | COV-70 production verification |

## 4. Delivery-path integrity

| ID | Check | Verdict | Class | Evidence | Follow-up |
| -- | -- | -- | -- | -- | -- |
| 4.1 | Headers/seeds | Pass | Observed | 12 actions carry common headers; seven Pay actions have idempotency seeds. | None |
| 4.2 | No ERB rendering | Pass | Observed | Empty bodies/tests prove no lookup; no app views/previews. | None |
| 4.3 | Fan-out idempotency | Pass | Observed | Normalized dedupe and recipient-specific keys verified. | None |
| 4.4 | Retry classes | Fail | Decision | Mail omits three transient network errors that lifecycle retries. | Add bounded mail network retries |
| 4.5 | Burst throttling | Decided | Decision | Accept at launch: 429 backoff exists; defer speculative throttle. | COV-70 telemetry |
| 4.6 | Terminal failures | Fail | Decision | No owned exhausted-mail alert; persisted records/Honeybadger insufficient. | Add terminal-failure alerting |
| 4.7 | Recurring pruning | Pass | Inferred | Dormant production worker configuration supports dispatch. | COV-70 live confirmation |
| 4.8 | Retention | Pass | Observed | 30-day retention exceeds Loops' 24-hour retry window. | None |

## 5. Repository hygiene and design drift

| ID | Check | Verdict | Class | Evidence | Follow-up |
| -- | -- | -- | -- | -- | -- |
| 5.1 | Repository gates | Pass | Observed | Rails, RuboCop, and ERB lint clean. | None |
| 5.2 | Dead subjects | Decided | Decision | Retain as historical documentation; Loops owns subjects. | None |
| 5.3 | AIDEV-NOTEs | Pass | Observed | 20 implementation/config and four test notes current. | None |
| 5.4 | Design drift | Pass | Observed | 18 done designs audited; active COV-37 wording corrected. | None |

## Decisions recorded

Mail retries need transient connection errors (4.4); a throttle is not justified before telemetry (4.5); terminal failures need an owned alert (4.6). Apex DMARC monitoring is pre-launch follow-up; stricter policy waits for volume. Retained i18n subjects remain documentation.

## Follow-up tickets

1. **Add bounded network retries to Loops mail delivery:** retry socket, connection-refused, and connection-reset only; preserve 409/400/413/422 boundaries and add focused tests.
2. **Alert on exhausted Loops transactional delivery:** create an operator-owned terminal-failure signal with template/error context and a retry-boundary runbook.
3. **Candidate — regression-test variable contracts:** version a reviewed non-network template contract fixture for twelve mailers.
4. **Add apex DMARC monitoring:** publish apex `p=none` reporting before launch; review subdomain reports before tightening policy.

## Inline fixes applied

`docs/designs/cov-37-loops-architecture.md` now records twelve triggers and the shipped receipt-PDF attachment. No behavior changed.

## Appendices

### Production runtime readback

`{delivery_method: :loops, default_url_options: {host: "covehomeschool.com"}, jumpstart_domain: "covehomeschool.com", delivery_job: "LoopsMailDeliveryJob"}`

### Sanitized Tier B Gmail headers

```
From: Cove <notify@mail.covehomeschool.com>
Return-Path: <…@envelope.mail.covehomeschool.com>
Authentication-Results: dkim=pass; spf=pass; dmarc=pass (p=NONE) header.from=mail.covehomeschool.com
```
