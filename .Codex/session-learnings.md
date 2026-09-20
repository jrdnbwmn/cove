## Catchup 2026-09-17

### Friction

Checkpoint boundaries were not respected consistently early in execution, which made release status difficult to read.

### Mistakes

Several earlier handoffs claimed partial progress before the checkpoint's full focused suite was green. The next agent should use the plan status plus current test evidence, not those partial claims.

### Observations

The COV-72 migration intentionally changes global family assumptions. Updating stale test helpers and fixtures to single-family semantics was necessary before the full suite could pass. Render bootstrap proof requires an unused allowlisted address and observable `created` plus `granted admin` logs.

## Catchup 2026-09-19

### Friction

The source-command handoff file was stale COV-72 content and needed a full COV-77 replacement.

### Mistakes

Running system tests concurrently with another Rails test process caused unrelated browser/authentication failures. Keep Rails tests sequential in this linked worktree.

### Observations

For focused system coverage, use the positional test file plus `-i` with the generated test method name. Local browser date assertions require noon UTC fixture timestamps to avoid a timezone day shift.
