> Plan created: docs/plans/cov-36-migrate-jumpstart-component-css.md
> Ticket: COV-36
> Branch: chore/cov-36-migrate-jumpstart-component-css

# Feature: Migrate legacy Jumpstart component CSS onto the `_tokens.css` palette

## Problem

COV-11 installed Rails Blocks' token layer (`app/assets/tailwind/theme/_tokens.css`)
as the intended single source of truth for theming, but deferred migrating
Jumpstart's own component CSS off its older token family (`--bg-primary`,
`--text-on-primary`, `--text-primary`, `--border-primary` and their `-hover`
variants). Twelve component stylesheets still read that older family, so
rebranding by editing `--primary` would restyle only Rails Blocks components —
the opposite of what COV-11 set out to achieve.

## Approach

Replace all **54 legacy token references** across the 12 flagged stylesheets with
`_tokens.css` equivalents, mapping each reference by **what the rule actually
does**, not by the token's name. Delete each file's `AIDEV-NOTE` as it is
migrated.

### Why mapping by name would be wrong

The legacy "primary" family resolves to Tailwind's neutral scale, and the names
lie about intent:

| Legacy token | Resolves to | Mapped to | Same value today? |
|---|---|---|---|
| `--bg-primary` / `--text-primary` / `--border-primary` | neutral-950 `oklch(0.145)` | `--primary` `oklch(0.205)` | No — one step lighter |
| `--text-on-primary` | `white` | `--primary-foreground` `oklch(0.985)` | Near-exact |
| `--bg/text/border-primary-hover` | neutral-800 `oklch(0.269)` | *(see below)* | No equivalent exists |

Two traps confirmed by reading every call site:

1. **Only 7 of the 20 `-hover` references are hover states.** Jumpstart reached
   for the lighter shade whenever it wanted "brand, but softer" — so
   `--border-primary-hover` is the *focus* ring on every form control, the
   *active* tab underline, and the *resting* border on outline buttons and
   pills. `.pill-primary` even uses `--bg-primary-hover` as its resting
   background.
2. **`--text-primary` is pixel-identical to `--foreground` today** (both
   neutral-950). Some sites mean "brand text" and some just mean "dark text";
   only reading the selector distinguishes them.

### Decisions

**1. Rewrite the references; do not alias.** The alternative — re-pointing the
legacy names in `themes/light.css` to `var(--primary)` — is a 7-line edit with
near-zero regression risk, but it keeps two naming families alive and leaves the
next reader following a two-hop trail out of `buttons.css`. That quietly
re-creates the problem COV-11 set out to solve. Rejected in favour of the real
migration.

**2. Hover shade = `color-mix`, no new token.** True hover states become
`color-mix(in oklab, var(--primary) 90%, transparent)`. This is exactly what
Tailwind v4 compiles `bg-primary/90` to and what shadcn/Rails Blocks use, it
adds no tokens, and it keeps rebranding a single edit to `--primary`. Adding a
literal `--primary-hover` token was rejected because it would make rebranding
three edits instead of one, breaking COV-11's core promise.

Direction is preserved: legacy resting `oklch(0.145)` → hover `oklch(0.269)` was
*lighter*; `--primary` at 90% alpha over the page background is also lighter.

**3. Form focus rings map to `--primary`, not `--ring`.** `--ring` is the
semantically obvious choice but resolves to `oklch(0.708)`, a light grey —
roughly 2.5:1 against white, below the 3:1 that WCAG 2.4.11 expects for focus
indicators, and a visible regression from today's near-black. It also would not
rebrand, and rebranding forms is an explicit acceptance criterion. `--primary`
stays dark today and rebrands tomorrow.

**Consequence to accept deliberately:** this makes `--primary` load-bearing for
accessibility. Add an `AIDEV-NOTE` in `_tokens.css` recording that `--primary`
must stay at least 3:1 against white, so a future pastel rebrand doesn't
silently break focus visibility.

**4. Alerts are the one justified exception.** `alert.css:51` (`li`) is body copy
inside a container that already carries a semantic colour; brand-coloured bullet
text inside a red danger alert is actively wrong. It maps to `--foreground` — a
pixel-identical no-op — with an `AIDEV-NOTE` explaining why. Since line 51 is the
file's only primary-family reference, `alert.css` ends up with zero `--primary`
references and **does not rebrand**. The ticket's acceptance criterion naming
alerts as a surface that must visibly restyle is wrong on this point and has
been corrected below.

**5. Semantic danger/success/warning/info tokens are out of scope.** They are a
separate family (`--bg-danger`, `--text-on-success-secondary`, …), none of the
54 references touch them, and they should *not* follow `--primary` — red should
stay red. Extending `_tokens.css` to cover them is a separate ticket if wanted.

**6. Dark mode verification is dropped.** The ticket asks for light + dark
spot-checks, but dark mode is intentionally disabled, `themes/dark.css` is gone,
and `_tokens.css` no longer carries a `.dark` block. Verification is light-only;
the check is that the inert `dark:` utilities stay inert.

### Two styling judgments Jordan ruled on

- **`buttons.css:256`** — `.btn-link.btn-icon`'s 1px border (currently near-black)
  maps to **`--border`**, not `--primary`. A brand-coloured outline on every icon
  button is too loud. This is a visible change today: near-black → `oklch(0.922)`.
- **`buttons.css:251`** — `.btn-link:disabled:hover` maps to **`--foreground`**.
  A disabled control taking the brand colour is wrong; `--foreground` is
  pixel-identical today and doesn't rebrand. Not "fixed" to a muted colour —
  that's out of scope.

## Complete reference map (54 sites)

`MIX` = `color-mix(in oklab, var(--primary) 90%, transparent)`

| File | Lines | Context | → |
|---|---|---|---|
| `top_nav.css` | 136, 143 | active item bar / underline | `--primary` |
| | 137 | active item text | `--primary` |
| `nav.css` | 163, 373 | active item `::before` bar | `--primary` |
| | 188, 191, 466 | active link + icon text | `--primary` |
| | 216 | `.cta-btn` background | `--primary` |
| | 217 | `.cta-btn` text | `--primary-foreground` |
| `forms.css` | 31, 32 | `.form-control:focus` ring + border | `--primary` |
| | 74, 75 | `select:focus` ring + border | `--primary` |
| | 97, 98 | `select[multiple]:focus` ring + border | `--primary` |
| | 280, 356 | checked radio / toggle background | `--primary` |
| `tabs.css` | 43, 54 | active underline / focus border (resting) | `--primary` |
| | 44, 55 | active text | `--primary` |
| | 47, 48 | active `:hover` text + underline | `MIX` |
| `pagination.css` | 20 | link text | `--primary` |
| | 30 | link `:hover` text | `MIX` |
| | 40, 41 | current page background + border | `--primary` |
| | 42 | current page text | `--primary-foreground` |
| `buttons.css` | 141, 150 | `.btn-primary` bg (resting, disabled) | `--primary` |
| | 142, 146, 151, 161 | `.btn-primary` text | `--primary-foreground` |
| | 145, 160, 162 | `:hover` bg + border | `MIX` |
| | 156, 157 | `.btn-outline` text + border | `--primary` |
| | 251 | `.btn-link:disabled:hover` text | `--foreground` |
| | 256 | `.btn-link.btn-icon` border | `--border` |
| `pills.css` | 24, 29, 30 | `.pill-primary` bg, outline border + text | `--primary` |
| | 25 | `.pill-primary` text | `--primary-foreground` |
| `wells.css` | 27 | link text | `--primary` |
| `alert.css` | 51 | `li` body copy | `--foreground` |
| `notifications.css` | 15 | background | `--primary` |
| `typography.css` | 53 | `.link` text | `--primary` |
| | 59 | `.link:hover/:focus` text | `MIX` |
| `docs.css` | 63, 69 | sidebar hover + active text | `--primary` |
| | 68 | sidebar active left bar | `--primary` |

## Verification

**The ticket points at the wrong surface.** These 12 stylesheets style Jumpstart
*engine* views (`lib/jumpstart/app/views/`, 36 files use `btn-primary` alone).
The app's own views use almost none of these classes, and there are no Lookbook
previews for them — so Lookbook and `/dev/kitchen_sink` cannot verify this work.

Jumpstart ships its own component gallery at **`/jumpstart/docs/*`** (dev-only,
mounted in `config/routes/jumpstart.rb`), with a page per stylesheet:

| Stylesheet | Verify at |
|---|---|
| `buttons.css` | `/jumpstart/docs/buttons` |
| `pills.css` | `/jumpstart/docs/pills` |
| `wells.css` | `/jumpstart/docs/wells` |
| `tabs.css` | `/jumpstart/docs/tabs` |
| `pagination.css` | `/jumpstart/docs/pagination` |
| `alert.css` | `/jumpstart/docs/alerts` |
| `forms.css` | `/jumpstart/docs/forms` |
| `typography.css` | `/jumpstart/docs/typography` |
| `nav.css`, `top_nav.css` | `/jumpstart/docs/navigation` |
| `notifications.css` | `/jumpstart/docs/notifications` |
| `docs.css` | any `/jumpstart/docs/*` page — it styles the gallery's own chrome |

Per AGENTS.md, screenshot these with a real Rails/Puma server plus a browser —
`ApplicationController.render` can't render authenticated views.

**Rebrand proof:** temporarily set `--primary` to a saturated colour in
`_tokens.css`, confirm all 11 surfaces above visibly change (alerts excepted, by
decision 4), then revert.

### Known risk to check during implementation

`rails_blocks/base.css` is imported *after* `components/forms.css` in the same
`layer(components)` and defines `.form-control` with `focus:ring-2
focus:ring-neutral-600`. At equal specificity the later import wins, so
`forms.css:31–32` may already be dead for `.form-control` — meaning the change
there could be a visual no-op. Verify empirically at `/jumpstart/docs/forms`
rather than assuming; if the rules are dead, note it but don't start deleting
them (out of scope).

## Data Model

N/A — CSS-only ticket. No models, migrations, routes, or Ruby changes.

## Screens / Flows

No end-user-facing changes. The intended visible deltas are:

- Primary buttons, pills, active nav/tab/pagination states shift from
  `oklch(0.145)` to `oklch(0.205)` — one step lighter, near-imperceptible, and
  the alignment COV-11 anticipated.
- `.btn-link.btn-icon`'s border lightens from near-black to `oklch(0.922)`
  (deliberate — decision above).
- Everything else is pixel-identical until `--primary` is edited.

## Scope

**In:**
- The 12 flagged stylesheets; all 54 references remapped per the table.
- Removing the 12 `AIDEV-NOTE`s about this deferred work.
- **Deleting the seven now-dead legacy primary tokens** from `themes/light.css`:
  `--bg-primary`, `--bg-primary-hover`, `--text-on-primary`, `--border-primary`,
  `--border-primary-hover`, `--text-primary`, `--text-primary-hover`. After the
  migration these have zero consumers (verified by grep across `app/` and
  `lib/`). Leaving dead token definitions is the same ambiguity this ticket
  removes. Re-run the grep as the final check before commit — it must return
  nothing, and note that `--base-border-primary` is a *different* token that
  stays.
- Two new `AIDEV-NOTE`s: the `--primary` contrast floor in `_tokens.css`, and
  the alert-exception rationale in `alert.css`.
- Light-only visual verification across the 11 `/jumpstart/docs` surfaces plus
  the temporary-rebrand proof.
- `bin/rails test` and `bin/rubocop`; `git diff --stat` reviewed before commit.

**Deferred:**
- Any actual rebrand — still a single edit to `--primary` /
  `--primary-foreground` after this lands.
- Semantic danger/success/warning/info tokens (decision 5).
- The `--base-*`, `--bg-disabled`, `--divider-color` families — untouched.
- Third-party widget CSS; any component without the `AIDEV-NOTE`.
- Deleting dead `.form-control:focus` rules if the known risk above confirms
  they're overridden.

## Open Questions

None.
