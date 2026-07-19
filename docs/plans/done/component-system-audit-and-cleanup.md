> Ticket: COV-17
> Branch: jrdnbwmn/cov-17-review-components

# Plan: Component System Audit + Final Cleanup

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1  | Add `target` param to ButtonComponent | Master | ✅ |
| 2  | Override homepage into app + swap CTAs to ButtonComponent | Master | ✅ |
| 3  | Cut dark-mode wiring (layout, head, theme controller) | Master | ✅ |
| 4a | Dark CSS cleanup: tokens + entry file (keep @variant dark) | Master | ✅ |
| 4b | Strip `.dark` blocks from 5 JSP component CSS files | Master | ✅ |
| 5  | Remove theme picker + tokenize profile-edit view | Master | ✅ |
| 6  | Delete orphaned nav.css / top_nav.css (verify-then-delete) | Master | ✅ |
| 7a | Color audit: auth + account views | Clone | ✅ |
| 7b | Color audit: application partials + pricing | Clone | ✅ |
| 7c | Color audit: billing subscription views | Clone | ✅ |

## Prerequisites

- Design: docs/designs/component-system-audit-and-cleanup.md
- Prototype: None (no visual design changes)
- Feature branch exists: jrdnbwmn/cov-17-review-components ✓
- No migration (theme is a `preferences` store_accessor, not a column)

## Tasks

---

### Phase 1 — Homepage

### Task 1 [Master]: Add `target` param to ButtonComponent

**Skills:** write-tests, style-ui
**Reference:** app/components/button_component.rb (`tag_attributes`, lines 73–89),
test/components/button_component_test.rb

**In scope:**

- Add `target: nil` keyword arg to `#initialize`; store as `@target`.
- In `tag_attributes`, when `@href.present?` and `@target.present?`, set
  `attrs[:target] = @target` (add `rel: "noopener"` when target is `_blank`).
- Add a component test: renders `a[target="_blank"][rel~="noopener"]` when
  `href:` + `target: "_blank"` given.
- Update docs/COMPONENT_CATALOG.md: add `target` row to the ButtonComponent
  arguments table.

**NOT in scope:**

- Any other new params. Changing existing variant/size behavior.
- Lookbook preview changes (existing preview stays).

**Build order:**

1. **Test:** test/components/button_component_test.rb — assert
   `a[href][target="_blank"]` renders with `rel` including `noopener`.
2. **Implement:** app/components/button_component.rb; update catalog.
3. **Verify:** `mise exec -- bin/rails test test/components/button_component_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 2 [Master]: Override homepage into app + swap CTAs

**Skills:** style-ui
**Reference:** lib/jumpstart/app/views/public/index.html.erb (stock view to copy)

**In scope:**

- Create app/views/public/index.html.erb by copying the stock engine view
  verbatim (app view overrides the engine view for `public#index`).
- Replace the two `link_to ... class: "btn ..."` CTAs (inside the existing
  `Rails.env.development?` block) with `ButtonComponent`:
  - "Configure Jumpstart" → `variant: :primary`, `href: jumpstart_path`,
    `data: { turbo: false }`.
  - "Read the Docs" → `variant: :outline`, `href: jumpstart.docs_path`,
    `target: "_blank"` (from Task 1), `data: { turbo: false }`.
- Keep the layout, copy, headings, and the `Rails.env.development?` guard
  exactly as-is.

**NOT in scope:**

- public/about, dashboard/show (typed-content stubs — leave untouched).
- Any layout/visual restructuring.

**Build order:**

1. **Test:** test/integration/public_test.rb already asserts `root_path` → 200;
   keep it green. (Buttons are dev-only so not asserted in test env; Jordan
   visually QAs in dev.)
2. **Implement:** app/views/public/index.html.erb.
3. **Verify:** `mise exec -- bin/rails test test/integration/public_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

**Depends on:** Task 1 (needs `target` param).

---

### Phase 2 — Disable dark mode (Level 1)

### Task 3 [Master]: Cut dark-mode wiring

**Skills:** write-tests
**Reference:** app/views/layouts/application.html.erb (lines 1–6),
app/views/application/_head.html.erb, app/javascript/controllers/theme_controller.js,
app/javascript/controllers/index.js

**In scope:**

- layouts/application.html.erb: drop `dark:` from `<html>` `class_names`
  (keep `hotwire-native`); remove `theme` from the `<body>` `data-controller`
  and remove `data-theme-preference-value`.
- application/_head.html.erb: delete the `current_user&.system_theme?`
  pre-paint `<script>` block.
- Delete app/javascript/controllers/theme_controller.js. No manual unregister
  needed — index.js eager-loads by directory scan (`eagerLoadControllersFrom`),
  so removing the file removes the `theme` controller.

**NOT in scope:**

- Any `.dark` CSS (Tasks 4a/4b). The theme picker (Task 5). Inert `dark:`
  classes in other views.

**Build order:**

1. **Test:** test/integration/public_test.rb (or a new layout integration
   test) — `get root_path`; assert body does NOT include
   `data-controller="theme"` nor `data-theme-preference-value`, and head does
   NOT include the `classList.toggle("dark"` script.
2. **Implement:** edit the two views; delete theme_controller.js.
3. **Verify:** `mise exec -- bin/rails test test/integration/public_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 4a [Master]: Dark CSS cleanup — tokens + entry file

**Reference:** app/assets/tailwind/theme/_tokens.css (`.dark` block lines
13–22), app/assets/tailwind/application.css (lines 6, 27)

**In scope:**

- theme/_tokens.css: delete the `.dark { … }` override block (lines 13–22).
  Leave `:root` and `@theme inline` intact.
- application.css: remove `@import "./themes/dark.css" layer(theme);` (line 27).
- **KEEP** `@variant dark (&:where(.dark, .dark *));` (line 6). Add an
  `AIDEV-NOTE` above it: kept intentionally so the ~468 inert component
  `dark:` classes never match (removing it would re-enable dark via
  prefers-color-scheme).
- Delete app/assets/tailwind/themes/dark.css.

**NOT in scope:**

- themes/light.css — leave fully intact. Its `--bg-dark` / `--text-on-dark`
  tokens are dark-*surface* colors, NOT dark-mode; do not touch.
- The 5 component CSS files (Task 4b).

**Build order:**

1. **Test:** none (CSS). Verification is the build compile below.
2. **Implement:** the edits + deletion above.
3. **Verify:** `mise exec -- bin/rails tailwindcss:build` compiles clean;
   `mise exec -- bin/rails test`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 4b [Master]: Strip `.dark` blocks from JSP component CSS

**Reference:** grep `\.dark` in each file first to locate blocks.

**In scope:** delete the `.dark { … }` / `:root.dark` selector blocks from:

- app/assets/tailwind/components/forms.css (1)
- app/assets/tailwind/components/notifications.css (1)
- app/assets/tailwind/components/braintree.css (45)
- app/assets/tailwind/components/lexxy.css (2)
- app/assets/tailwind/rails_blocks/base.css (3)

**NOT in scope:**

- Non-`.dark` rules in those files. `@variant dark` in application.css.
- View/component `dark:` utility classes (deferred Level 2).

**Build order:**

1. **Test:** none (CSS).
2. **Implement:** remove only the `.dark`-scoped blocks; leave the light
   rules untouched.
3. **Verify:** `mise exec -- bin/rails tailwindcss:build` compiles clean;
   `grep -rn "\.dark" app/assets/tailwind` shows only the kept `@variant`
   line in application.css.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 5 [Master]: Remove theme picker + tokenize profile-edit view

**Skills:** write-tests, style-ui
**Reference:** app/views/devise/registrations/edit.html.erb (theme
SelectComponent, lines 62–71), lib/jumpstart/app/models/user/theme.rb

**In scope:**

- Delete the `SelectComponent` for `user[theme]` (theme picker) from
  devise/registrations/edit.html.erb.
- Convert this file's hardcoded gray/neutral utilities to semantic tokens
  (see mapping in Task 7). Leave adjacent inert `dark:` variants as-is.

**NOT in scope:**

- Editing lib/jumpstart/app/helpers/theme_helper.rb or the User::Theme
  concern — they go inert (engine code, unused once the picker is gone).
- Other views' colors (Tasks 7a–7c).

**Build order:**

1. **Test:** test/controllers/users/registrations_controller_test.rb — GET
   edit; assert the response does NOT include `name="user[theme]"`.
2. **Implement:** remove the select; tokenize colors.
3. **Verify:** `mise exec -- bin/rails test test/controllers/users/registrations_controller_test.rb`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

---

### Phase 3 — Legacy CSS + token hygiene

### Task 6 [Master]: Delete orphaned nav.css / top_nav.css

**Reference:** app/assets/tailwind/components/nav.css, top_nav.css;
application.css imports (lines 42, 49).

**In scope:**

- **Verify-then-delete:** for each class defined in nav.css and top_nav.css,
  `grep -rn "class-name" app/views app/components lib` (and JS). If ALL
  classes in a file are unreferenced, delete the file and its `@import` in
  application.css. If any class is still used, KEEP that file and note which
  class blocked it — do not refactor the usage.

**NOT in scope:**

- Chasing a still-referenced class into a larger refactor (guardrail).

**Build order:**

1. **Test:** none.
2. **Implement:** per-class grep; delete files + imports only if fully unused.
3. **Verify:** `mise exec -- bin/rails tailwindcss:build`; `mise exec -- bin/rails test`.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Tasks 7a / 7b / 7c [Clone]: Color audit — hardcode → semantic tokens

**Skills:** style-ui
**Reference:** app/assets/tailwind/theme/_tokens.css (available tokens)

**Shared mapping (apply consistently; when a color's role is ambiguous,
LEAVE it and note the file:line — do not guess):**

- primary/body text (`text-neutral-900`, `text-gray-900`) → `text-foreground`
- secondary/muted text (`text-neutral-500/600/700`) → `text-muted-foreground`
- subtle surface bg (`bg-neutral-50/100`, `bg-gray-50/100`) → `bg-muted`
- borders (`border-neutral-200/300`, `border-gray-200/300`) → `border-border`
- page bg (`bg-white`, `bg-neutral-0`) → `bg-background`

**In scope (per cluster):**

- 7a: devise/shared/_links.html.erb, account_invitations/show.html.erb,
  accounts/index.html.erb, accounts/show.html.erb
- 7b: application/_user_menu.html.erb, application/_dev_menu.html.erb,
  pricing/show.html.erb
- 7c: billing/subscriptions/edit.html.erb, pauses/show.html.erb,
  cancels/show.html.erb, resumes/show.html.erb

**NOT in scope:**

- devise/registrations/edit.html.erb (done in Task 5).
- Removing/altering inert `dark:` variant classes (deferred Level 2 — leave).
- Kitchen-sink page / intentional demo colors.
- Any layout or structural change — colors only.

**Build order (each clone):**

1. **Test:** none (visual-only, no behavior change).
2. **Implement:** apply the mapping to the cluster's files.
3. **Verify:** `mise exec -- bin/rails test` stays green (regression check).
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

## Task Dependencies

- Task 2 depends on Task 1 (needs the `target` param).
- Phase 2 (3, 4a, 4b, 5) can follow Phase 1; within it, 4a → 4b (build
  sanity), otherwise independent.
- Phase 3 follows Phase 2. Task 6 independent. Tasks 7a/7b/7c are fully
  parallel Clone work (disjoint file sets), and independent of Task 6.
