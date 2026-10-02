> Ticket: COV-92
> Branch: feature/cov-92-fill-out-extraneous-pages

# Plan: Legal and About pages (Terms, Privacy, Refund Policy, About)

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Enable Terms/Privacy agreements (no re-accept prompt) | Master | ✅   |
| 2    | 1     | 1          | Shared legal page layout; Terms/Privacy use it | Master | ✅   |
| 3    | 1     | 1          | `/refunds` route, action, page + Refund Policy copy | Master | ✅   |
| 4    | 2     | 2          | Terms of Service copy | Clone  | ✅   |
| 5    | 2     | 2          | Privacy Policy rewrite | Clone  | ✅   |
| 6    | 2     | 2          | About page copy | Clone  | ✅   |
| 7    | 3     | 3          | Refunds link in footer + sidebar account menu | Clone  | ✅   |
| 8    | 3     | 3          | Refund + terms links on pricing and checkout | Master | ✅   |
| 9    | 3     | 3          | Refund links on cancel page + family-deletion notice | Master | ✅   |
| 10   | 3     | 4          | Screenshot check, final dates, product-brief update | Master | ✅   |

## Prerequisites

- Design: `docs/designs/legal-and-about-pages.md` (read the **Document Content**
  section before any copy task — it is the outline every copy task follows)
- Product rules: `docs/product/product-brief.md` (billing + family rules the
  copy must match)
- Prototype: None
- Feature branch exists: `feature/cov-92-fill-out-extraneous-pages`
- Before any `bin/rails` command: `export PATH="$HOME/.local/share/mise/shims:$PATH"`
  and confirm `ruby -v` reports 4.0.5.
- No new components needed — these are text pages using plain HTML +
  Tailwind's `prose` (the `@tailwindcss/typography` plugin is already loaded in
  `app/assets/tailwind/application.css`). Links are plain `link_to`.

### Facts every task should know

- `app/controllers/public_controller.rb` **replaces** the engine's
  `lib/jumpstart/app/controllers/public_controller.rb` (it doesn't extend it).
  The engine's `public/terms.html.erb` / `privacy.html.erb` views are used today
  because there are no app-level ones; creating `app/views/public/terms.html.erb`
  etc. overrides them.
- Terms/Privacy body copy lives in `app/views/users/agreements/_terms_of_service.html.erb`
  and `_privacy_policy.html.erb`. These partials are ALSO rendered by Jumpstart's
  re-accept screen (`lib/jumpstart/app/views/users/agreements/show.html.erb`), so
  they must contain body copy only — no H1, no "Last updated" line, no wrapper.
- Operating party, address, and email come from `Jumpstart.config`:
  `business_name` ("Cove"), `business_address` (contains a `\n` — render with
  `simple_format` or split on newline), `support_email`, `domain`.
- Copy rule: never state the Premium student cap number in legal copy
  ("reasonable use" only). Never promise unbuilt features.
- Body copy style: plain-language sections, each `<section>` with one `<h2>`,
  `<p>`s, and `<ul>` for sub-points. No `<h3>`+ headings. Bold (`<strong>`)
  only where emphasis is legally expected. No ALL CAPS.
- Every legal partial starts with an ERB comment
  `<%# AIDEV-NOTE: Revisit this page when: student logins ship, AI features launch (name providers), Cove forms an LLC (update operating party), analytics is added, or any new data processor is added. %>`

## Tasks

### Task 1 [Master]: Enable Terms/Privacy agreements without prompting

**Skills:** write-tests
**Reference:** Read `config/initializers/agreements.rb`,
`lib/jumpstart/app/controllers/concerns/users/agreement_updates.rb`,
`lib/jumpstart/app/models/user/agreements.rb`

**In scope:**

- Uncomment both `Agreement.new` entries in `config/initializers/agreements.rb`:
  `title: "Terms of Service"` (fix capitalization) and `"Privacy Policy"`,
  `updated: Time.zone.parse("<today's date, YYYY-MM-DD> 00:00:00")` (Task 10
  re-confirms the date), `prompt_when_updated: false` on both.
- Replace the "Uncomment these…" comment with an `# AIDEV-NOTE:` explaining:
  entries exist so pages show "Last updated"; nobody is prompted because
  `require_accepted_latest_agreements!` only checks `prompt_when_updated: true`;
  for a future material change, bump `updated` and set `prompt_when_updated: true`
  so every user re-accepts once.

**NOT in scope:**

- Any view changes (Task 2). Refund Policy is NOT an Agreement.

**Build order:**

1. **Test:** new `test/integration/legal_agreements_test.rb`:
   - "signed-in parent is not sent to the agreement screen" — set
     `users(:one).update!(accepted_terms_at: 1.year.ago, accepted_privacy_at: 1.year.ago)`
     (older than `updated`), `sign_in`, `get user_root_path`, assert response is
     not a redirect to `agreement_path(:terms_of_service)` / `:privacy_policy`.
   - "terms and privacy agreements are configured" — assert
     `Rails.application.config.agreements.map(&:id)` equals
     `[:terms_of_service, :privacy_policy]` and none has `prompt_when_updated`.
2. **Implement:** edit `config/initializers/agreements.rb` as above.
3. **Verify:** `bin/rails test test/integration/legal_agreements_test.rb test/integration/public_test.rb`

---

### Task 2 [Master]: Shared legal page layout; Terms/Privacy pages use it

**Skills:** write-tests, style-ui
**Reference:** Read `lib/jumpstart/app/views/public/terms.html.erb` (current
markup to replace), `app/assets/tailwind/components/typography.css` (h1/h2 are
serif weight 400)

**In scope:**

- New `app/views/public/_legal_page.html.erb`, locals `title:` and `updated:`
  (a Date or nil), body via `yield`. Markup: `max-w-prose mx-auto my-12`
  column; `<h1 class="mb-4">`; when `updated` present,
  `tag.p t("users.agreements.show.last_updated", date: l(updated, format: :long)), class: "mb-8 text-muted-foreground"`;
  body inside `<div class="prose prose-headings:font-normal max-w-none">`.
  Add `# AIDEV-NOTE`: Fabric Serif has only weight 400; `prose` bolds headings
  by default, which causes faux bold — hence `prose-headings:font-normal`.
- New `app/views/public/terms.html.erb` and `privacy.html.erb`: set meta title
  (`Current.meta_tags.set(title: t(".title"))`), then
  `render layout: "public/legal_page", locals: {title: t(".title"), updated: @agreement&.updated&.to_date} do` →
  `render "users/agreements/terms_of_service"` (resp. `privacy_policy`).
  Note: lazy `t(".title")` inside the block resolves to the calling view — pass
  the title as a local, don't call `t(".title")` inside the partial.
- `config/locales/en.yml`: `public.terms.title` → `"Terms of Service"`.

**NOT in scope:**

- Changing body copy of either partial (Tasks 4–5). About page (Task 6).

**Build order:**

1. **Test:** in `test/integration/public_test.rb` add:
   - "terms page shows when it was last updated" — `get terms_path`, assert
     `h1` text "Terms of Service" and body includes
     `I18n.t("users.agreements.show.last_updated", date: I18n.l(<terms agreement>.updated.to_date, format: :long))`.
   - same for privacy.
   - "legal page still renders when its agreement is missing" —
     `Rails.application.config.stub(:agreements, []) { get terms_path }`; assert
     success, h1 present, body does not include "Last updated".
   - "legal page headings are not bolded" — assert `div.prose.prose-headings\\:font-normal` present on terms.
2. **Implement:** the partial, the two views, the locale fix.
3. **Verify:** `bin/rails test test/integration/public_test.rb test/integration/legal_agreements_test.rb`

---

### Task 3 [Master]: `/refunds` route, action, page, and Refund Policy copy

**Skills:** write-tests
**Reference:** Read `app/controllers/public_controller.rb`,
`config/routes/jumpstart.rb` (`scope controller: :public` block),
`docs/designs/legal-and-about-pages.md` → "Refund Policy" outline,
`docs/product/product-brief.md` billing rules

**In scope:**

- `config/routes/jumpstart.rb`: `get :refunds` after `get :privacy` in the
  public scope (gives `refunds_path`).
- `PublicController#refunds` — empty action. Update the class's AIDEV-NOTE:
  it no longer mirrors the engine's five actions exactly; say it replaces the
  engine controller, must keep all engine actions, and adds `refunds`.
- `config/locales/en.yml`: `public.refunds.title: "Refund Policy"`;
  `application.footer.refunds: "Refunds"` (label used by Task 7).
- New `app/views/public/refunds.html.erb`: meta title, renders
  `public/legal_page` with `title: t(".title")` and a hardcoded
  `updated: Date.new(<today>)`, then the copy inline. Starts with the legal
  AIDEV-NOTE comment (see Prerequisites). Sections per the design outline:
  How to cancel (Billing settings; any parent) · What happens (Premium until
  end of paid period, then Free; nothing deleted) · No refunds or credits for
  unused time or partial periods; yearly → monthly at renewal, no proration ·
  Ends immediately with no refund (cancel while past due; deleting the family)
  · Exceptions (duplicate charges / billing errors refunded if reported within
  **30 days**; otherwise at our discretion; we comply where law requires) ·
  Contact (`mail_to Jumpstart.config.support_email`). Link "Terms of Service"
  to `terms_path` where it says refunds are part of the Terms.

**NOT in scope:**

- Linking to `/refunds` from anywhere else (Tasks 7–9). Agreement entry.

**Build order:**

1. **Test:** `test/integration/public_test.rb`:
   - "refund policy is public and explains cancellation" — signed out,
     `get refunds_path`, assert success, `h1` "Refund Policy", body includes
     "Last updated", "30 days", support email, and an `a[href='#{terms_path}']`.
2. **Implement:** route, action, locale keys, view.
3. **Verify:** `bin/rails test test/integration/public_test.rb`
4. **Checkpoint:** When done, run **review-changes-mini** for Checkpoint 1
   (Tasks 1–3). If Checkpoint 1's tasks were executed as a parallel batch, the
   master runs this review once the whole batch returns instead. Either way it
   runs exactly once, after all of Tasks 1–3 are done.

---

### Task 4 [Clone]: Terms of Service copy

**Skills:** write-tests
**Reference:** `docs/designs/legal-and-about-pages.md` → "Terms of Service"
(17 sections — follow it exactly, in order); `docs/product/product-brief.md`;
"Facts every task should know" above

**In scope:**

- Replace the entire contents of
  `app/views/users/agreements/_terms_of_service.html.erb` (the Jumpstart
  suggestions comment goes) with: the legal AIDEV-NOTE comment, then 17
  `<section>`s, one `<h2>` each, matching the outline's headings and points.
- Operating party "Cove"; address/email from `Jumpstart.config` (use
  `simple_format(Jumpstart.config.business_address)` or `safe_join(... split("\n"), tag.br)`).
- Section 7 links to `refunds_path`. Section 15: $50 / prior 12 months cap.
  Section 16: Utah law, Utah County courts, small claims allowed, no
  arbitration. Section 6: "reasonable use", no number.

**NOT in scope:**

- Layout, title, date (Task 2). Privacy copy. Any other file except the test.

**Build order:**

1. **Test:** new `test/integration/terms_page_test.rb`:
   "terms explain billing, refunds, AI, and governing law" — `get terms_path`;
   assert `h2` count is 17; body includes "Utah", "$50", support email,
   "307 N 990 E"; `a[href='#{refunds_path}']` present; does NOT include
   "Some suggestions to help create"; does NOT include the numeric Premium
   cap (assert `assert_no_match /\b\d+ students\b/`).
2. **Implement:** the partial.
3. **Verify:** `bin/rails test test/integration/terms_page_test.rb test/integration/public_test.rb`

---

### Task 5 [Clone]: Privacy Policy rewrite

**Skills:** write-tests
**Reference:** `docs/designs/legal-and-about-pages.md` → "Privacy Policy"
(13 sections); current `app/views/users/agreements/_privacy_policy.html.erb`
(keep its good sentences); existing privacy test in
`test/integration/public_test.rb` ("privacy policy explains OAuth data…")

**In scope:**

- Rewrite `app/views/users/agreements/_privacy_policy.html.erb`: legal
  AIDEV-NOTE comment, then 13 `<section>`/`<h2>` sections per the outline.
- Must include: a prominent **Children's information** section; Google data
  section naming name/email/profile photo and stating compliance with the
  "Google API Services User Data Policy" (link to
  `https://developers.google.com/terms/api-services-user-data-policy`,
  `target: "_blank"`); sharing section naming Stripe, **Loops (all account and
  billing emails, plus marketing if opted in)**, Honeybadger, Render, and the
  bold "never sold or shared for targeted advertising" line; cookies =
  essential only.
- Update the existing privacy test in `test/integration/public_test.rb` to the
  new headings (update, don't delete).

**NOT in scope:**

- Layout/date (Task 2). Terms copy. Naming AI providers (not launched).

**Build order:**

1. **Test:** update "privacy policy explains…" test in
   `test/integration/public_test.rb`: assert `h2` texts "Children's
   information" and the Google section heading you chose; body includes
   "Stripe", "Loops", "Honeybadger", "Render", "Google API Services User Data
   Policy", support email; Loops sentence mentions account emails (assert
   body includes the exact Loops sentence you write); no Jumpstart
   suggestions text.
2. **Implement:** the partial.
3. **Verify:** `bin/rails test test/integration/public_test.rb`

---

### Task 6 [Clone]: About page copy

**Skills:** write-tests
**Reference:** `docs/designs/legal-and-about-pages.md` → "About";
`config/locales/en.yml` `public.index.value_points` (mirror these three
points, don't invent features); `app/views/public/_legal_page.html.erb`
(from Task 2)

**In scope:**

- Rewrite `app/views/public/about.html.erb`: meta title, render
  `public/legal_page` with `title: t(".title")`, `updated: nil` (no date
  line); ~4 short sections (What Cove is · What it helps with · What we
  believe · Who it's for) in company voice; ends "Questions? Email
  <mail_to support_email>."
- Prose lives in the view (not `en.yml`), consistent with the legal pages.

**NOT in scope:**

- Changing `public.about.title` or the navbar/layout. Images or CTAs.

**Build order:**

1. **Test:** new `test/integration/about_page_test.rb`: "about page tells
   families what Cove is" — signed out `get about_path`; assert success, `h1`
   `I18n.t("public.about.title")`, at least 4 `h2`s, `a[href='mailto:support@covehomeschool.com']`,
   body does NOT include "Last updated". Also keep existing about tests in
   `public_test.rb` passing (navbar border).
2. **Implement:** the view.
3. **Verify:** `bin/rails test test/integration/about_page_test.rb test/integration/public_test.rb`
4. **Checkpoint:** When done, run **review-changes-mini** for Checkpoint 2
   (Tasks 4–6), including a copy check against `docs/product/product-brief.md`.
   Tasks 4–6 are expected to run as a parallel batch — in that case the
   master runs this review once the whole batch returns, not the task itself.
   Either way it runs exactly once, after all of Tasks 4–6 are done.

---

### Task 7 [Clone]: Refunds link in footer and sidebar account menu

**Skills:** write-tests
**Reference:** `app/views/application/_footer.html.erb`,
`app/views/application/_sidebar_account_menu.html.erb` (Privacy/Terms links
near the bottom), `test/system/app_shell_system_test.rb:179` (footer link
assertions)

**In scope:**

- Footer: add `<li>` Refunds link (`t(".refunds")`, `refunds_path`,
  `footer_link_classes`) directly after Terms.
- Sidebar account menu: add `link_to t("application.footer.refunds"), refunds_path, class: "hover:underline"`
  after Terms.

**NOT in scope:**

- Locale key (already added in Task 3). Reordering other links.

**Build order:**

1. **Test:** `test/integration/public_test.rb` — "footer links to the refund
   policy": signed out `get about_path`, assert `footer a[href='#{refunds_path}']`
   text "Refunds". Signed-in: `sign_in users(:one)`, `get user_root_path`,
   assert `a[href='#{refunds_path}']` present (the account menu renders more
   than once — assert presence, not an exact count). Add a matching
   `assert_link` line next to `test/system/app_shell_system_test.rb:181`.
2. **Implement:** both partials.
3. **Verify:** `bin/rails test test/integration/public_test.rb` then
   `bin/rails test:system test/system/app_shell_system_test.rb`

---

### Task 8 [Master]: Refund and terms links on pricing and checkout

**Skills:** write-tests
**Reference:** `app/views/pricing/show.html.erb:11`,
`app/views/checkouts/show.html.erb:6,97,98`, `config/locales/en.yml`
`pricing.show.no_refunds`, `test/system/pricing_and_billing_system_test.rb:164`
("refund policy appears on pricing, checkout, and cancellation"),
`app/views/devise/registrations/new.html.erb:69` (pattern for a `_html` key
with a `link_to` interpolation)

**In scope:**

- Rename `pricing.show.no_refunds` → `no_refunds_html`:
  `"Cancel anytime. You keep Premium until the end of the period you have paid for. No refunds are issued for unused time. %{link}"`
  plus `refund_policy: "See our refund policy."`.
- Pricing: `t(".no_refunds_html", link: link_to(t(".refund_policy"), refunds_path, class: "underline text-foreground hover:text-primary"))`.
- Checkout (both spots, lines 6 and 98): same key via `t("pricing.show...")`
  with `target: "_blank"` on the link.
- Checkout consent line (97): move to a new key
  `checkouts.show.consent_html` with `%{app}` and `%{terms}`; `terms` =
  `link_to("terms", terms_path, target: "_blank", class: ...)`.
- Grep for every remaining `no_refunds` caller and update it.

**NOT in scope:**

- Cancel page / family deletion (Task 9). Engine views under `lib/jumpstart`.

**Build order:**

1. **Test:** update the system test at
   `test/system/pricing_and_billing_system_test.rb:164`: replace the
   `no_refunds` `assert_text` lines with `assert_link "See our refund policy.", href: refunds_path`
   on pricing and checkout; on checkout also assert
   `assert_selector "a[href='#{refunds_path}'][target='_blank']"` and
   `assert_selector "a[href='#{terms_path}'][target='_blank']"`. If
   `test/integration/checkouts_test.rb` can render checkout with the
   existing Stripe stub, add the same href/target assertions there (faster).
2. **Implement:** locale keys, three view spots.
3. **Verify:** `grep -rn "no_refunds\b\|no_refunds\"" app test` returns no old
   key; `bin/rails test test/integration/checkouts_test.rb test/integration/billing_policy_copy_test.rb`;
   then `bin/rails test:system test/system/pricing_and_billing_system_test.rb`

---

### Task 9 [Master]: Refund links on cancel page and family-deletion notice

**Skills:** write-tests
**Reference:** `app/helpers/account_deletion_helper.rb`,
`test/helpers/account_deletion_helper_test.rb`,
`app/views/billing/subscriptions/cancels/show.html.erb:17`,
`app/javascript/src/confirm.js:20-34` (the confirm dialog inserts
`turbo_confirm_description` into `innerHTML`, so a link in it renders),
`app/views/accounts/show.html.erb:96`, `app/views/accounts/edit.html.erb:17`

**In scope:**

- `en.yml` `billing.subscriptions.cancels.show`: rename
  `active_until_no_refund` → `active_until_no_refund_html` and
  `active_until_no_refund_undated` → `active_until_no_refund_undated_html`,
  each ending `%{link}`; add `refund_policy: "Refund policy"`.
- `cancellation_end_notice`: pass `link: link_to(t("billing.subscriptions.cancels.show.refund_policy"), refunds_path, class: "underline")`.
  `cancel_immediately` unchanged (design scope covers only the two
  `active_until` keys).
- Family-deletion notice: `accounts.deletion.paid_description` →
  `paid_description_html` ending `%{link}`; `family_deletion_description`
  passes the same refund link. (The design's table pointed this row at
  `cancellation_end_notice`, but the family-deletion notice is actually
  `family_deletion_description` — that's what this changes.)
- Update every caller/test of the renamed keys (system test lines 177/181,
  helper test line 7/45).

**NOT in scope:**

- `devise.registrations.edit.cancel_my_account_paid_description` (login
  deletion) — not in the design. Changing `confirm.js`.

**Build order:**

1. **Test:** `test/helpers/account_deletion_helper_test.rb` — update the
   paid family-deletion and active-until assertions to expect the new `_html`
   output and assert it includes `href="/refunds"`; add an undated case.
   Update `test/system/pricing_and_billing_system_test.rb` cancel-page
   assertions to `assert_link "Refund policy", href: refunds_path`.
2. **Implement:** locale keys + helper.
3. **Verify:** `grep -rn "active_until_no_refund\b\|paid_description\"" app test`
   shows no stale callers; `bin/rails test test/helpers/account_deletion_helper_test.rb test/integration/billing_policy_copy_test.rb`;
   then `bin/rails test:system test/system/pricing_and_billing_system_test.rb`
4. **Checkpoint:** When done, run **review-changes-mini** for Checkpoint 3
   (Tasks 7–9). If Checkpoint 3's tasks were executed as a parallel batch, the
   master runs this review once the whole batch returns instead. Either way it
   runs exactly once, after all of Tasks 7–9 are done.

---

### Task 10 [Master]: Screenshot check, final dates, product-brief update

**Skills:** run (screenshots)
**Reference:** `docs/product/product-brief.md` "Open questions" (Terms/refund
policy line ~88)

**In scope:**

- Start the app; screenshot `/terms`, `/privacy`, `/refunds`, `/about`
  (desktop + one mobile width) into `.context/`. Confirm H1/H2 render in the
  serif at weight 400 (no faux bold), "Last updated" shows on the three legal
  pages only, nothing overflows. If headings look bold, check compiled CSS
  for `prose-headings:font-normal` (and `bin/rails assets:clobber` if stale
  `public/assets/` is served).
- Confirm `updated:` in `config/initializers/agreements.rb` and the Refunds
  hardcoded date both equal the actual ship date; adjust if needed.
- `docs/product/product-brief.md`: remove/resolve the "Terms of Service and
  refund policy pages" open question, noting the remaining manual Stripe and
  Google Console steps from the design's Deferred list.

**NOT in scope:**

- Any visual redesign. The Stripe Dashboard / Google Console steps
  themselves (Jordan, post-merge).

**Build order:**

1. **Test:** none new (verification task); full suite must pass.
2. **Implement:** date fixes if needed, product-brief edit.
3. **Verify:** `bin/rails test` and `bin/rails test:system` (sequentially),
   screenshots attached in the report.
4. **Checkpoint:** When done, run **review-changes-mini** for Checkpoint 4
   (Task 10). It runs exactly once, after Task 10 is done.

## Task Dependencies

- Task 2 depends on Task 1 (needs agreements configured for the date line).
- Task 3 depends on Task 2 (uses `public/_legal_page`).
- Tasks 4, 5, 6 depend on Tasks 2–3 and can run **in parallel** (separate
  files; only Task 5 edits `public_test.rb`, Tasks 4/6 use new test files).
- Task 7 depends on Task 3 (`refunds_path`, `footer.refunds` key). Run it on
  its own — Tasks 7–9 all run system tests, which must not run concurrently.
- Task 8 and Task 9 both edit `config/locales/en.yml` and the same system
  test — run **sequentially** (8 then 9), after Task 3.
- Task 10 runs last.
