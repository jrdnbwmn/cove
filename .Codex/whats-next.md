# What's Next

## Work completed and current state

COV-17, “Component System Audit + Final Cleanup,” is complete on `jrdnbwmn/cov-17-review-components` (target: `origin/main`). The plan status tables in `docs/plans/component-system-audit-and-cleanup.md` and `docs/plans/cov-17-visual-qa-fixes.md` are fully complete. The branch contains the committed audit, visual-QA fixes, component catalog update, and all associated tests; wrap-up verification is in progress.

## Work Remaining

No planned COV-17 work remains. A separate reported checkbox/radio visual mismatch has been diagnosed but is not approved or implemented. It needs Jordan’s decision before any change because the proposed fix removes three competing global native-control rules:

1. Delete unused checkbox/radio, picker, switch, and toggle blocks from `app/assets/tailwind/components/forms.css`.
2. Delete the bare checkbox/radio rules from `app/assets/tailwind/rails_blocks/base.css`.
3. Change `CheckboxComponent` from `rounded` to `rounded-sm` in `app/components/checkbox_component.rb`.

If approved, add a focused regression test as needed, run `mise exec -- bin/rails tailwindcss:build`, visually check `/dev/kitchen_sink` and Lookbook, then run `mise exec -- bin/rails test`.

## Dead Ends

- Do not inspect Tailwind v4 cascade precedence through naive CSSOM rule traversal: nested style rules can be skipped. Search the compiled CSS text instead.
- Do not change the inert Jumpstart theme helper/model; COV-17 intentionally removed only the active dark-mode wiring.

## Open Questions

Should the separate checkbox/radio visual fix be approved and tracked as its own follow-up, or folded into this branch before review?
