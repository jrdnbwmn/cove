> Ticket: COV-15
> Branch: feature/cov-15-rebuild-billing-views

# Feature: Rebuild account + billing (Pay) views with design-system components

## Problem
The account settings, team/account management, and subscription/billing (Pay)
views are the last surfaces still on Jumpstart's hand-rolled markup and the old
`form-control` / `btn` / `banner` / `alert` CSS classes. After COV-12 (component
library), COV-13 (app shell), and COV-14 (auth views), these should be rebuilt on
the same DS component vocabulary + tokens. This is the **riskiest** ticket — it
touches real payment and subscription flows — so it is a strict **visual
replacement with ZERO behavior change**: every field name, param, route, redirect,
processor JS wiring, i18n key, and Pundit guard is preserved exactly.

## Approach
**Copy each engine view into `app/views/…`, then rebuild it there** on DS
components + tokens. App views win over the in-repo Jumpstart engine
(`lib/jumpstart/app/views/…`), the same override pattern COV-13/COV-14 used, so
`lib/jumpstart` stays pristine. Because view paths are unchanged, i18n lazy lookup
(`t('.…')`) is unchanged — no locale edits.

Rebuild incrementally, **one flow at a time, commit per flow**, verifying (tests +
browser) after each. One branch → **one PR**, reviewed flow-by-flow.

### Key decisions (locked in brainstorm)

1. **Stripe only.** `config/jumpstart.rb` enables only `stripe`. Rebuild only the
   views that actually render under this config. The `paddle`/`braintree`/`paypal`
   checkout and payment-method partials **are not touched** (they never render
   here). Stripe uses **embedded checkout** — a single `stripe--embedded-checkout`
   Stimulus controller.

2. **`PlanCardComponent` (new, feature-specific).** The plan card
   (`subscriptions/_plan`) renders in three places (pricing, checkout features,
   change-plan). Build one `PlanCardComponent` composed **from** `CardComponent`
   (allowed by `style-ui`), reused across all three. Gets a Lookbook preview +
   `/update-catalog`.

3. **Full account-settings scope.** In addition to billing + team management,
   `account/passwords/edit` (change password) and the `api_tokens` views
   (`index`/`new`/`edit`/`show`/`_form`) are **in scope** as account settings.

4. **Stripe embedded checkout left byte-identical.** `checkouts/forms/_stripe` is
   an opaque iframe host div carrying `public_key_value` + `client_secret_value`.
   We do not restyle inside it — only the surrounding page chrome. Its controller
   and data attributes are preserved verbatim.

5. **Errors render two ways (COV-14 pattern).** `application/_error_messages`
   summary → `AlertComponent variant:error`; per-attribute errors wired into each
   field component via `error:`.

6. **Button selector shift.** DS `ButtonComponent` renders `<button type=submit>`,
   not Rails' `input[name=commit]`, so any test selectors matching `input[name=…]`
   are updated (CSS attribute selectors per `CLAUDE.local.md`), as COV-14 did.

7. **`_account_navbar` sidebar kept rendering, not rebuilt** (same as COV-14 — the
   billing/account views `content_for :sidebar` render it as-is).

### Standing hygiene (carried from COV-12/13/14)
Self-host assets (no CDN). Lazy-register only the Stimulus controllers used. Route
accents through tokens (`bg-primary`/`text-primary-foreground`). Never `--force`
over a Jumpstart controller without approval. Tailwind v4 CSS-first via `@theme` —
never create `tailwind.config.js`. Importmap (no Node). `# AIDEV-NOTE:` for
non-obvious decisions. Run Rails/bin commands via `mise exec --`.

## Acceptance Criteria
- Every billing/account behavior works unchanged (tests + browser walkthrough):
  create/edit/delete team, switch, transfer, member roles, invite/resend/accept,
  subscribe, change plan, cancel/resume, update payment method, extra billing info,
  invoice/receipt PDF links, change password, API token CRUD.
- **No** payment controller/model logic changed — views + view-layer components only.
- Stripe embedded-checkout JS still wired; all forms submit with identical params.
- Views use DS components + tokens; no `form-control`/`btn`/`banner`/`alert`
  Jumpstart classes remain in the rebuilt views.
- `bin/rails test` and `bin/rails test:system` pass (full output shown).
- If ANY billing behavior is ambiguous or a test is hard to pass without changing
  logic → **STOP and ask**. No "looks fine" merges.

## Prototype
None. Visual design = the existing Jumpstart layout/IA, restyled onto DS components
+ tokens. Layout preserved, not redesigned.

## Data Model
No models, migrations, routes, or controller changes. The "model" here is the
**param/behavior inventory that must be preserved exactly** (see Preserved Verbatim
below). One **new view component**: `PlanCardComponent` (composed from
`CardComponent`; no DB).

## Screens / Flows
No new flows; same fields, params, redirects. Six commit-per-flow batches:

| # | Flow | Views | Component mapping |
|---|------|-------|-------------------|
| **A** | Account settings | `account/passwords/edit`; `api_tokens/{index,new,edit,show,_form}` | `PasswordComponent`, `FormFieldComponent`, `ButtonComponent`, `TableComponent`, `BadgeComponent`; clipboard preserved |
| **B** | Team management | `accounts/{index,show,new,edit,_form}`, `transfers/_form`, `account_users/{edit,_form}`, `account_invitations/{new,edit,show}` | `TableComponent`, `AvatarComponent`, `BadgeComponent`, `FormFieldComponent`, `CheckboxComponent` (roles), `PaginationComponent`, `AlertComponent`; delete/transfer `button_to` + `turbo_confirm` preserved |
| **C** | Pricing & checkout | `pricing/show`, `subscriptions/_plan`, `checkouts/{show,_testimonial}`, `forms/_stripe` | new `PlanCardComponent`; `pricing`/`toggle` Stimulus + monthly/yearly toggle preserved; Stripe embedded-checkout div byte-identical |
| **D** | Subscription mgmt | `billing/{show,_email,_info,_charges}`, `subscriptions/{_subscription,_summary,edit}`, `cancels/resumes/pauses/upcomings/show` | `PlanCardComponent`, `TableComponent` (charges/invoices), `BadgeComponent` (status), `AlertComponent` (trial/past-due), `ButtonComponent`; plan-change `form_with` + hidden `plan` + `turbo_confirm` preserved |
| **E** | Payment method | `payment_methods/new`, `forms/_fake_processor` | `FormFieldComponent`, `ButtonComponent`; fake_processor form params preserved (form the system tests drive) |

Invoices/receipts = the PDF links in `_charges` (Flow D); no separate screen.

### Preserved verbatim (risk surface)
- **Stripe:** `checkouts/forms/_stripe` controller div + `public_key_value` /
  `client_secret_value` data attrs, untouched. No payment controller/model edits.
- **Subscription params:** change-plan `form_with url: billing_subscription_url,
  method: :patch` + `hidden_field :plan` (`plan.to_param`) + `turbo_confirm`;
  cancel/pause/resume `button_to` (`:delete`/`:post`) + `turbo_confirm`;
  confirm-payment → `pay.payment_path`; fake_processor form action/params;
  extra-billing-info `form_with model: current_account, url: billing_path` +
  `text_area :extra_billing_info`.
- **Account/team params:** `accounts/_form` `name`/`domain`/`subdomain` (multitenancy
  guards)/`avatar` file_field + accept list; role checkboxes (`AccountUser::ROLES`,
  `form.check_box role`); invite `name`/`email`; delete/transfer `button_to` +
  `turbo_confirm`/`turbo_confirm_description`; `switch_account_button`,
  `account_avatar`, `nav_link_to` helpers.
- **Wiring:** Stimulus `pricing`, `toggle`, `clipboard`, `stripe--embedded-checkout`
  reused as-is; `content_for :sidebar` → `_account_navbar`; all routes,
  `Current.meta_tags`, lazy i18n keys, Pundit/`account_admin?` guards, `pagy`;
  every `Jumpstart.config.*` / `hotwire_native_app?` branch.

### Edge cases
- **Subscription states** (`_subscription`): `on_trial`, `canceled`, `incomplete`,
  `past_due`, `unpaid`, `paused`, `on_grace_period` — each keeps its badge +
  action set (red badges for past_due/unpaid); trial/past-due banners →
  `AlertComponent`. `metered?`/`charge_per_unit?` → usage/upcoming links. No
  subscription → "choose plan" empty state.
- **Billing access:** non-admin → "contact admin" message, no subscription UI.
- **Team:** personal account → info alert, no members table / delete / invite /
  transfer; account owner → admin checkbox disabled, cannot be removed; empty
  charges → empty-state text; pagination only when `@pagy.last > 1`; pending invites
  → "awaiting response" badge + resend/copy-link/edit.
- **Forms:** validation errors both ways (summary `AlertComponent` + per-field
  `error:`); invalid submit re-renders with values intact.
- **Stripe embedded checkout:** iframe interior opaque; only page chrome restyled.

### Testing
- **Extend existing integration tests** (behavior unchanged): `accounts_test`,
  `account_users_test`, `account_invitations_test`, `subscriptions_test`.
- **System tests** (`account_system_test` + new billing coverage): subscription
  lifecycle happy path via `fake_processor` (pricing → subscribe → change plan →
  cancel → resume); one team-management flow (invite → member appears). WebMock
  blocks external HTTP; `set_payment_processor :fake_processor, allow_fake: true`
  stands in for Stripe (as `subscriptions_test` already does).
- Update button selectors from `input[name=…]` to CSS attribute selectors for
  `<button type=submit>`.
- **Per-flow:** run relevant tests + browser walkthrough (light/dark, mobile) after
  each flow's commit. Final gate: full `bin/rails test` + `bin/rails test:system`
  output shown.

## Scope
**In:** copy + rebuild all views in Flows A–E above; new `PlanCardComponent`
(preview + `/update-catalog`); extend the four integration test files + system
tests. One branch (`feature/cov-15-rebuild-billing-views`), commit per flow, one PR.

**Deferred / Out:**
- `paddle`/`braintree`/`paypal` checkout + payment-method partials (never render;
  Stripe-only config).
- `connected_accounts` views (omniauth disabled — `omniauth_providers: []`).
- Any controller/model/route/i18n/migration changes.
- The `_account_navbar` sidebar partial itself (kept rendering, not rebuilt).
- Devise mailer / account_mailer views (not user-facing account screens).

## Open Questions
None — all brainstorm decisions resolved (full account-settings scope incl.
`account/passwords/edit` + `api_tokens`; Stripe-only rebuild; `PlanCardComponent`;
one PR).

## More Info
- **DS components used:** `PlanCardComponent` (new), `CardComponent`,
  `TableComponent`, `BadgeComponent`, `AvatarComponent`, `AlertComponent`,
  `ButtonComponent`, `FormFieldComponent`, `CheckboxComponent`, `PasswordComponent`,
  `PaginationComponent` (see `docs/COMPONENT_CATALOG.md`).
- **Stimulus (reused, lazy-registered):** `pricing`, `toggle`, `clipboard`,
  `stripe--embedded-checkout`.
- **Config facts:** `payment_processors: ["stripe"]`; `omniauth_providers: []`;
  tests use Pay `fake_processor`.
- If a needed base component turns out missing → install on demand via the
  rails-blocks skill (dry-run, never `--force`) or STOP and ask.
