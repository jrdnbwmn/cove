> Ticket: COV-36
> Branch: chore/cov-36-migrate-jumpstart-component-css

# Plan: Migrate legacy Jumpstart component CSS onto the `_tokens.css` palette

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Guard test + migrate `buttons.css`, `pills.css` (sets the MIX pattern) | Master | |
| 2 | 1 | 2 | Migrate `forms.css`, `tabs.css` | Clone | |
| 3 | 1 | 2 | Migrate `nav.css`, `top_nav.css`, `docs.css` | Clone | |
| 4 | 1 | 3 | Migrate `pagination.css`, `typography.css`, `wells.css`, `notifications.css` | Clone | |
| 5 | 1 | 3 | Migrate `alert.css` (the documented exception) | Clone | |
| 6 | 2 | 4 | Delete 7 dead tokens from `light.css`; contrast-floor note in `_tokens.css` | Master | |
| 7 | 2 | 4 | Visual verification across `/jumpstart/docs` + rebrand proof | Master | |

## Prerequisites

- Design: `docs/designs/cov-36-migrate-jumpstart-component-css.md`
- Prototype: None (CSS-only, no new UI)
- Feature branch exists: `chore/cov-36-migrate-jumpstart-component-css`
- No new components needed — catalog scanned, this touches legacy Jumpstart engine
  stylesheets only, not `app/components/`

**Shared constants every task uses:**

| Shorthand | Literal replacement |
| --- | --- |
| `PRIMARY` | `var(--primary)` |
| `ON-PRIMARY` | `var(--primary-foreground)` |
| `MIX` | `color-mix(in oklab, var(--primary) 90%, transparent)` |
| `FG` | `var(--foreground)` |
| `BORDER` | `var(--border)` |

**Rules that apply to every migration task (1–5):**

- Make edits by **literal string match with surrounding selector context**, not by
  line number. Line numbers below are pre-edit navigation aids only.
- Delete the file's line-1 `AIDEV-NOTE` (`/* AIDEV-NOTE: This file reads
  Jumpstart's --bg-primary/--text-on-primary token family; COV-4–6 will migrate it
  to the new _tokens.css palette. */`) **last**, and delete the whole line — there
  is no blank line after it.
- Do not touch `--base-*` tokens. `--base-border-primary` is a **different** token
  that stays.
- Do not reformat, reorder, or otherwise edit lines you aren't remapping.

## Tasks

### Task 1 [Master]: Guard test + migrate `buttons.css` and `pills.css`

**Skills:** write-tests
**Reference:** Read `test/config/honeybadger_config_test.rb` for the plain-`Minitest::Test`
file-reading test pattern used in this repo.

**In scope:**

- New `test/config/tailwind_token_migration_test.rb` with **two** test methods:
  1. `test_component_stylesheets_never_reference_legacy_primary_tokens` — glob
     `app/**/*.css` and `lib/**/*.css`, assert none contains any of the seven
     literal strings `var(--bg-primary)`, `var(--bg-primary-hover)`,
     `var(--text-on-primary)`, `var(--border-primary)`,
     `var(--border-primary-hover)`, `var(--text-primary)`,
     `var(--text-primary-hover)`. Failure message names the offending file. Goes
     green at the end of Phase 1.
  2. `test_legacy_primary_tokens_are_no_longer_defined` — read
     `app/assets/tailwind/themes/light.css`, assert it has no declaration matching
     `/^\s*--(bg|text-on|text|border)-primary(-hover)?:/`. Goes green in Task 6.
     Anchoring at line start is what keeps `--base-border-primary:` from
     false-matching.
- `app/assets/tailwind/components/buttons.css` — 13 sites:
  - `.btn-primary`: 141 `background` → PRIMARY; 142 `color` → ON-PRIMARY
  - `.btn-primary &:hover`: 145 `background` → MIX; 146 `color` → ON-PRIMARY
  - `.btn-primary &:disabled:hover`: 150 `background` → PRIMARY; 151 `color` → ON-PRIMARY
  - `.btn-primary &.btn-outline`: 156 `color` → PRIMARY; 157 `border: 1px solid` →
    PRIMARY *(resting border, not a hover)*
  - `.btn-primary &.btn-outline &:hover`: 160 `background` → MIX; 161 `color` →
    ON-PRIMARY; 162 `border: 1px solid` → MIX
  - `.btn-link &:disabled:focus, &:disabled:hover`: 251 `color` → **FG** (design
    decision: disabled controls must not take the brand colour)
  - `.btn-link &.btn-icon`: 256 `border: 1px solid` → **BORDER** (design decision:
    near-black → `oklch(0.922)`, a deliberate visible change)
- `app/assets/tailwind/components/pills.css` — 4 sites, **all resting states
  despite the `-hover` token names**:
  - `.pill-primary`: 24 `background` → PRIMARY; 25 `color` → ON-PRIMARY
  - `.pill-primary &.pill-outline`: 29 `border: 1px solid` → PRIMARY; 30 `color` → PRIMARY
- Delete the `AIDEV-NOTE` from both stylesheets.

**NOT in scope:**

- Any other stylesheet; `themes/light.css`; `_tokens.css`.
- "Fixing" `.btn-link:disabled:hover` to a muted colour — `FG` is pixel-identical
  today and that's the whole intent.
- Making guard-test method #1 pass. It stays **red** until Task 5 and #2 until
  Task 6. Do not migrate other files to force it green.

**Build order:**

1. **Test:** write `test/config/tailwind_token_migration_test.rb` as above. Run it;
   confirm both methods fail with a message naming the un-migrated files.
2. **Implement:** the 17 edits above, then delete the two `AIDEV-NOTE` lines.
3. **Verify:** `grep -nE 'var\(--(bg|text-on|text|border)-primary(-hover)?\)' app/assets/tailwind/components/buttons.css app/assets/tailwind/components/pills.css`
   returns nothing. Then `bin/rails test test/config/tailwind_token_migration_test.rb`
   — expect both methods still red, and confirm the failure no longer names
   `buttons.css` or `pills.css`.
4. **Checkpoint 1 review:** this is the only task in Checkpoint 1 — run
   review-changes-mini covering Task 1 when the work is finished.

### Task 2 [Clone]: Migrate `forms.css` and `tabs.css`

**Reference:** the shared constants and per-task rules above; follow the MIX
formatting Task 1 established.

**In scope:**

- `app/assets/tailwind/components/forms.css` — 8 sites, **all → PRIMARY**:
  - `.form-control:focus`: 31 `box-shadow: inset 0 0 0 1px`; 32 `border: 1px solid`
  - `select:focus`: 74 `box-shadow`; 75 `border`
  - `select[multiple]:focus`: 97 `box-shadow`; 98 `border`
  - 280 checked radio `background`; 356 toggle `background`
  - These map to `--primary`, **not `--ring`** — `--ring` is `oklch(0.708)`,
    roughly 2.5:1 on white and below the 3:1 WCAG 2.4.11 expects for focus
    indicators.
- `app/assets/tailwind/components/tabs.css` — 6 sites under `&[data-active="true"]`:
  - 43 `border-bottom: 2px solid` → PRIMARY *(resting active underline)*; 44
    `color` → PRIMARY
  - `&:hover`: 47 `color` → **MIX**; 48 `border-bottom: 2px solid` → **MIX** *(the
    only true hovers in this file)*
  - `&:focus-visible, &:focus`: 54 `border: 2px solid` → PRIMARY; 55 `color` → PRIMARY
- Delete the `AIDEV-NOTE` from both files.

**NOT in scope:**

- Deleting or restructuring the `.form-control:focus` rules even if they turn out
  to be overridden by `rails_blocks/base.css` — Task 7 investigates that; this task
  only remaps.
- `--base-border-focus` on tabs.css:38 — different token, stays.

**Build order:**

1. **Test:** none new — Task 1's guard test covers this file set.
2. **Implement:** the 14 edits, then delete the two `AIDEV-NOTE` lines.
3. **Verify:** `grep -nE 'var\(--(bg|text-on|text|border)-primary(-hover)?\)' app/assets/tailwind/components/forms.css app/assets/tailwind/components/tabs.css`
   returns nothing.

### Task 3 [Clone]: Migrate `nav.css`, `top_nav.css`, `docs.css`

**In scope:**

- `app/assets/tailwind/components/nav.css` — 7 sites:
  - 163 active `::before` bar `background-color` → PRIMARY
  - 188, 191 active link + icon `color` → PRIMARY
  - `.cta-btn`: 216 `background-color` → PRIMARY; 217 `color` → **ON-PRIMARY**
  - 373 active `::before` bar `background-color` → PRIMARY
  - 466 active link `color` → PRIMARY
- `app/assets/tailwind/components/top_nav.css` — 3 sites, all → PRIMARY: 136
  `box-shadow: inset 4px 0 0 0`; 137 `color`; 143 `box-shadow: inset 0 -4px 0 0`
- `app/assets/tailwind/components/docs.css` — 3 sites, all → PRIMARY: 63 sidebar
  hover `color`; 68 active `border-left: 4px solid`; 69 active `color`
- Delete the `AIDEV-NOTE` from all three files.

**NOT in scope:**

- Any other nav-adjacent stylesheet (`toasts.css`, `modal.css`) — they carry no
  `AIDEV-NOTE` and no legacy primary references.
- `docs.css` styles the `/jumpstart/docs` gallery's own chrome; do not treat it as
  dev-only throwaway and skip it.

**Build order:**

1. **Test:** none new.
2. **Implement:** the 13 edits, then delete the three `AIDEV-NOTE` lines.
3. **Verify:** `grep -nE 'var\(--(bg|text-on|text|border)-primary(-hover)?\)' app/assets/tailwind/components/nav.css app/assets/tailwind/components/top_nav.css app/assets/tailwind/components/docs.css`
   returns nothing.
4. **Checkpoint 2 review:** Checkpoint 2 covers Tasks 2–3. Run review-changes-mini
   naming both when this task's work is finished. If Tasks 2 and 3 were dispatched
   as a parallel batch, the master runs this once the batch returns rather than
   this task running it. Either way, exactly once.

### Task 4 [Clone]: Migrate `pagination.css`, `typography.css`, `wells.css`, `notifications.css`

**In scope:**

- `app/assets/tailwind/components/pagination.css` — 5 sites under `a`:
  - 20 link `color` → PRIMARY
  - `&:hover`: 30 `color` → **MIX** *(a real hover)*
  - `&[aria-current="page"]`: 40 `background` → PRIMARY; 41 `border: 1px solid` →
    PRIMARY; 42 `color` → **ON-PRIMARY**
- `app/assets/tailwind/components/typography.css` — 2 sites: 53 `.link` `color` →
  PRIMARY; 59 `.link:hover/:focus` `color` → **MIX**
- `app/assets/tailwind/components/wells.css` — 1 site: 27 link `color` → PRIMARY
- `app/assets/tailwind/components/notifications.css` — 1 site: 15 `background` → PRIMARY
- Delete the `AIDEV-NOTE` from all four files.

**NOT in scope:**

- `pagination.css`'s `&:not([href])` disabled state (uses `--base-text-tertiary`) —
  untouched.
- `alert.css` — Task 5 owns it.

**Build order:**

1. **Test:** none new.
2. **Implement:** the 9 edits, then delete the four `AIDEV-NOTE` lines.
3. **Verify:** `grep -nE 'var\(--(bg|text-on|text|border)-primary(-hover)?\)' app/assets/tailwind/components/{pagination,typography,wells,notifications}.css`
   returns nothing.

### Task 5 [Clone]: Migrate `alert.css` — the documented exception

**In scope:**

- `app/assets/tailwind/components/alert.css:51` — `li` `color: var(--text-primary)`
  → **`var(--foreground)`**, *not* `--primary`. This is body copy inside a
  container that already carries its own semantic colour; brand-coloured bullet
  text inside a red danger alert would be actively wrong. Pixel-identical today
  (both `oklch(0.145)`).
- Replace the file's line-1 `AIDEV-NOTE` with a new one recording the exception,
  e.g.: `/* AIDEV-NOTE: COV-36 mapped this file's body copy to --foreground, not
  --primary: alerts already carry a semantic colour, so brand-tinted text inside a
  danger alert would fight it. Alerts intentionally do not rebrand. */`
- Because line 51 is this file's only primary-family reference, `alert.css` ends up
  with **zero** `--primary` references and does not rebrand. The ticket's
  acceptance criterion listing alerts as a surface that must visibly restyle is
  wrong; the design corrects it.

**NOT in scope:**

- Migrating alerts to `--primary` "for consistency."
- The semantic `--bg-danger` / `--text-on-success-secondary` family — separate
  ticket, red stays red.

**Build order:**

1. **Test:** none new.
2. **Implement:** the one edit plus the `AIDEV-NOTE` swap.
3. **Verify:** `grep -rnE 'var\(--(bg|text-on|text|border)-primary(-hover)?\)' app/ lib/`
   returns nothing. Then `bin/rails test test/config/tailwind_token_migration_test.rb`
   — method #1 must now be **green**; method #2 still red (Task 6 fixes it).
4. **Checkpoint 3 review:** Checkpoint 3 covers Tasks 4–5. Run review-changes-mini
   naming both when this task's work is finished. If Tasks 4 and 5 were dispatched
   as a parallel batch, the master runs this once the batch returns. Exactly once
   either way.

**Phase 1 exit condition:** all 12 stylesheets migrated, zero `AIDEV-NOTE`s about
deferred token work remain, guard-test method #1 green. Independently deployable —
`light.css` still defines the seven tokens, now simply unused.

### Task 6 [Master]: Delete the dead legacy tokens and record the contrast floor

**In scope:**

- `app/assets/tailwind/themes/light.css` — delete lines 4–10, the seven now-
  consumerless declarations: `--bg-primary`, `--bg-primary-hover`,
  `--text-on-primary`, `--border-primary`, `--border-primary-hover`,
  `--text-primary`, `--text-primary-hover`. **Keep line 93's
  `--base-border-primary`** — different token, still in use.
- `app/assets/tailwind/theme/_tokens.css` — add an `AIDEV-NOTE` next to the
  existing rebrand note recording that `--primary` is now load-bearing for
  accessibility, e.g.: `/* AIDEV-NOTE: COV-36 mapped form focus rings to --primary
  (not --ring, which is too light to meet WCAG 2.4.11). Any rebrand must keep
  --primary at >= 3:1 contrast against white or focus indicators become
  invisible. */`

**NOT in scope:**

- Any other token family: `--base-*`, `--bg-disabled`, `--divider-color`, and the
  semantic danger/success/warning/info tokens all stay exactly as they are.
- Changing the value of `--primary` or `--primary-foreground` — the rebrand itself
  remains deferred.

**Build order:**

1. **Test:** guard-test method #2 is already written and red — this task makes it green.
2. **Implement:** the deletion and the note.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH"` (confirm
   `ruby -v` reports 4.0.5), then
   `bin/rails test test/config/tailwind_token_migration_test.rb` — **both methods
   green**. Then the design's final grep:
   `grep -rn -- '--bg-primary\|--text-on-primary\|--border-primary\|--text-primary' app/ lib/`
   must return only `--base-border-primary` hits.

### Task 7 [Master]: Visual verification, rebrand proof, and full check

**Skills:** claude-in-chrome
**Reference:** AGENTS.md "Known Gotchas" — `ApplicationController.render` can't
render authenticated views; use a real Rails/Puma server plus a browser. Tailwind
v4 compiles nested rules, so search compiled CSS **text**, never CSSOM
`Element.matches()`.

**In scope:**

- Boot for verification: `export PATH="$HOME/.local/share/mise/shims:$PATH"`,
  `bin/rails tailwindcss:build` (`app/assets/builds/` does not exist yet — the
  build is required), `bin/rails server -p 3000` in the background.
  `/jumpstart/docs/*` requires authentication — sign in at `/users/sign_in` as
  `owner@cove.test` / `password` (seeded; run `bin/rails db:seed` first if the user
  is missing).
- Screenshot and eyeball all 11 surfaces, light mode only:
  `/jumpstart/docs/buttons`, `/pills`, `/wells`, `/tabs`, `/pagination`,
  `/alerts`, `/forms`, `/typography`, `/navigation`, `/notifications`, plus the
  gallery chrome itself for `docs.css`.
- **Resolve the known risk at `/jumpstart/docs/forms`:** `rails_blocks/base.css` is
  imported *after* `components/forms.css` in the same `layer(components)` and
  defines `.form-control` with `focus:ring-2 focus:ring-neutral-600`. At equal
  specificity the later import wins, so `forms.css:31–32` may already be dead for
  `.form-control` — making that edit a visual no-op. Determine this empirically by
  focusing a control and searching the compiled `app/assets/builds/tailwind.css`
  text. **Record the finding; do not delete the rules either way** — that's
  explicitly deferred.
- **Rebrand proof:** temporarily set `--primary` in `_tokens.css` to a saturated
  colour (e.g. `oklch(0.55 0.22 264)`), `bin/rails tailwindcss:build`, reload.
  Confirm all 10 rebranding surfaces visibly change **and that alerts do not**
  (Task 5's deliberate exception). Then revert `_tokens.css` and rebuild.
- Confirm the inert `dark:` utilities stayed inert — no `.dark` styles activated.
- Full check: `bin/rails test` and `bin/rubocop` (project-wide form; never point
  RuboCop at `.erb` paths). Review `git diff --stat` before commit.

**NOT in scope:**

- Dark-mode verification. Dark mode is intentionally disabled, `themes/dark.css` is
  gone, and `_tokens.css` carries no `.dark` block — light-only, per the design
  (which overrides the ticket on this).
- Lookbook or `/dev/kitchen_sink` — these 12 stylesheets style Jumpstart *engine*
  views and have no previews there.
- Committing the temporary rebrand colour. Verify
  `git diff app/assets/tailwind/theme/_tokens.css` shows only the new `AIDEV-NOTE`
  before finishing.

**Build order:**

1. **Verify:** the browser pass and rebrand proof above.
2. **Verify:** `bin/rails test`, `bin/rubocop`, `git diff --stat`.
3. **Checkpoint 4 review:** Checkpoint 4 covers Tasks 6–7. Run review-changes-mini
   naming both when this task's work is finished.

## Task Dependencies

- Task 1 first — it writes the guard test and establishes the MIX formatting every
  later task copies.
- **Tasks 2, 3, 4, 5 can all run in parallel** once Task 1 lands. They touch
  disjoint file sets and share no state.
- Task 6 depends on Tasks 1–5 all being complete — the token deletion is only safe
  once every consumer is gone.
- Task 7 depends on Task 6.
