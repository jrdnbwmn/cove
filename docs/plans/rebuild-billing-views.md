> Ticket: COV-15
> Branch: feature/cov-15-rebuild-billing-views

# Plan: Rebuild account + billing (Pay) views with design-system components

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | `PlanCardComponent` (new, composed from `CardComponent`) + preview + `/update-catalog` | Master | ✅ |
| 2 | Flow A pattern-setter: `account/passwords/edit` + `api_tokens/{_form,new,edit}` | Master | ✅ |
| 3 | `api_tokens/{index,show}` (table + badge + clipboard) | Clone | ✅ |
| 4 | Flow B forms: `accounts/{_form,new,edit}` (avatar/domain/subdomain guards) | Master | ✅ |
| 5 | `accounts/{index,show}` (members table, avatars, pagination, delete/transfer) | Clone | ✅ |
| 6 | `account_users/{_form,edit}` (role checkboxes) + `accounts/transfers/_form` | Clone | ✅ |
| 7 | `accounts/account_invitations/{new,edit}` + `account_invitations/show` | Clone | |
| 8 | Flow C: `pricing/show` + retire `_plan` → `PlanCardComponent` (toggle) | Master | |
| 9 | `checkouts/{show,_testimonial}` + `forms/_stripe` (byte-identical Stripe div) | Clone | |
| 10 | Flow D: `billing/{show,_email,_info,_charges}` (dashboard + charges table) | Master | |
| 11 | `billing/subscriptions/{_subscription,_summary,edit}` (status badges + plan change) | Master | |
| 12 | `cancels/resumes/pauses/upcomings/show` (4 confirm pages) | Clone | |
| 13 | Flow E: `payment_methods/new` + `forms/_fake_processor` (system-test-driven) | Master | |
| 14 | Extend integration tests + system tests + selector migration + full gate | Master | |

## Prerequisites

- Design: `docs/designs/rebuild-billing-views.md`
- Prototype: None (visual design = existing Jumpstart billing/account layout, restyled onto DS components + tokens)
- Feature branch `feature/cov-15-rebuild-billing-views` exists (current branch) ✓
- All DS components exist in catalog (`CardComponent`, `TableComponent`, `BadgeComponent`, `AvatarComponent`, `AlertComponent`, `ButtonComponent`, `FormFieldComponent`, `CheckboxComponent`, `PasswordComponent`, `PaginationComponent`). Only `PlanCardComponent` is new (Task 1).
- Config facts: `payment_processors: ["stripe"]`, `omniauth_providers: []`; tests use Pay `fake_processor`.

## Global rules for every task

- **Copy, don't edit the engine.** Create new files under `app/views/…`; leave `lib/jumpstart/…` pristine. App views win over engine views. View paths stay identical, so lazy i18n (`t('.…')`) is unchanged — **no locale edits**.
- **Environment:** run all Rails/bin commands via `mise exec --` (e.g. `mise exec -- bin/rails test …`). Rails Blocks operations go through the **`rails-blocks-cli` skill, never the MCP**.
- **ZERO behavior change.** This is the riskiest ticket. Preserve verbatim every field name/param, route/url helper, redirect, `turbo_confirm`/`turbo_confirm_description`, Stimulus data attrs & controller names, `content_for :sidebar` → `_account_navbar`, `Current.meta_tags`, Pundit/`account_admin?` guards, `pagy`, and every `Jumpstart.config.*` / `hotwire_native_app?` branch. **If ANY behavior is ambiguous or a test can't pass without changing logic → STOP and ask.** No "looks fine."
- **Field-wrapping recipe (from COV-14):** wrap the raw `f.*_field` through `FormFieldComponent`'s `with_input` slot so all original options survive; pass `error: model.errors[:attr].first` (nil-safe). Passwords → `PasswordComponent` (regenerates its own input — map `name:`/`autocomplete:`/`placeholder:`/`error:` explicitly; if a needed option like `autofocus`/`required` isn't exposed, STOP and ask). Submits → `ButtonComponent.new(text:, type: "submit")` — renders `<button type=submit>`, **not** `input[name=commit]`.
- **Errors render two ways:** per-field via each component's `error:` AND the summary via `app/views/application/_error_messages.html.erb` (already rebuilt in COV-14 → `AlertComponent variant:error`). Keep both.
- Route accents through tokens (`bg-primary`/`text-primary-foreground`, `text-muted`, `border-(--divider-color)`); **no** `form-control`/`btn`/`banner`/`alert` Jumpstart classes remain in rebuilt views. `# AIDEV-NOTE:` for non-obvious decisions.
- **`button_to` destructive actions** (delete/transfer/cancel/pause/resume): keep the `button_to` element, method, and all `data: { turbo_confirm: …, turbo_confirm_description: … }` verbatim — restyle only, via `ButtonComponent`'s destructive variant or class pass-through.

## Tasks

### Task 1 [Master]: `PlanCardComponent` (new, composed from `CardComponent`)

**Skills:** create-component, style-ui, write-tests
**Reference:** `lib/jumpstart/app/views/billing/subscriptions/_plan.html.erb`; its 4 call sites (`pricing/show` ×2, `billing/subscriptions/edit` ×2) which render via `render layout: "billing/subscriptions/plan" do … end` with a **yielded action block**; catalog `CardComponent`, `ButtonComponent`.

**In scope:**

- Build `PlanCardComponent` composed **from** `CardComponent` (per style-ui "compose, don't fork"). Args: `plan:` (a Pay plan object). Renders: name (`plan.name`), description, price block — reproducing the existing `_plan` logic exactly: `plan.contact_url?` → `t(".contact_us_price")`; else `pay_amount_to_currency(plan, strip_insignificant_zeros: true)` + optional `plan.unit_label` + `formatted_plan_interval(plan)`; and the `plan.features` checklist (checkmark svg + feature text).
- Expose an **actions slot** (e.g. `with_actions` / a yielded block region) that renders where the current `<%= yield %>` sits — call sites pass different buttons (subscribe / current-plan / change-to). It MUST render the caller's block content unchanged.
- The i18n key `t(".contact_us_price")` currently resolves under the `_plan` partial's lazy scope — resolve it to the explicit absolute key so the component renders identically (verify the key path; if unclear, STOP and ask).
- Add a `PlanCardComponentPreview` (Lookbook) covering: priced plan w/ features, contact-us plan, plan w/ `unit_label`. Run `/update-catalog`.

**NOT in scope:** any billing/pricing *view* (Tasks 8 & 11 wire this in); deleting `_plan` (Task 8 does that); DB.

**Caveats:** ⚠️ The action region is a **layout yield today** — the component must accept a block/slot, or the 4 call sites can't pass their distinct buttons. Confirm the slot renders arbitrary caller markup before finishing. ⚠️ Keep the checkmark svg and muted-text styling token-based, not hardcoded neutrals.

**Build order:**

1. **Test:** component test / preview render asserting name, formatted price, features list, contact-us branch, and that an actions block is yielded.
2. **Implement:** the component + preview.
3. **Verify:** `mise exec -- bin/rails test test/components/plan_card_component_test.rb` (or the component test path); `/update-catalog`.
4. **Review:** run review-changes before proceeding.

### Task 2 [Master]: Flow A pattern-setter — `account/passwords/edit` + `api_tokens/{_form,new,edit}`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/account/passwords/edit.html.erb`, `lib/jumpstart/app/views/api_tokens/{_form,new,edit}.html.erb`; COV-14's `app/views/devise/passwords/edit.html.erb` for the two-password recipe.

**In scope:**

- `app/views/account/passwords/edit.html.erb`: current/new/confirm passwords → `PasswordComponent` (correct `autocomplete` per field); submit → `ButtonComponent`. Keep form url/method + `error_messages` summary.
- `app/views/api_tokens/_form.html.erb`: token attributes (name, and any expiry/scope fields present) → `FormFieldComponent`/appropriate DS control; submit → `ButtonComponent`. Preserve exact param names.
- `app/views/api_tokens/{new,edit}.html.erb`: page chrome + `render "form"`, `Current.meta_tags`, headings.

**NOT in scope:** `api_tokens/{index,show}` (Task 3); token generation/controller logic.

**Caveats:** This sets the form recipe for the whole ticket — get FormField/Password/Button clean. Preserve every `api_token` param name exactly (drives API auth).

**Build order:**

1. **Implement:** the four views.
2. **Verify:** `mise exec -- bin/rails test` (api_tokens controller/integration coverage stays green).
3. **Review:** run review-changes before proceeding.

### Task 3 [Clone]: `api_tokens/{index,show}` (table + badge + clipboard)

**Skills:** style-ui
**Reference:** Task 2's rebuilt api_tokens forms; `lib/jumpstart/app/views/api_tokens/{index,show}.html.erb`; catalog `TableComponent`, `BadgeComponent`, `ButtonComponent`.

**In scope:**

- `app/views/api_tokens/index.html.erb`: token list `<table>` → `TableComponent` (row/column slots); status/last-used or similar tags → `BadgeComponent`; row actions (edit/revoke) preserve `button_to`/`turbo_confirm` verbatim; "New token" → `ButtonComponent`. Empty state text kept.
- `app/views/api_tokens/show.html.erb`: keep the **clipboard** Stimulus wiring (`data-controller="clipboard"`, targets, copy button) verbatim — restyle chrome only.

**NOT in scope:** clipboard controller JS; token forms (Task 2).

**Caveats:** ⚠️ Do not alter the `clipboard` controller data attributes — the copy-to-clipboard is behavior. `DropdownComponent#with_item_link` has no `data_turbo` — irrelevant unless you add a dropdown (don't).

**Build order:**

1. **Implement:** the two views.
2. **Verify:** `mise exec -- bin/rails test`.
3. **Review:** run review-changes before proceeding.

### Task 4 [Master]: Flow B forms — `accounts/{_form,new,edit}`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/accounts/{_form,new,edit}.html.erb`; catalog `FormFieldComponent`, `ButtonComponent`, `AvatarComponent`.

**In scope:**

- `app/views/accounts/_form.html.erb`: `name` → `FormFieldComponent`(`f.text_field`); `domain`/`subdomain` → `FormFieldComponent` **preserving every multitenancy guard/condition** around them exactly; `avatar` → `FormFieldComponent`(`f.file_field`) keeping the avatar preview `image_tag`/`account_avatar` and the **accept list** verbatim; submit → `ButtonComponent`. Keep `error_messages`.
- `app/views/accounts/{new,edit}.html.erb`: chrome, `content_for :sidebar` if present, `Current.meta_tags`, `render "form"`.

**NOT in scope:** `accounts/{index,show}` (Task 5); `account_users`/invitations/transfers; account model logic.

**Caveats:** ⚠️ `subdomain`/`domain` fields are gated by `Jumpstart.config` / multitenancy conditionals — reproduce each conditional exactly; do not render a field the config would hide. Preserve the file-field `accept:` list character-for-character.

**Build order:**

1. **Implement:** the three views.
2. **Verify:** `mise exec -- bin/rails test test/controllers/accounts_controller_test.rb` (or the accounts integration test).
3. **Review:** run review-changes before proceeding.

### Task 5 [Clone]: `accounts/{index,show}` (members table, avatars, pagination)

**Skills:** style-ui
**Reference:** Task 4's forms; `lib/jumpstart/app/views/accounts/{index,show}.html.erb`; catalog `TableComponent`, `AvatarComponent`, `BadgeComponent`, `PaginationComponent`, `ButtonComponent`.

**In scope:**

- `app/views/accounts/index.html.erb`: accounts `<table>` (`@accounts.sorted`) → `TableComponent`; `account_avatar` kept; "Create" → `ButtonComponent` (keep `Jumpstart.config.team_accounts?` guard); `Current.meta_tags` + sidebar kept.
- `app/views/accounts/show.html.erb`: members table → `TableComponent` with `AvatarComponent` + role `BadgeComponent`; pending-invite rows → "awaiting response" `BadgeComponent` + resend/copy-link/edit actions; pagination only when `@pagy.last > 1` → `PaginationComponent`; delete/transfer/invite → `ButtonComponent` preserving `button_to`+`turbo_confirm*`. Edge states: **personal account** → info `AlertComponent`, no members table/delete/invite/transfer; account **owner** row → admin checkbox disabled + not removable.

**NOT in scope:** `account_users` edit/form (Task 6); invitation new/edit (Task 7); pagination Stimulus.

**Caveats:** ⚠️ Reproduce the personal-vs-team and owner-vs-member conditionals exactly — they gate destructive actions. `pagy` variable names/guards unchanged.

**Build order:**

1. **Implement:** the two views.
2. **Verify:** `mise exec -- bin/rails test test/controllers/accounts_controller_test.rb` + `account_users`/`account_invitations` integration tests.
3. **Review:** run review-changes before proceeding.

### Task 6 [Clone]: `account_users/{_form,edit}` + `accounts/transfers/_form`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/account_users/{_form,edit}.html.erb`, `lib/jumpstart/app/views/accounts/transfers/_form.html.erb`; catalog `CheckboxComponent`, `FormFieldComponent`, `ButtonComponent`.

**In scope:**

- `account_users/_form.html.erb`: role checkboxes → `CheckboxComponent` iterating `AccountUser::ROLES` with `form.check_box role` semantics preserved (same name array structure); submit → `ButtonComponent`.
- `account_users/edit.html.erb`: chrome + `render "form"`.
- `accounts/transfers/_form.html.erb`: transfer target field(s) → appropriate DS control; the transfer submit keeps `button_to`/`turbo_confirm` verbatim.

**NOT in scope:** `accounts/show` roster (Task 5); account_user/transfer controller logic.

**Caveats:** ⚠️ `CheckboxComponent` emits no companion hidden `"0"` — confirm the roles param still round-trips as the controller expects (Rails `check_box` normally pairs a hidden field). If dropping the hidden field would change submitted params, STOP and ask. Owner's admin checkbox stays disabled.

**Build order:**

1. **Implement:** the three files.
2. **Verify:** `mise exec -- bin/rails test test/controllers/account_users_test.rb` (or integration equivalent).
3. **Review:** run review-changes before proceeding.

### Task 7 [Clone]: `accounts/account_invitations/{new,edit}` + `account_invitations/show`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/accounts/account_invitations/{new,edit}.html.erb`, `lib/jumpstart/app/views/account_invitations/show.html.erb`; catalog `FormFieldComponent`, `ButtonComponent`, `AlertComponent`, `AvatarComponent`.

**In scope:**

- invitation `new`/`edit`: `name`/`email` → `FormFieldComponent`; submit → `ButtonComponent`; keep `error_messages`.
- `account_invitations/show.html.erb`: the accept/decline landing — inviter/account context (avatar + text), accept → `ButtonComponent`, restyle onto DS + tokens; preserve every route/param.

**NOT in scope:** roster/pending list (Task 5); invitation controller/mailer logic.

**Build order:**

1. **Implement:** the three views.
2. **Verify:** `mise exec -- bin/rails test test/controllers/account_invitations_test.rb` (or integration equivalent).
3. **Review:** run review-changes before proceeding.

### Task 8 [Master]: Flow C — `pricing/show` + retire `_plan` → `PlanCardComponent`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/pricing/show.html.erb` (renders `_plan` via `render layout:` ×2 for monthly/yearly); Task 1's `PlanCardComponent`.

**In scope:**

- `app/views/pricing/show.html.erb`: replace each `render layout: "billing/subscriptions/plan" do … end` with `render PlanCardComponent.new(plan: plan) do |c| … end` (or its actions slot), passing the **same** action block (subscribe/contact link) unchanged. Preserve the **`pricing` + `toggle` Stimulus** wiring and the monthly/yearly toggle exactly (data-controllers, targets, both plan lists).
- Create `app/views/billing/subscriptions/_plan.html.erb` as a thin shim **only if** any un-migrated caller still renders it; otherwise leave the engine `_plan` in place (it stops rendering once all callers use the component). Prefer: migrate all 4 callers (here + Task 11) and add **no** app-level `_plan`. Note in the task if a caller remains.

**NOT in scope:** `checkouts/*` (Task 9); `billing/subscriptions/edit` plan cards (Task 11); toggle Stimulus JS.

**Caveats:** ⚠️ The monthly/yearly toggle and `pricing` controller are behavior — preserve target names and the two plan-collection loops. ⚠️ Coordinate with Task 11 so **all 4** `_plan` call sites move to `PlanCardComponent`; if the engine `_plan` still has a caller after both, keep it. (Task 8 sets the call pattern → do before Task 11.)

**Build order:**

1. **Implement:** `pricing/show`.
2. **Verify:** `mise exec -- bin/rails test`; browser-check the toggle in Task 14.
3. **Review:** run review-changes before proceeding.

### Task 9 [Clone]: `checkouts/{show,_testimonial}` + `forms/_stripe`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/checkouts/{show,_testimonial}.html.erb`, `lib/jumpstart/app/views/checkouts/forms/_stripe.html.erb`.

**In scope:**

- `checkouts/show.html.erb`: restyle page chrome (heading, layout, the plan-features/summary column) onto DS + tokens; keep the `render "checkouts/forms/#{…}"` processor dispatch and any `Jumpstart.config`/plan context exactly.
- `checkouts/_testimonial.html.erb`: restyle onto tokens (`AvatarComponent`/`CardComponent` if it fits the existing layout).
- `checkouts/forms/_stripe.html.erb`: **byte-identical** — the `stripe--embedded-checkout` controller div + `public_key_value` / `client_secret_value` data attrs are copied verbatim into `app/views/…`. Do NOT restyle inside it.

**NOT in scope:** `_braintree`/`_paddle_billing`/`_paddle_classic`/`_paypal` forms (never render — Stripe-only config, not touched); Stripe controller JS; pricing (Task 8).

**Caveats:** ⚠️ `_stripe` is an opaque iframe host — any change to its data attrs breaks checkout. Copy it exactly; only the surrounding page is restyled.

**Build order:**

1. **Implement:** the three files.
2. **Verify:** `mise exec -- bin/rails test`.
3. **Review:** run review-changes before proceeding.

### Task 10 [Master]: Flow D — `billing/{show,_email,_info,_charges}`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/billing/{show,_email,_info,_charges}.html.erb`; catalog `TableComponent`, `ButtonComponent`, `FormFieldComponent`, `AlertComponent`.

**In scope:**

- `billing/show.html.erb`: dashboard chrome; renders `_subscription`/`_summary`/`_charges`/`_email`/`_info`; **non-admin → "contact admin"** message with no subscription UI (preserve the `account_admin?` guard exactly); sidebar + `Current.meta_tags` kept.
- `billing/_charges.html.erb`: charges `<table>` (`current_account.pay_charges.sorted`) → `TableComponent` (Date/Amount/Invoice/Receipt columns); invoice/receipt **PDF `link_to … format: :pdf, target: :_blank`** kept verbatim (the svg icons may become `ButtonComponent` icon links or stay as-is); empty → empty-state text.
- `billing/_info.html.erb`: extra-billing-info `form_with model: current_account, url: billing_path` + `text_area :extra_billing_info` → `FormFieldComponent` wrapping the raw `text_area`; submit → `ButtonComponent`. Params preserved.
- `billing/_email.html.erb`: restyle onto DS.

**NOT in scope:** `_subscription`/`_summary`/`edit` (Task 11); cancel/pause/resume pages (Task 12); payment method (Task 13); Pay model logic.

**Caveats:** ⚠️ Preserve the PDF link URLs (`invoice_billing_charge_path`/`receipt_...`, `format: :pdf`, `target: :_blank`) exactly. ⚠️ The non-admin guard must render the "contact admin" branch unchanged.

**Build order:**

1. **Implement:** the four files.
2. **Verify:** `mise exec -- bin/rails test`.
3. **Review:** run review-changes before proceeding.

### Task 11 [Master]: `billing/subscriptions/{_subscription,_summary,edit}`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/billing/subscriptions/{_subscription,_summary,edit}.html.erb`; Task 1's `PlanCardComponent`; catalog `BadgeComponent`, `AlertComponent`, `ButtonComponent`.

**In scope:**

- `_subscription.html.erb`: map every state to a `BadgeComponent` + its action set exactly — `free_trial`, `canceled`, `incomplete`, `past_due` (**red** → `variant: :error`/danger), `unpaid` (**red**), `paused`, `on_grace_period`; trial/paused/past-due explanatory lines → keep (banners → `AlertComponent`); `metered?` / `plan&.charge_per_unit?` → usage/upcoming links preserved; **no subscription → "choose plan" empty state**. Replace the `badge` helper calls and hardcoded `bg-red-100 text-red-800` with `BadgeComponent` variants.
- `_summary.html.erb`: restyle onto DS/tokens.
- `edit.html.erb` (change plan): the 2 `render layout: "billing/subscriptions/plan"` monthly/yearly loops → `PlanCardComponent` (matching Task 8's call pattern); each plan's change action keeps `form_with url: billing_subscription_url, method: :patch` + `hidden_field :plan` (`plan.to_param`) + `turbo_confirm` verbatim.

**NOT in scope:** cancel/pause/resume/upcoming pages (Task 12); `billing/show`/`_charges` (Task 10).

**Caveats:** ⚠️ Highest-risk view — every subscription state must keep its exact badge + button set; walk each `elsif` branch. ⚠️ Change-plan form params (`plan` hidden field via `plan.to_param`, PATCH to `billing_subscription_url`) are the live plan-switch — preserve exactly. Coordinate with Task 8 on the `PlanCardComponent` actions-slot call shape.

**Build order:**

1. **Implement:** the three files.
2. **Verify:** `mise exec -- bin/rails test test/integration/subscriptions_test.rb` (or `test/controllers/...subscriptions`).
3. **Review:** run review-changes before proceeding.

### Task 12 [Clone]: `cancels/resumes/pauses/upcomings/show` (4 confirm pages)

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/billing/subscriptions/{cancels,resumes,pauses,upcomings}/show.html.erb`; catalog `ButtonComponent`, `AlertComponent`, `CardComponent`.

**In scope:**

- All four `show` pages: restyle chrome onto DS + tokens. cancel/pause/resume actions keep `button_to` (`:delete`/`:post`) + `turbo_confirm` verbatim; `upcomings/show` (usage/upcoming invoice) restyle only — preserve any Pay data rendering.

**NOT in scope:** `_subscription` state logic (Task 11); Pay controller logic.

**Build order:**

1. **Implement:** the four views.
2. **Verify:** `mise exec -- bin/rails test`.
3. **Review:** run review-changes before proceeding.

### Task 13 [Master]: Flow E — `payment_methods/new` + `forms/_fake_processor`

**Skills:** style-ui
**Reference:** `lib/jumpstart/app/views/billing/subscriptions/payment_methods/new.html.erb`, `.../payment_methods/forms/_fake_processor.html.erb`; `test/system/*` that drives fake_processor.

**In scope:**

- `payment_methods/new.html.erb`: page chrome → DS; keep the processor-form dispatch (`render "…/forms/#{…}"`) and Stripe update-card wiring exactly.
- `payment_methods/forms/_fake_processor.html.erb`: the `banner banner-info` info box → `AlertComponent variant:info` (message `t ".message"` kept). **Preserve the form action/params** the system tests submit — this is the form the subscription system tests drive.

**NOT in scope:** `_braintree`/`_paypal` payment-method forms (never render — not touched); Stripe card JS; Pay logic.

**Caveats:** ⚠️ System tests submit this form (`set_payment_processor :fake_processor, allow_fake: true`). If restyling changes the submit control from `input[name=commit]` to `<button type=submit>`, the driving selector must be migrated in Task 14 — flag the exact selector here.

**Build order:**

1. **Implement:** the two files.
2. **Verify:** `mise exec -- bin/rails test`.
3. **Review:** run review-changes before proceeding.

### Task 14 [Master]: Tests, system-test selector migration, and full gate

**Skills:** write-tests
**Reference:** `test/controllers/accounts_controller_test.rb`, `account_users_test`, `account_invitations_test`, `test/integration/subscriptions_test.rb`, `test/system/account_system_test.rb`.

**In scope:**

- **Selector migration:** update every system-test selector matching `input[name="commit"]` / `input[name=…]` for a submit to a CSS attribute selector on `<button type=submit>` (`find("button[type=submit]").click`), per `CLAUDE.local.md` (Capybara here doesn't resolve `click_button` on `aria-label`; use CSS attribute selectors).
- **Extend integration tests** (behavior unchanged, keep green): `accounts_test`, `account_users_test`, `account_invitations_test`, `subscriptions_test`.
- **New system coverage:** subscription lifecycle happy path via `fake_processor` (pricing → subscribe → change plan → cancel → resume); one team flow (invite → member appears). WebMock blocks external HTTP; `set_payment_processor :fake_processor, allow_fake: true`.
- **Full gate:** run and show output for `mise exec -- bin/rails test` AND `mise exec -- bin/rails test:system`. Browser-verify each rebuilt flow (light/dark, mobile) via the run/verify skill.

**NOT in scope:** new product behavior; new components.

**Caveats:** Run specific system tests with the positional file arg + `-i "test name"` (not `-n`), per `CLAUDE.local.md`.

**Build order:**

1. **Test:** migrate selectors + add the new system/integration coverage.
2. **Verify:** full `test` + `test:system`, output shown; browser walkthrough.
3. **Review:** run review-changes before final commit.

## Task Dependencies

- **Task 1** (`PlanCardComponent`) blocks Tasks 8 & 11 — do it first.
- **Flow A:** Task 2 (pattern-setter) → Task 3.
- **Flow B:** Task 4 (forms, pattern-setter) → Tasks 5, 6, 7 can run in parallel (clones) once 4 lands (5 reads roster patterns; 6/7 are independent files).
- **Flow C:** Task 8 sets the `PlanCardComponent` call shape → Task 11 reuses it. Task 9 is independent of 8 (can parallel).
- **Flow D:** Task 10 and Task 12 are independent; Task 11 depends on Task 1 and should follow Task 8 (shared call pattern). 10/12 can parallel with each other.
- **Flow E:** Task 13 independent (can run any time after Task 2's recipe lands).
- **Task 14** runs last, after all views exist — it owns all system-test selector migration + new coverage + the final gate (kept in one Master pass to avoid clones fighting flaky system tests; earlier tasks verify against integration/controller tests only).
- **Commit per flow** (A/B/C/D/E) as the design specifies; one branch → one PR.
