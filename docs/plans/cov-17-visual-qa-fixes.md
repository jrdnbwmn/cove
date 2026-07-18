> Ticket: COV-17
> Branch: jrdnbwmn/cov-17-review-components

# Plan: COV-17 Visual-QA Fixes

Follow-up to the component-system audit (`docs/plans/component-system-audit-and-cleanup.md`).
These fixes address issues found during Jordan's visual check of the app + Lookbook.
All root causes are verified against source and the compiled `app/assets/builds/tailwind.css`.

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| A  | Fix global link underlines + list bullets (base.css) | Master | ☐ |
| B1 | `text-muted` → `text-muted-foreground`: accounts + api_tokens | Clone | ☐ |
| B2 | `text-muted` → `text-muted-foreground`: billing + checkouts | Clone | ☐ |
| B3 | `text-muted` → `text-muted-foreground`: auth + pricing + public + components | Clone | ☐ |
| C  | Retire legacy `.text-muted` class + `--text-muted` token | Master | ☐ |
| D  | Load JS in Lookbook preview layout | Master | ☐ |
| E  | Make toast preview demonstrable (add trigger) | Master | ☐ |
| F  | Kitchen sink: fix "Plan" select + remove dark examples | Master | ☐ |

## Root-cause summary (verified)

| # (Jordan's list) | Symptom | Root cause |
| ---- | ------- | ---------- |
| 1 | Very light / near-white text | `text-muted` collision. Legacy `.text-muted { color: var(--text-muted) }` (gray-600, components layer) is overridden by the Tailwind-generated `.text-muted { color: var(--muted) }` utility. `--muted: oklch(0.97 0 0)` ≈ white, and the utilities layer wins the cascade. Both rules confirmed present in `tailwind.css`. |
| 2 | Underlines on button/link text | Global `a { text-decoration: underline }` in `components/base.css:21-39` leaks into `ButtonComponent` (renders `<a>`), footer links, dropdown items, breadcrumbs. |
| 3 | Bullets on footer/breadcrumb lists | Global `ul { list-style: disc }` / `ol { list-style: decimal }` in `components/base.css:46-54` re-add bullets that Tailwind Preflight had reset to none. |
| 4 | Dropdown / tooltip / modal dead in Lookbook | `layouts/component_preview.html.erb` loads the stylesheet but has **no `javascript_importmap_tags`**, so no Stimulus controller runs in previews. |
| 5 | Tabs / toast not visible in Lookbook | Tabs: same missing-JS cause as #4. Toast: `UiToastComponent` renders only an empty container (`height: 0px`) — nothing shows until a toast is dispatched, and the preview has no trigger. |
| 6 | Kitchen-sink "Plan" select mis-styled | The inline demo (`dev/kitchen_sink/show.html.erb:28-32`) uses a raw `<select class="form-control">`. `.form-control` (`forms.css:13`) and the base `select` rule (`forms.css:53`) both apply and conflict (padding, no appearance reset / dropdown arrow), so it looks unlike the polished `SelectComponent` demo at line 59. |
| 7 | Dark-mode examples remain in kitchen sink | Leftover `.dark` demo blocks after dark-mode removal (7 blocks). |

## Prerequisites

- Feature branch exists: `jrdnbwmn/cov-17-review-components` ✓
- Run all Rails/bin commands through `mise exec --` (see CLAUDE.local.md).
- Do NOT run RuboCop directly on `.erb` paths — use `bin/rubocop`.
- No migration, no new gems.

## Decisions Jordan made (2026-07-18)

- **Task A:** OK to also drop the global `a` `color` / `font-weight` so links are fully
  neutral by default (components set their own). _CONFIRM at execution time if unsure —
  Jordan leaned toward neutral but flag if any bare content link looks wrong._
- **Task F / #6:** Prefer keeping the `variant: :inline` FormField demo but with a
  properly-styled select. If restyling the raw select is awkward, fall back to rendering
  a real `SelectComponent` there. _CONFIRM at execution._

> NOTE: the two items above were left as open questions in the planning session.
> Re-confirm with Jordan before executing A and F if there's any ambiguity.

---

## Tasks

### Task A [Master]: Fix global link underlines + list bullets (#2, #3)

**Reference:** `app/assets/tailwind/components/base.css` (lines 21-54)

**In scope:**

- From the global `a {}` rule: remove `text-decoration: underline`,
  `text-underline-offset`, and `text-decoration-color`. Delete the `@supports`
  block (lines 34-39) that only sets link underline color.
- Also drop `color: var(--base-text)` and `font-weight: var(--font-weight-medium)`
  from `a {}` (neutral links by default) — pending Jordan's confirm; if in doubt,
  keep them and remove only the underline declarations.
- Remove the global `ul { list-style-type: disc; list-style-position: inside }`
  and `ol { list-style-type: decimal; list-style-position: inside }` blocks.
  (Preflight already resets these to none.)

**NOT in scope:**

- The `.link` class (typography.css) and `.prose` (typography plugin) — they
  provide intentional underlines/lists and stay.
- Any component or view markup changes.

**Build order:**

1. **Verify first:** `grep -rn "<ul\|<ol" app/views` and check docs / `.prose`
   pages for content lists/links that visually depend on bullets or underlines.
   If any legitimate content relies on them, wrap in `.prose` or add `list-disc`
   utilities rather than keeping the global rule.
2. **Implement:** edit base.css.
3. **Verify:** `mise exec -- bin/rails tailwindcss:build` compiles clean;
   `mise exec -- bin/rails test`. Eyeball footer, profile dropdown, breadcrumbs,
   and buttons ("Read the Docs") — no underlines, no bullets.
4. **Review:** run review-changes before proceeding.

---

### Tasks B1 / B2 / B3 [Clone]: `text-muted` → `text-muted-foreground` migration (#1)

Finishes the token migration that audit tasks 7a-7c started but didn't cover for
all views. Apply the plan's existing mapping: **muted text → `text-muted-foreground`**.
Also convert `text-muted` on SVG icons (`fill="currentColor"`) → `text-muted-foreground`.

Disjoint file clusters (fully parallel — no shared files):

- **B1 — accounts + api_tokens:**
  `accounts/new.html.erb`, `accounts/edit.html.erb`,
  `accounts/account_invitations/new.html.erb`,
  `accounts/account_invitations/edit.html.erb`,
  `accounts/transfers/_form.html.erb`,
  `account_users/edit.html.erb`, `account_invitations/show.html.erb`,
  `api_tokens/show.html.erb`, `api_tokens/new.html.erb`, `api_tokens/edit.html.erb`
- **B2 — billing + checkouts:**
  `billing/show.html.erb`, `billing/_email.html.erb`, `billing/_charges.html.erb`,
  `billing/_info.html.erb`, `billing/subscriptions/_summary.html.erb`,
  `billing/subscriptions/edit.html.erb`,
  `billing/subscriptions/cancels/show.html.erb`,
  `billing/subscriptions/payment_methods/new.html.erb`,
  `billing/subscriptions/upcomings/show.html.erb`,
  `checkouts/show.html.erb`, `checkouts/_testimonial.html.erb`
- **B3 — auth + pricing + public + components:**
  `devise/registrations/edit.html.erb`, `devise/shared/_links.html.erb`,
  `account/passwords/edit.html.erb`, `pricing/show.html.erb`,
  `public/index.html.erb`, `app/components/plan_card_component.html.erb`

**NOT in scope:**

- `text-muted-foreground` occurrences (already correct — leave).
- The `.text-muted` CSS class / `--text-muted` token (removed in Task C, after B).
- Any layout/structural change — color utility swap only.

**Build order (each clone):**

1. **Test:** none (visual-only, no behavior change).
2. **Implement:** replace every `text-muted` (not `-foreground`) with
   `text-muted-foreground` in the cluster's files. Re-grep the cluster to confirm
   zero bare `text-muted` remain.
3. **Verify:** `mise exec -- bin/rails test` stays green.
4. **Review:** clones stage changes and report; do NOT commit.

> Re-run `grep -rlE 'text-muted( |")' app/views app/components` before starting to
> pick up any file added since planning (planning snapshot: ~27 files).

---

### Task C [Master]: Retire legacy `.text-muted` class + token (#1 cleanup)

**Depends on:** B1, B2, B3 all complete (nothing references `.text-muted` anymore).

**Reference:** `app/assets/tailwind/components/typography.css:83-85`,
`app/assets/tailwind/themes/light.css:104`

**In scope:**

- `grep -rn "text-muted[^-]" app/views app/components` → confirm zero remaining
  (guard before deleting the class).
- Delete the `.text-muted { color: var(--text-muted) }` block from typography.css.
- Delete `--text-muted: var(--color-gray-600)` from light.css (confirm no other
  refs via `grep -rn "\-\-text-muted" app`).

**Build order:**

1. **Implement:** the two deletions after the guard grep.
2. **Verify:** `mise exec -- bin/rails tailwindcss:build`; confirm the duplicate
   `.text-muted{color:...}` utility no longer collides (only the semantic
   `text-muted-foreground` remains in use). `mise exec -- bin/rails test`.
3. **Review:** run review-changes.

---

### Task D [Master]: Load JS in Lookbook preview layout (#4, #5-tabs)

**Reference:** `app/views/layouts/component_preview.html.erb`,
`app/views/application/_head.html.erb:6` (source of the tag to mirror)

**In scope:**

- Add `<%= javascript_importmap_tags %>` inside `<head>` of the preview layout.
  This wires Stimulus so dropdown, tooltip, modal, and tabs become interactive in
  Lookbook previews. Controllers auto-register via the index.js directory scan.

**NOT in scope:**

- The app layout or `_head` partial. Any component behavior change.

**Build order:**

1. **Test:** none (layout/asset).
2. **Implement:** add the tag.
3. **Verify:** open Lookbook (`/lookbook`) previews for DropdownComponent,
   TooltipComponent, UiModalComponent, UiTabsComponent — confirm each responds to
   interaction (open/close, hover, tab switch).
4. **Review:** run review-changes.

---

### Task E [Master]: Make toast preview demonstrable (#5-toast)

**Depends on:** Task D (JS must load for the toast to fire).

**Reference:** `test/components/previews/ui_toast_component_preview.rb`,
`app/components/ui_toast_component.*`, the toast Stimulus controller
(`app/javascript/controllers/` — find the `ui-toast` / toast controller to learn
the exact dispatch event/API).

**In scope:**

- `UiToastComponent` renders only an empty container; add a trigger button to the
  preview that dispatches the toast event so a toast actually appears. Confirm the
  event name / payload from the toast controller before wiring the button.

**NOT in scope:**

- Changing `UiToastComponent` itself (unless the controller offers no public
  trigger — if so, note it and ask Jordan).

**Build order:**

1. **Implement:** add trigger(s) to the preview.
2. **Verify:** Lookbook UiToastComponent preview → clicking the trigger shows a toast.
3. **Review:** run review-changes.

---

### Task F [Master]: Kitchen sink — fix "Plan" select + remove dark examples (#6, #7)

**Reference:** `app/views/dev/kitchen_sink/show.html.erb`,
`app/components/select_component.*` (for correct select classes/markup),
`app/assets/tailwind/components/forms.css` (`.form-control` vs base `select`)

**In scope:**

- **#6:** the inline "Plan" demo (lines 28-32) must stop rendering a raw
  `<select class="form-control">`. Restyle it to match the design-system select
  (appearance reset + dropdown arrow, as `SelectComponent` produces) so it looks
  like the polished select at line 59. If restyling the raw select inside the
  FormFieldComponent is awkward, render a real `SelectComponent` there instead
  (pending Jordan's confirm — see Decisions above).
- **#7:** delete every `.dark` demo block and "Dark mode ..." labeled example:
  lines ~7-9, 47-53, 63-69, 113-124, 146-155, 192-202, 243-248 (re-locate by
  `grep -n 'dark' app/views/dev/kitchen_sink/show.html.erb` — line numbers will
  shift as blocks are removed).

**NOT in scope:**

- Other kitchen-sink sections / non-dark demos. Any component code change.

**Build order:**

1. **Test:** `mise exec -- bin/rails test test/integration/dev/kitchen_sink_test.rb`
   should stay green (adjust only if it asserts on removed dark blocks).
2. **Implement:** fix the select demo; remove all dark blocks.
3. **Verify:** load `/dev/kitchen_sink` in dev — Plan select matches line-59
   select; no dark-mode examples remain. Run the kitchen-sink test.
4. **Review:** run review-changes.

## Task Dependencies

- Tasks A, D, F are independent and can start immediately (each ≤ 1 file, Master).
- Tasks B1/B2/B3 are fully parallel Clone work (disjoint file sets).
- Task C depends on B1 + B2 + B3 (all `text-muted` usages migrated first).
- Task E depends on Task D (JS must load before a toast can fire).

## Global verification (end of plan)

- `mise exec -- bin/rails tailwindcss:build` compiles clean.
- `mise exec -- bin/rails test` green.
- `git diff` reviewed for stray debug artifacts.
- Visual re-check of the four screenshots' surfaces: homepage subtitle + CTAs,
  footer, profile dropdown, billing "not subscribed" / billing-email copy — plus
  a Lookbook click-through of the JS components.
