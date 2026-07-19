@AGENTS.md

## Current Project Decisions

- Dark mode is intentionally disabled. Keep the inert Tailwind `@variant dark`
  declaration so existing `dark:` utilities stay inactive; do not restore theme
  wiring or a system-preference fallback without an explicit product decision.
