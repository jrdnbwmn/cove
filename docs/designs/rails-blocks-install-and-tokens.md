> Ticket: COV-11
> Branch: feature/cov-11-rails-blocks-install

# Feature: Install Rails Blocks Pro + default design tokens

## Problem
This fresh Jumpstart Pro app is about to grow a ViewComponent-based component
library built with Rails Blocks Pro. Before any components land, we need the
one-time Rails Blocks Pro base install done and a default design-token layer in
place — structured so rebranding later is a single-file edit. No shell/feature
rebuilding; just make Rails Blocks Pro work and read from our tokens.

## Approach
Lay down a shadcn-style token layer (neutral/monochrome default) as the single
source of truth, wire in only Rails Blocks' **foundational** Pro base CSS, and
prove it end-to-end with one free component (button) rendered in our palette in
Lookbook + the kitchen sink, light and dark.

Key decisions made during brainstorm:

1. **Override, not isolate.** Jumpstart already defines some of the same token
   names. The new RB token layer intentionally overrides them now; `_tokens.css`
   becomes the single source of truth. Tickets 4–6 migrate Jumpstart's own
   components off their hardcoded colors later.
2. **Editing `application.css`'s `@theme` is in scope.** The "don't remove
   Jumpstart component CSS yet" guard applies to component files, not the token
   layer.
3. **Foundational base CSS only (option 3b).** Rails Blocks' base guide also
   pulls CSS + CDN links for third-party widget libs (Tom Select, Air
   Datepicker, Shoelace, PhotoSwipe). Those belong to components landing in
   Ticket 3. This ticket installs only foundational base CSS — no CDN links, no
   dead widget CSS/JS, no per-component Stimulus registrations.

### Token / CSS file architecture

- **`app/assets/tailwind/theme/_tokens.css`** — single source of truth for the
  palette. Three blocks:
  - `:root { … }` raw light values: `--background`, `--foreground`, `--primary`,
    `--primary-foreground`, `--muted`, `--muted-foreground`, `--border`,
    `--ring`, `--radius` (values from the ticket snippet).
  - `.dark { … }` raw dark overrides. Uses the `.dark` **class** selector, which
    matches Jumpstart's actual dark-mode mechanism (see Dark mode below).
  - `@theme inline { … }` maps raw → Tailwind tokens (`--color-primary:
    var(--primary)`, `--color-background`, `--color-muted`,
    `--color-border`, `--color-ring`, `--radius`), generating `bg-primary`,
    `text-primary-foreground`, `bg-muted`, `border-border`, `ring-ring`, etc.
  - **Rebranding = edit `--primary` / `--primary-foreground` here only.**
- **`app/assets/tailwind/rails_blocks/base.css`** (new) — Rails Blocks'
  foundational Pro base CSS only (resets, form/input theming, scroll-area +
  toast utilities that use plain `--toast-*` / `--fade-*` custom props). No
  third-party widget theming, no CDN links. Kept separable; reads from our
  tokens. `@import`ed from `application.css`.
- **`app/assets/tailwind/application.css`** — two edits:
  1. Remove `--color-primary: var(--bg-primary)` from the top `@theme` (now
     owned by `_tokens.css`'s `@theme inline`).
  2. Add `@import "./rails_blocks/base.css"`.

**Why override works automatically:** `_tokens.css` is `@import`ed *unlayered*,
while `themes/light.css` / `themes/dark.css` sit in `layer(theme)`. Unlayered CSS
beats layered CSS in the cascade, so `_tokens.css`'s `--background` /
`--foreground` win over Jumpstart's without import-order gymnastics.

### Dark mode
Settled — no change needed. `app/javascript/controllers/theme_controller.js`
toggles the `.dark` **class** on `<html>`, and `application.css` declares
`@variant dark (&:where(.dark, .dark *))`. The ticket's `.dark { }` block is
correct as-written; no `[data-theme]` selector.

### Token collision analysis (why override is safe)
- `--background` (raw): Jumpstart light = white ≈ RB `oklch(1 0 0)` (identical);
  dark = gray-900 vs RB near-black `oklch(0.145 0 0)`. Only *visible* delta is
  the dark background going slightly truer-black. Accepted.
- `--color-primary` (@theme): Jumpstart = `var(--bg-primary)` (gray-950 light /
  white dark) ≈ RB `var(--primary)` (`oklch(0.205)` / `oklch(0.985)`).
  Visually near-identical; resolved by handing `--color-primary` to `--primary`.
- `--muted` / `--muted-foreground`: new names; no clash with Jumpstart's
  `--text-muted`.
- Jumpstart's `--bg-primary` / `--bg-secondary` families (consumed by
  `buttons.css` etc.) are untouched, so existing Jumpstart UI is unaffected apart
  from the dark-bg shift.

## Acceptance Criteria
- `rails-blocks doctor` passes; `rails-blocks whoami` shows `pro: true`
  (verify only — do not reinstall or re-login; if Pro is NOT active, stop and
  tell Jordan).
- Rails Blocks foundational Pro base CSS installed via a separable
  `rails_blocks/base.css`, `@import`ed from `application.css`; Tailwind build
  succeeds; **no CDN `<head>` links**.
- `_tokens.css` holds the default neutral/monochrome palette; base CSS + the
  smoke-test button read from tokens; dark mode uses Jumpstart's `.dark` class.
- Smoke-test button renders in `/lookbook` and `/dev/kitchen_sink` in **light
  and dark**, in our palette (`bg-primary` / `text-primary-foreground`, radius
  from `--radius`), and appears in the component catalog + component map as the
  first entry.
- Rebranding is demonstrably a single edit to `--primary` /
  `--primary-foreground` in `_tokens.css`.
- `bin/rails test` passes (show output). `git diff --stat` reviewed.

## Prototype
None. Visual default is the neutral/monochrome Rails Blocks look; it's a
placeholder Jordan will rebrand later.

## Data Model
N/A — CSS/asset + tooling ticket. No models, migrations, or routes.

## Screens / Flows
- **Lookbook preview** for the button component (light + dark) at `/lookbook`.
- **Kitchen sink** entry at `/dev/kitchen_sink` showing the button in our
  palette.
- No end-user-facing screens; this is infrastructure.

## Scope
**In:**
- Verify Rails Blocks CLI Pro access (no reinstall/login).
- `_tokens.css` default token layer (`:root` / `.dark` / `@theme inline`).
- New separable `rails_blocks/base.css` with foundational Pro base CSS only.
- `application.css` edits (drop `--color-primary` legacy line; import base CSS).
- `# AIDEV-NOTE` markers where Jumpstart component CSS hardcodes clashing colors
  (mark only — do not remove; Tickets 4–6 migrate).
- Install `button` as a ViewComponent (`--as view_component`, into
  `app/components/`, dry-run → approval → real), swap its accent to
  `bg-primary` / `text-primary-foreground`, radius from `--radius`.
- Lookbook preview + kitchen-sink entry for the button; run `update-catalog`
  and `update-component-previews`.
- `bin/rails test`; commit `feature: install Rails Blocks Pro and default design
  tokens`.

**Deferred:**
- Migrating Jumpstart's own component CSS off hardcoded colors (Tickets 4–6).
- Third-party widget libs and their CSS/JS + Stimulus registrations
  (Tom Select, Air Datepicker, Shoelace, PhotoSwipe) — ride in with their
  components in Ticket 3.
- Any per-component JS deps / importmap pins beyond the base install.
- Actual rebrand of `--primary` (Jordan does this later).

## Open Questions
None blocking. Two minor items to resolve at implementation and record as
`# AIDEV-NOTE`:
- **Radius wiring:** `--radius` alone won't affect Jumpstart's `--radius-lg`
  rounding. Make the smoke-test button consume `rounded-[var(--radius)]` (or map
  the Tailwind radius scale off `--radius`) so it demonstrably reads the token.
- **`controllers/index.js`:** already satisfies the RB guide
  (`eagerLoadControllersFrom` + explicit `tailwindcss-stimulus-components`
  registrations). Preserve as-is; expect no change.

## More Info
- **Tooling:** Use the `rails-blocks-cli` skill for ALL Rails Blocks operations.
  Do NOT use the Rails Blocks MCP — it's non-functional for this repo (scoped to
  the parent dir, binary not on PATH, placeholder token). CLI is v0.1.4, already
  authenticated Pro.
- **Standing hygiene rules** for all Rails Blocks installs: (1) self-host assets,
  never add CDN `<head>` links — vendor/importmap-pin everything; (2) lazy-load
  Stimulus — register a controller only because its component is installed and
  used; (3) route primary accents through tokens (`bg-primary` /
  `text-primary-foreground`, not hardcoded `bg-neutral-900`); (4) never `--force`
  over a Jumpstart controller without approval.
- **Build:** Tailwind v4 CSS-first via `@theme`; source in
  `app/assets/tailwind/`, build at `app/assets/builds/tailwind.css`. Never create
  `tailwind.config.js`.
- **Install discipline:** always `--dry-run` first and show files before writing;
  never `--force` without approval; install `--as view_component` into
  `app/components/`.

### Default token values (from ticket)
```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);            /* the accent — change to rebrand */
  --primary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --border: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
  --radius: 0.625rem;
}
.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --primary: oklch(0.985 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --border: oklch(0.269 0 0);
  --ring: oklch(0.556 0 0);
}
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-border: var(--border);
  --color-ring: var(--ring);
  --radius: var(--radius);
}
```
