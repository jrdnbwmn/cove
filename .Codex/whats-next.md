# What's Next

## Work completed and current state

COV-17, “Component System Audit + Final Cleanup,” is active on `jrdnbwmn/cov-17-review-components` (target: `origin/main`). Tasks 1–5 are complete, reviewed, committed, and the workspace was clean before this handoff.

- `a32ee7d` — Tasks 1–3: secure `target: "_blank"` support in `ButtonComponent`, the app-level homepage shadow with ButtonComponent CTAs, and removal of the layout/head/theme-controller dark-mode wiring.
- `82bdfee` — Tasks 4a–5: removal of dark-mode tokens and component CSS selectors; retention of the intentional inert `@variant dark`; removal of the profile theme picker; tokenization of the avatar file-input colors.

Latest verification:

- `mise exec -- bin/rails tailwindcss:build` passed.
- `grep -rn '\.dark' app/assets/tailwind` reports only the intentionally retained `@variant dark` line in `app/assets/tailwind/application.css`.
- `mise exec -- bin/rails test test/controllers/users/registrations_controller_test.rb` — 6 runs, 20 assertions, 0 failures.
- `mise exec -- bin/rails test` — 312 runs, 747 assertions, 0 failures.
- Targeted RuboCop and `git diff --check` passed before the latest commit.

The approved plan is [docs/plans/component-system-audit-and-cleanup.md](../docs/plans/component-system-audit-and-cleanup.md). Its Status table is the source of truth.

## Work Remaining

Resume at Task 6, then follow the plan in order:

1. **Task 6 (Master):** inspect every selector defined in `app/assets/tailwind/components/nav.css` and `app/assets/tailwind/components/top_nav.css` with searches across `app/views`, `app/components`, `lib`, and JavaScript. Delete a file and its import from `app/assets/tailwind/application.css` only if every selector is unreferenced. Do not refactor a still-used selector; record what blocks deletion. Verify with `mise exec -- bin/rails tailwindcss:build` and `mise exec -- bin/rails test`, then run the required review.
2. **Tasks 7a, 7b, and 7c (Clone):** delegate these disjoint color-audit clusters as the plan directs. Apply only the specified semantic-token mapping; leave ambiguous colors and all `dark:` utilities untouched. Each clone must run the full Rails test suite and complete its task-level review.
3. Mark each finished plan row with `✅`, review the combined branch changes, and keep the user’s requested pause boundaries.

Before resuming in a fresh session, run the execute-plan preflight from this workspace: `git status --porcelain`, `mise exec -- bin/rails db:migrate:status`, and `mise exec -- bin/rails test`.

## Dead Ends

- The Braintree stylesheet’s first dark-mode selector also included the light `.braintree-heading` selector. Preserve that heading rule when removing dark rules; deleting the whole selector would be scope creep.
- A registration test defined on the outer test class is inherited by each nested class. Keep the theme-picker regression test in its dedicated `ThemePickerTest` nested class so it runs once.
- Do not modify `lib/jumpstart/app/helpers/theme_helper.rb` or `lib/jumpstart/app/models/user/theme.rb`; the plan intentionally leaves them inert.

## Open Questions

None. The plan can resume at Task 6.
