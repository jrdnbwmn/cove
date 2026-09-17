# What's Next

## Work completed and current state

Ticket `COV-72` is active on `feature/cov-72-family-accounts-two-parent-admins`. The approved plan is [docs/plans/cov-72-family-accounts-two-parent-admins.md](../docs/plans/cov-72-family-accounts-two-parent-admins.md).

- Tasks 1-24 are marked complete in the plan. This includes the family schema/migration, one-family fixtures and models, signup and OAuth linking, invitation acceptance, parent ownership guards, UI, receipts, Loops transactional email update, and architecture documentation.
- The working tree contains the complete uncommitted COV-72 implementation: 50+ modified files plus app-owned overrides, a migration, acceptance service, and tests. Do not discard or reset it.
- Local release gates passed on 2026-09-17 with mise Ruby 4.0.5: `bin/rails test` = 701 runs / 2,560 assertions / 0 failures; `bin/rails test:system` = 38 runs / 84 assertions / 0 failures; `bin/rubocop` and `git diff --check` were clean before this handoff.
- The Loops transactional `account-invite` message was updated and republished. A real verification send was delivered and confirmed rendered with a staging CTA. Do not resend unless a new rendering change requires it.
- Render pre-merge bootstrap verification succeeded on the COV-79 `main` commit: an unused staging bootstrap address was created and granted admin. Do not put that address in source, docs, or commits.
- Task 24 architecture diagrams and project decisions were updated. The user identified the repository `AGENTS.md` as the Cove project decision source; it has been edited directly.

## Work Remaining

1. Run `/prompts:review-changes` over the entire COV-72 branch. Review all uncommitted changes against the plan, run the full gates again, inspect `git diff origin/main...`, then commit the COV-72 work in logical commits.
2. Create a PR against `main`; Jordan reviews and merges it. Do not merge it yourself.
3. After merge, deploy the exact merged COV-72 SHA to Render staging. Confirm the SHA, then browser-smoke signup, Family settings, invitation blockers, parent removal, transfer, login-deletion guard, billing, and removed routes.
4. Staging database reset/re-provisioning is deferred. It requires exact merged-SHA deployment, successful bootstrap evidence, and Jordan's explicit destructive confirmation. No reset has been authorized.
5. Only after the post-merge staging work and browser evidence are complete, mark Task 25 complete and run `/prompts:close-out` after Jordan merges.

## Dead Ends

- The historic Loops value `cmsdr01rw02s00j3ozshehy4f` is a transactional ID, not an email-message ID. `loops email-messages get` returns not found. The correct CLI surface is `loops transactional get/send`; the Loops browser editor can edit the transactional record directly.
- Reusing an existing `BOOTSTRAP_ADMIN_EMAIL` only proves the idempotent found/already-admin path. Fresh creation proof requires an unused address that is first added to `STAGING_EMAIL_RECIPIENT_ALLOWLIST` and then configured as `BOOTSTRAP_ADMIN_EMAIL`.
- Render Free has no shell or one-off jobs. Verify configuration via observable deploy logs and behavior, not masked environment fields.
- Some earlier attempts stopped at partial checkpoints. Treat the plan table and the green full local release gates above as the current source of truth, then perform the full branch review before shipping.

## Open Questions

- Should the full branch review result in one commit or several logical commits? Preserve the project's one-logical-change-per-commit convention.
- Has Jordan reviewed the complete diff and approved PR creation? If not, do not create the PR.
- After merge and exact-SHA staging deployment, request explicit confirmation before any database reset.
