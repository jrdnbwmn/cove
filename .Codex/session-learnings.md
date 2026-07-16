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
