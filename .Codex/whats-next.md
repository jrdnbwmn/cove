# What's Next

## Work completed and current state

COV-15, “Rebuild account + billing (Pay) views with design-system components,” is active on `feature/cov-15-rebuild-billing-views` (target: `origin/main`). Tasks 1–10 of 14 are complete, reviewed, and committed. The worktree is clean.

- `79e9d3f` — Task 1: `PlanCardComponent`, previews, component coverage, catalog, and map.
- `df1d5d0` and `567f1ad` — Tasks 2–3: password and API-token shadows; clipboard and Turbo revoke behavior remain intact.
- `01042c0`, `73ab5e8`, `6d88a6d`, and `4a46a67` — Tasks 4–7: account, roster, transfer, member, and invitation shadows. Role forms include hidden `"0"` inputs before `CheckboxComponent` so unchecked Rails params remain unchanged; the user explicitly approved this.
- `86665b0` — Task 8: pricing uses `PlanCardComponent` for both plan lists, preserving toggle/action wiring. With user approval, `PricingHelper` uses explicit existing `billing.subscriptions.plan.*` keys because component rendering no longer has the old `_plan` lazy-i18n scope. `test/integration/plans_test.rb` covers the action label.
- `b94d88a` — Task 9: checkout/testimonial shadows and byte-identical app-level Stripe form. `cmp -s` confirmed it matches the engine source.
- `b5df1ea` — Task 10: billing show/email/info/charges shadows; non-admin guard, toggle wiring, account params, and PDF routes are preserved.

Latest verification after Task 10:

- `mise exec -- bin/rails test` — 289 runs, 631 assertions, 0 failures.
- `mise exec -- bin/rubocop` — 432 files inspected, no offenses.
- `git diff --check` passed.

The approved plan is [docs/plans/rebuild-billing-views.md](../docs/plans/rebuild-billing-views.md). The saved design is [docs/designs/rebuild-billing-views.md](../docs/designs/rebuild-billing-views.md).

## Work Remaining

Resume at Task 11 (Master), then follow the plan in order:

1. Create app-level shadows for `app/views/billing/subscriptions/_subscription.html.erb`, `_summary.html.erb`, and `edit.html.erb`. This is the highest-risk task: preserve each state branch/action. Migrate edit's monthly/yearly loops to `PlanCardComponent` like Task 8, retaining the PATCH form, hidden `plan` (`plan.to_param`), and Turbo confirmation. Confirm all four known `_plan` callers (two pricing, two subscription edit) use the component; only add an app-level shim if another caller remains.
2. Task 12 (Clone): subscription cancel/resume/pause/upcoming pages; preserve every `button_to` method and Turbo confirmation.
3. Task 13 (Master): payment-method new/fake-processor shadows. Preserve fake-processor form behavior and record every system-test selector needing migration from `input[name=commit]` to `button[type=submit]` for Task 14.
4. Task 14 (Master, last): selector migration, integration/system coverage, browser walkthrough, then full `mise exec -- bin/rails test` and `mise exec -- bin/rails test:system` gates.

Global constraints: create only app-level view shadows except for the approved `PricingHelper` compatibility fix; otherwise leave `lib/jumpstart/` pristine. Run Rails/bin commands through `mise exec --`. Preserve routes, params, meta/sidebar content, Pundit/config guards, Turbo data, Stimulus attributes, and Pagy conditions exactly.

## Dead Ends

- Rendering `pricing_link_to(plan)` inside `PlanCardComponent` first failed with `Translation missing: en.pricing.show.get_started`: the old layout partial supplied a billing-plan lazy-i18n scope. The user approved explicit existing keys in `PricingHelper`; do not revert this.
- `CheckboxComponent` lacks Rails’ hidden unchecked value. Keep a hidden `"0"` input immediately before each role checkbox.
- Do not run RuboCop directly on ERB paths; use the project-wide command. Direct `ApplicationController.render` of authenticated templates lacks Devise/Warden context. This checkout also requires `mise exec --`.

## Open Questions

None. The approved plan can resume at Task 11.
