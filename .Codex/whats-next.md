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
- Task 6 verified that neither legacy navigation stylesheet is orphaned, so neither was deleted: `nav.css` is still used by `SidebarComponent` and Jumpstart menu partials; `top_nav.css` is still used by the engine navbar, native navbar, minimal layout, and documentation header. `mise exec -- bin/rails tailwindcss:build` and `mise exec -- bin/rails test` both passed (312 runs, 747 assertions).

The approved plan is [docs/plans/component-system-audit-and-cleanup.md](../docs/plans/component-system-audit-and-cleanup.md). Its Status table is the source of truth.

## Work Remaining

Resume at Tasks 7a, 7b, and 7c, then follow the plan in order:

1. **Tasks 7a, 7b, and 7c (Clone):** delegate these disjoint color-audit clusters as the plan directs. Apply only the specified semantic-token mapping; leave ambiguous colors and all `dark:` utilities untouched. Each clone must run the full Rails test suite and complete its task-level review.
2. Mark each finished plan row with `✅`, review the combined branch changes, and keep the user’s requested pause boundaries.

Before resuming in a fresh session, run the execute-plan preflight from this workspace: `git status --porcelain`, `mise exec -- bin/rails db:migrate:status`, and `mise exec -- bin/rails test`.

## Dead Ends

- The Braintree stylesheet’s first dark-mode selector also included the light `.braintree-heading` selector. Preserve that heading rule when removing dark rules; deleting the whole selector would be scope creep.
- A registration test defined on the outer test class is inherited by each nested class. Keep the theme-picker regression test in its dedicated `ThemePickerTest` nested class so it runs once.
- Do not modify `lib/jumpstart/app/helpers/theme_helper.rb` or `lib/jumpstart/app/models/user/theme.rb`; the plan intentionally leaves them inert.

## Open Questions

None. The plan can resume at Task 6.
