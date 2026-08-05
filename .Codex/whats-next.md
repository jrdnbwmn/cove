# What's Next

## Work completed and current state

Ticket `COV-47` is active on branch `feature/cov-47-e2e-transactional-email-verification`.

- The approved implementation plan is [docs/plans/cov-47-loops-verification.md](../docs/plans/cov-47-loops-verification.md). The Render Free-tier bridge addendum is [docs/plans/cov-47-free-tier-verification-bridge.md](../docs/plans/cov-47-free-tier-verification-bridge.md).
- The temporary, staging-only authenticated verification bridge is committed and pushed in `0c6a49b` (`app/controllers/staging/verification_controller.rb`, staging route block, and integration tests). Its focused tests passed (12 runs / 62 assertions), the full Rails suite passed (585 runs / 2165 assertions), and RuboCop passed (490 files, no offenses). The checkpoint-1 mini review passed.
- Bridge status was successfully verified in staging: Loops delivery and `perform_deliveries` are enabled; the operator and both controlled recipients are allowlisted; the verification account billing email is `hello@covehomeschool.com`; five pre-existing `@cove.test` records remain non-allowlisted and were deliberately left untouched. No email was sent to them.
- Render configuration requires a manually selected commit deploy. `cove-staging` was most recently deployed with `124dbef` (`chore: update staging Stripe webhook secret`), and Render reported the service live. This commit changes only the encrypted `config/credentials/staging.yml.enc` file; the plaintext secret must never be displayed or committed.
- In Stripe test mode, a webhook destination named `COV-47 staging verification` was created for `https://staging.covehomeschool.com/webhooks/stripe`, listening to exactly: `charge.succeeded`, `charge.refunded`, `invoice.payment_failed`, `invoice.payment_action_required`, `customer.subscription.updated`, and `customer.subscription.deleted`. Its signing secret was placed into staging credentials before `124dbef` was committed and deployed. The endpoint signature/delivery test is still outstanding.
- A staging verification user exists and is signed in through the staging UI. Its controlled login is `jordan.d.bowman@gmail.com`; its controlled billing recipient is `hello@covehomeschool.com`. Do not put either address into source, plan docs, screenshots, or commits.
- Working tree was clean immediately after `124dbef`; this handoff introduces the only new draft files, `.Codex/whats-next.md` and `.Codex/session-learnings.md`.

## Work Remaining

1. Resume at original-plan Task 2 / bridge-addendum Task 4. In Stripe test mode, use the new destination's **Send test events** flow to send one selected event and confirm staging accepts the signed delivery (HTTP success). Do not expose the signing secret. If it fails, stop before checkout and investigate credentials/deployment.
2. Create exactly one Stripe **test-mode** product with a recurring yearly $99 price. Use the bridge `POST /staging/verification/create_plan` with its `price_...` id, then confirm the plan appears on staging pricing. Do not create a second plan or alter existing plans.
3. Follow original-plan Tasks 5-12 strictly in order: checkout with the real staging UI; record the successful-charge timestamp and Stripe event ID; cancel immediately to start the one-hour survey timer; refund; test failed-payment and abandoned-3DS paths; invoke the three Tier-B bridge actions; run reset/change, invitation, cancellation fallback only if needed, webhook replay within 24 hours, and bridge enqueue-failure/Honeybadger verification.
4. For every send, inspect both controlled inboxes, record delivery placement, attachment/link behavior, Stripe IDs/timestamps, Loops data, and Honeybadger evidence in `docs/designs/cov-47-loops-verification.md`. Never invent a result; use a reason for any unperformed check.
5. Run the addendum's checkpoint-2 `review-changes-mini` only after original Tasks 4-12 are complete. Complete Loops dashboard auditing, results tables, database cleanup via the bridge, and Stripe product archival according to Task 5.
6. Execute mandatory addendum Task 6: remove the bridge controller/routes/tests and any bridge-only configuration references, commit and push removal separately, deploy removal to staging, prove bridge routes return `404`, return Render to linked `main` with auto-deploy enabled, and remove only the temporary operator variable (keep the standing recipient allowlist). Then run the complete test/lint/diff checks and checkpoint-3 review. The final branch should retain only the completed COV-47 design document, per the addendum.

## Dead Ends

- Render Free services do not provide Shell or One-Off Jobs. Do not attempt to use `bin/rails console` there; use the fixed-purpose bridge actions from the addendum.
- Render environment values are masked in the editor. The recipient allowlist was not applied on an early save attempt; verify it through bridge `status`, not through the masked UI. The proven live status has `non_allowlisted_count: 5` (only stale test records), not 6.
- This worktree does not have `config/credentials/staging.key`; the initial credentials edit used a mismatched/default key and failed with `AEAD authentication tag verification failed`. The user supplied the existing `cove-staging` `RAILS_MASTER_KEY` interactively, then updated the encrypted file. Do not retry credentials editing without the matching staging key.
- Specific-commit Render deploys are manual and disable normal auto-deploy behavior. Record and reverse that setting during addendum Task 6.
- A browser attempt to open Stripe was once interrupted while tabs were being moved. Reconnect to the existing Chrome session if available; otherwise use the Stripe test dashboard directly. No Stripe test event has yet been sent.

## Open Questions

- Does Stripe's first signed test delivery reach staging successfully with the newly configured credential? This must be proven before any subscription checkout.
- What are the actual results of the eleven real sends, links, attachment rendering, webhook replay, Loops dashboard audit, and Honeybadger error? None have been recorded yet.
- Should the verification user and its Stripe test subscriptions be retained after cleanup? Record the decision in the design document as required by the plan.
