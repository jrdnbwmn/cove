> Ticket: COV-83
> Branch: feature/cov-83-create-v1-marketing-page

# Plan: v1 marketing homepage

## Status

| Task | Phase | Checkpoint | Description                                                       | Assign | Done |
| ---- | ----- | ---------- | ----------------------------------------------------------------- | ------ | ---- |
| 1    | 1     | 1          | `marketing_page?` helper, `_wordmark` partial, navbar variant     | Master | ✅   |
| 2    | 1     | 1          | Wordmark in Devise/error layouts, drop `.minimal-top-nav` border  | Clone  | ✅   |
| 3    | 1     | 2          | Extract `pricing/_plans` partial (+ move locale keys)             | Master | ✅   |
| 4    | 1     | 2          | `PublicController` app-level override with plan loading           | Master | ✅   |
| 5    | 1     | 2          | Homepage view, `public.index.*` copy, homepage tests              | Clone  | ✅   |

## Prerequisites

- Design: `docs/designs/cov-83-v1-marketing-page.md`
- Prototype: None
- Feature branch exists (`feature/cov-83-create-v1-marketing-page`)
- Shell: `export PATH="$HOME/.local/share/mise/shims:$PATH"` before any `bin/rails` / `bin/rubocop` (confirm `ruby -v` → 4.0.5)
- Components used (all in catalog, none new): `ButtonComponent`, `PlanCardComponent` (via existing `pricing/_free_card` and `pricing/_premium_card`). No `/create-component` needed.

## Tasks

### Task 1 [Master]: `marketing_page?` helper, wordmark partial, navbar variant

**Skills:** write-tests
**Reference:** Read `app/views/application/_navbar.html.erb`, `app/controllers/application_controller.rb`, and `lib/jumpstart/app/controllers/concerns/authentication.rb` (for the `helper_method` idiom)

**In scope:**

- `ApplicationController#marketing_page?` exposed via `helper_method`. Backed by an explicit list of `controller_name#action_name` pairs: `public#index` and `pricing#show`. (Action-level, not controller-level, because `PublicController` also serves `/about`, `/terms`, `/privacy`, which must keep the standard navbar.) Add an `# AIDEV-NOTE:` explaining why the list is explicit.
- New `app/views/application/_wordmark.html.erb`: renders `Jumpstart.config.application_name` as text with `.font-display`. No `sr-only` span, no SVG.
- `_navbar.html.erb`: two branch points only — omit `border-b border-border` on the root `<nav>` when `marketing_page?`; brand link renders `render "application/wordmark"` when `marketing_page?`, otherwise the existing `render_svg "logo"` + `sr-only` span.
- Tests in `test/integration/public_test.rb`.

**NOT in scope:**

- Layouts `minimal` / `error` (Task 2)
- The homepage view, controller override, or pricing partial (Tasks 3–5)
- Changing the mobile toggle, dropdowns, or account links in the navbar
- The signed-in navbar logo (deferred per design)

**Build order:**

1. **Test:** `test/integration/public_test.rb` — add: (a) `get pricing_path` → `nav[aria-label='Primary']` has no `border-b` class and contains the text "Cove" with no `svg`; (b) `get about_path` → nav has `border-b` class and contains an `svg`; (c) signed-in `get accounts_path`-style page (use `sign_in users(:one)` + a known signed-in route, e.g. `edit_user_registration_path`) → nav has `border-b` and an `svg`; (d) brand link `a[href='/']` on `/pricing` has accessible text "Cove" exactly once (assert the `nav` brand link's text is "Cove" and has no `.sr-only` child). The `/` homepage assertions arrive in Task 5 (it still renders the stock page here, but the navbar branch is exercised via `/pricing`). Needs at least one visible `Plan` fixture so `/pricing` doesn't redirect — check `test/fixtures/plans.yml`.
2. **Implement:** `app/controllers/application_controller.rb`, `app/views/application/_wordmark.html.erb`, `app/views/application/_navbar.html.erb`.
3. **Verify:** `bin/rails test test/integration/public_test.rb`

### Task 2 [Clone]: Wordmark in Devise and error layouts

**Skills:** write-tests
**Reference:** Read `app/views/layouts/minimal.html.erb`, `app/views/layouts/error.html.erb`, `app/assets/tailwind/components/top_nav.css` (line ~172), `test/integration/errors_test.rb`

**In scope:**

- In `minimal.html.erb` and `error.html.erb`, replace the `render_svg "logo"` + `sr-only` span inside the `link_to root_path` block with `render "application/wordmark"` (created in Task 1).
- Delete the `border-bottom: 1px solid var(--base-border-tertiary);` line from `.minimal-top-nav` in `top_nav.css`.
- Tests: extend `test/integration/errors_test.rb` so the dynamic `/404` and `/500` pages show "Cove" text in the header link and contain no `svg`; add one assertion that a Devise page (`new_user_session_path`) shows the "Cove" text wordmark and no `svg` in `nav.minimal-top-nav`.

**NOT in scope:**

- `public/*.html` static error pages (must stay unchanged) and `test/integration/static_error_pages_test.rb`
- `app/views/jumpstart/docs/_top_nav.html.erb` (stays Jumpstart-branded)
- The main navbar or `_wordmark` itself (Task 1)

**Build order:**

1. **Test:** `test/integration/errors_test.rb` as above (fails until layouts change).
2. **Implement:** `app/views/layouts/minimal.html.erb`, `app/views/layouts/error.html.erb`, `app/assets/tailwind/components/top_nav.css`.
3. **Verify:** `bin/rails test test/integration/errors_test.rb test/integration/static_error_pages_test.rb`

**Checkpoint 1 review:** When this task's work is finished, run review-changes-mini for checkpoint 1 (Tasks 1–2). If Tasks 1–2 were executed as a parallel batch, the master runs this review once the whole batch returns instead of the task running it. It runs exactly once per checkpoint, after every task in the checkpoint is done. (Note: Task 2 depends on Task 1, so these run sequentially.)

### Task 3 [Master]: Extract `pricing/_plans` partial

**Skills:** write-tests
**Reference:** Read `app/views/pricing/show.html.erb`, `test/integration/plans_test.rb`, and the `pricing:` block in `config/locales/en.yml` (~line 252)

**In scope:**

- New `app/views/pricing/_plans.html.erb` containing the monthly/yearly toggle, the `data-controller="pricing"` wrapper, `subscription` / `free_family` computation, and the card grid — moved verbatim from `show.html.erb`. Takes locals `monthly_plans:` and `yearly_plans:` (no ivars).
- `pricing/show.html.erb` keeps the heading/subhead and the `no_refunds` footnote, and renders `render "pricing/plans", monthly_plans: @monthly_plans, yearly_plans: @yearly_plans`.
- Move the `monthly` / `yearly` keys in `config/locales/en.yml` from `pricing.show.*` to `pricing.plans.*` (the partial's lazy `t('.monthly')` scope). Leave `heading`, `subhead`, `no_refunds`, and `free.*` where they are; confirm nothing else references the moved keys (`grep -rn "pricing.show.monthly\|pricing.show.yearly"`).
- Test in `test/integration/plans_test.rb`: `/pricing` still renders the toggle buttons (labels "Monthly" / "Yearly"), the Free card, and the Premium card.

**NOT in scope:**

- The homepage or `PublicController` (Tasks 4–5)
- Restyling or changing any card behavior
- `pricing/_free_card` / `_premium_card` internals

**Build order:**

1. **Test:** `test/integration/plans_test.rb` — add the toggle-label assertions (`[data-controller='pricing'] button[data-frequency='monthly']` text "Monthly", likewise yearly). Run first to confirm it passes on the current markup, then keep it green through the refactor.
2. **Implement:** `app/views/pricing/_plans.html.erb`, `app/views/pricing/show.html.erb`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/plans_test.rb test/integration/premium_access_test.rb` and `bin/rails test test/integration/billing_policy_copy_test.rb`

### Task 4 [Master]: `PublicController` app-level override

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/public_controller.rb` and `app/controllers/accounts_controller.rb` (existing engine-override pattern), and `lib/jumpstart/app/controllers/pricing_controller.rb` (plan query)

**In scope:**

- New `app/controllers/public_controller.rb`: copy the engine file verbatim (`index`, `about`, `terms`, `privacy`, `reset_app`, same bodies). In `index`, add `@monthly_plans, @yearly_plans = Plan.visible.sorted.partition(&:monthly?)`. **No redirect** when empty. Add an `# AIDEV-NOTE:` that this replaces (not extends) the engine controller, so all five actions must stay in sync.
- Tests in `test/integration/public_test.rb`: `about_path`, `terms_path`, `privacy_path` return success and render their agreement/title content; `reset_app` route returns "Redirecting..." (find its path with `bin/rails routes | grep reset_app`).

**NOT in scope:**

- The homepage view (Task 5)
- Any change to `PricingController` (engine file; its redirect stays)
- Refactoring the other overridden controllers

**Build order:**

1. **Test:** the four-action regression tests above (they pass against the engine controller too — write them first as a safety net, then confirm they still pass after the override).
2. **Implement:** `app/controllers/public_controller.rb`.
3. **Verify:** `bin/rails test test/integration/public_test.rb`

### Task 5 [Clone]: Homepage view, copy, and tests

**Skills:** write-tests, style-ui
**Reference:** Read `app/views/pricing/show.html.erb` (heading + container idiom), `docs/COMPONENT_CATALOG.md` → `ButtonComponent` section only, and the `public:` block in `config/locales/en.yml` (~line 302)
**Prototype:** None — follow brand tokens (`--primary`, `--background`, `--bg-accent` / `--border-accent`; never hex). Only `h1`/`h2` take the serif. No shadows on buttons.

**In scope:**

- Replace the entire body of `app/views/public/index.html.erb` (including the dev-only Jumpstart buttons) with three stacked sections:
  1. **Hero:** `h1`, subhead `<p>`, one `ButtonComponent` (primary, `size: :lg`) with `href: new_user_registration_path`.
  2. **Value points:** three-up on desktop (`lg:grid-cols-3`), stacked on mobile; each an `h3` + one sentence. No icons.
  3. **Pricing:** `render "pricing/plans", monthly_plans: @monthly_plans, yearly_plans: @yearly_plans`, wrapped in `if @monthly_plans.any? || @yearly_plans.any?` so the section (including its heading) is omitted with no plans. Include the `pricing.show.no_refunds`-style footnote only if trivial to reuse; otherwise omit.
- Add `public.index.*` keys to `config/locales/en.yml` using the design's draft copy: headline "Your homeschool's chief of staff", subhead, CTA "Start free", three value-point heading/body pairs, and a pricing section heading. Every string in the template comes from `t(".key")`.
- Tests in `test/integration/public_test.rb`: signed-out `/` shows the `h1` headline, the CTA link `href` equals `new_user_registration_path`, three value-point headings, and both plan cards / the toggle; the page body contains no "Jumpstart" text outside the footer mark; with `Plan.update_all(hidden: ...)` (or the equivalent that makes `Plan.visible` empty — check the `visible` scope) `/` returns 200, still shows the hero and value points, and has no pricing toggle; navbar on `/` is borderless with the text wordmark (mirrors Task 1's `/pricing` assertions); signed-in `/` still renders the dashboard (existing test).

**NOT in scope:**

- Any new ViewComponent or Stimulus controller
- Footer `mark.svg`, SEO/OG tags, images, additional marketing pages
- Editing `PublicController` or the shared partial (Tasks 3–4)

**Build order:**

1. **Test:** `test/integration/public_test.rb` as above.
2. **Implement:** `app/views/public/index.html.erb`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/public_test.rb`; then `grep -rn 'render_svg "logo"' app/views` must list only `app/views/application/_navbar.html.erb` (non-marketing branch) and `app/views/jumpstart/docs/_top_nav.html.erb`; then `bin/rails test` and `bin/rubocop`.

**Checkpoint 2 review:** When this task's work is finished, run review-changes-mini for checkpoint 2 (Tasks 3–5). If Tasks 3–5 were executed as a parallel batch, the master runs this review once the whole batch returns instead of the task running it. It runs exactly once per checkpoint, after every task in the checkpoint is done.

## Task Dependencies

- Task 2 depends on Task 1 (needs `_wordmark` partial).
- Task 3 is independent of Tasks 1–2.
- Task 4 is independent of Tasks 1–3 but both are Master and both touch shared infra, so run sequentially.
- Task 5 depends on Tasks 3 (partial + locale keys) and 4 (`@monthly_plans` / `@yearly_plans`), and on Task 1 for its navbar assertions.
- Tasks 3 and 4 touch disjoint files and *could* run in parallel; Task 5 must wait for both. Task 5 and Task 3 both edit `config/locales/en.yml`, so never run them concurrently.
