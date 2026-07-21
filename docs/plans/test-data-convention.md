> Ticket: COV-24
> Branch: jrdnbwmn/cov-24-fixtures-test-convention

# Plan: Fixtures-only test-data convention

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Add `### Test data` subsection to `AGENTS.md` + confirm suite green | Master | |

## Prerequisites

- Design: `docs/designs/test-data-convention.md`
- Prototype: None
- Feature branch exists: `jrdnbwmn/cov-24-fixtures-test-convention` (already checked out)

## Tasks

### Task 1 [Master]: Document the fixtures-only test-data convention

**Skills:** none (documentation-only)
**Reference:** `AGENTS.md` lines 85–91 (`## Testing` section) — insert the new subsection immediately after line 91, before `## Routes Organization` (line 93). Match the existing bullet/bold style used in that file.

**In scope:**

- Add a `### Test data` subsection under the existing `## Testing` heading in `AGENTS.md`, containing the convention verbatim from the design doc's "Convention to document" section:
  - Fixtures-only (`test/fixtures/<table>.yml`, one file per new model).
  - No FactoryBot / Faker / new gems — raise as a product decision if a slice thinks it needs one.
  - Naming: generic `one`/`two` baselines plus intent-named labels (`subscribed`, `invited`, `admin`, `hidden`).
  - Associations by fixture label, never numeric IDs.
  - Literals by default; ERB only for computed values (timestamps, derived secrets) — not for fake/random data.
  - Signing in / switching accounts: reuse existing `sign_in(user)` (Devise) and `switch_account(account)` (`test_helper.rb` / `application_system_test_case.rb`).
- Run the full suite as a regression check and confirm it's green.

**NOT in scope:**

- Any new gem, factory library, or test helper (explicitly forbidden by the design).
- `db/seeds.rb` / dev-demo seed data (deferred to COV-25).
- Per-slice seed pattern (deferred to COV-26).
- Editing existing fixture files or tests — the existing fixtures are already the reference implementation.

**Build order:**

1. **Test:** No new test. This is a documentation-only change; the check is that the existing suite still passes (regression only, per Acceptance Criteria).
2. **Implement:** Insert the `### Test data` subsection into `AGENTS.md` after line 91.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test` — confirm green. Then `git diff` to confirm only `AGENTS.md` changed.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

## Task Dependencies

- Single task; no dependencies or parallelism.
