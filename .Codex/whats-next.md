# What's Next

## Work completed and current state

Ticket `COV-77` is active on `feature/cov-77-pricing-and-billing-pages-for-free-vs-premium`. The approved plan is [docs/plans/cov-77-pricing-and-billing-pages.md](../docs/plans/cov-77-pricing-and-billing-pages.md), with the design at [docs/designs/cov-77-pricing-and-billing-pages.md](../docs/designs/cov-77-pricing-and-billing-pages.md).

- Checkpoint 1 (Tasks 1-2) is committed as `b1dacce feature: add pricing presentation primitives`. It adds `app/helpers/pricing_helper.rb`, its helper test, PlanCard optional data/price overrides, component tests, previews, and the COV-77 locale contract. Full Rails verification passed: 765 runs, 2,867 assertions, 0 failures/errors.
- Checkpoint 2 implementation is present but uncommitted: Tasks 3-5 implement Free/Premium pricing states, the billing state partial, paid-only billing sections, fixed paid/canceled fixtures, no trial rendering, and no duplicate canceled-date warning. Relevant new files are `app/views/billing/_plan_state.html.erb` and `test/system/pricing_and_billing_system_test.rb`.
- Task 7 implementation is also present but uncommitted: it preserves both Family deletion controls, localizes Free/Premium deletion consequences, and distinguishes owner versus second-parent login deletion. Its new test is `test/integration/billing_policy_copy_test.rb`.
- Do not discard/reset current uncommitted COV-77 files. `git diff --check` passed.
- Latest full Rails suite passed after checkpoint 2: `PATH="/Users/jordan/.local/share/mise/shims:$PATH" bin/rails test` => 769 runs, 2,889 assertions, 0 failures/errors/skips.
- Focused green evidence: pricing integration tests; system-test filters for five pricing cases, three billing-state cases, and the second-parent case; subscription partial test (7 runs/27 assertions); policy-copy plus accounts-edit integration tests (6 runs/31 assertions).

## Work Remaining

1. Finish Task 6 with TDD. In `app/views/checkouts/show.html.erb`, remove both checkout trial branches while retaining standard authorization copy and render `pricing.show.no_refunds` below payment content, including the Stripe path outside its iframe. In `app/views/billing/subscriptions/cancels/show.html.erb`, use `@subscription.current_period_end` for dated cancellation/no-refund copy and `billing.subscriptions.cancels.show.active_until_no_refund_undated` when absent. Complete criteria 6-7 in `test/system/pricing_and_billing_system_test.rb`; stub Stripe creation in-process like `test/integration/checkouts_test.rb`. Do not test Stripe iframe content.
2. Finish Task 8. Apply the catalog and preview skills, updating only the `PlanCardComponent` entry in `docs/COMPONENT_CATALOG.md`, `docs/architecture/component-map.mermaid` only if required, the kitchen-sink trial sample in `app/views/dev/kitchen_sink/show.html.erb`, and `test/integration/dev/kitchen_sink_test.rb`.
3. Run checkpoint 3 mini review after Tasks 6-8. Inspect all changes against the plan, run full Rails/system/lint/whitespace/diff gates, then commit logical COV-77 changes. Do not merge or create a PR unless Jordan asks.
4. Final commands: `bin/rails test test/components/plan_card_component_test.rb test/integration/dev/kitchen_sink_test.rb`; `bin/rails test`; `bin/rails test:system`; `bin/rubocop`; `git diff --check && git diff --stat origin/main... && git diff origin/main...`. Prepend mise shims to every Rails/RuboCop command.

## Dead Ends

- `bin/rails test:system test/system/pricing_and_billing_system_test.rb` runs the whole system suite here. For one COV-77 test, use the positional file and `-i` with generated test name, e.g. `-i 'test_Free_family_sees_Free_as_its_current_plan_and_can_upgrade'`. Do not run Rails tests concurrently in this worktree; an earlier concurrent system run produced unrelated authentication failures and was terminated.
- Fixture timestamps must be midday UTC: midnight UTC displayed the prior local date. Current paid/canceled fixtures use `2026-10-15 12:00:00 UTC` and `2026-10-20 12:00:00 UTC`.
- In billing partials, `t(".key")` resolves under `billing.plan_state`; `_plan_state.html.erb` needs absolute `billing.show.*` translation keys.
- `ButtonComponent` with `href` renders an anchor, so system tests need `assert_link` for Change plan.

## Open Questions

- None. The plan is approved and the remaining tasks are fully specified.
