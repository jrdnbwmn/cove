## Catchup 2026-07-16

### Friction

The original B1 plan mapped the `forms` slug to components that Rails Blocks
does not provide. The revised plan correctly models it as one wrapper.

### Mistakes

The first B1 attempt had to stop at dry-run because the original component
mapping was inaccurate. Preview aggregation via `inline_template` also does
not work for this ViewComponent preview API; use one preview method per state.

### Observations

For this workspace, run Rails commands through `mise exec --`. The browser
runtime may initialize with no browser backends available, so inspect
`agent.browsers.list()` once and record the limitation rather than falling back
to a separate automation path. Rails Blocks' `forms` CSS is already imported
after Jumpstart's forms CSS, so its `.form-control` rules take precedence.

## Catchup 2026-07-16 (B2)

### Friction

The active context was nearing its limit while the second plan batch reached
its review boundary, so B2 was completed and committed before pausing for a
fresh-session handoff.

### Mistakes

The first attempted `importmap pin` command used a `--download` flag that this
project's importmap CLI does not support. The plain pin command works, but its
initial downloaded tom-select entry was not self-contained; use the verified
local ESM bundle described in `.Codex/whats-next.md`.

### Observations

For Rails Blocks batches, write minimal flat-component tests first, prove RED,
then install and normalize. Preview tests can provide a second RED/GREEN cycle.
The generated component source needed RuboCop auto-formatting after namespace
removal, and its inline HTML styles must be removed to comply with this repo's
ViewComponent rules.
