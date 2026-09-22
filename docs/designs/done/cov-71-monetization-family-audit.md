> Ticket: COV-71
> Branch: chore/cov-71-audit-monetization-family-setup

# Feature: Monetization and family-account audit

## Problem

Before family accounts (COV-72) and live-mode Stripe (COV-78) are built, we
need a confirmed record of what billing and account plumbing actually exists —
in code, in Stripe, in Loops, and on staging. The prior code audit had several
findings that turned out to be wrong or understated. **This ticket makes no
code changes.**

## Approach

Audit in four passes, recording each finding as OK / needs work:

1. **Code** — read the Jumpstart engine and app for the eleven listed gaps.
2. **Stripe** — query the API directly with Cove's own test key (read-only),
   then use the dashboard for settings the API doesn't expose.
3. **Loops** — list contact properties via the API.
4. **Staging** — walk `/admin`, `/billing`, `/pricing`, `/accounts` as a
   superadmin.

Everything below was verified on 2026-09-15.

## Acceptance Criteria

- [x] Findings recorded, each marked OK / needs work
- [x] Stripe and Loops settings later tickets rely on are written down
- [x] Gaps 1–11 confirmed or corrected; new gaps listed as follow-ups

## Prototype

None.

## Product rules this audit is measured against

Moved into [`docs/product/product-brief.md`](../product/product-brief.md) —
that brief was empty when this audit was written, so the rules were recorded
here first. Pricing there has since moved on to $12/mo and $120/yr (COV-88);
the figures below are what the audit was actually measured against on
2026-09-15.

### Pricing and tiers (as of this audit)

- Premium was **$9/mo** or **$84/yr** (shown as "$7/mo billed yearly") at the
  time of this audit.
- The model stays `Account` in code; users see "family".

### Technical principles

- `Account#premium?` — active subscription (**including `past_due`**) or
  complimentary Premium. Single source of truth.
- `Account#students_allowed` — 1 on Free, the family's `student_limit` on
  Premium.
- `Account#plan_status` — `premium`, `complimentary`, or `free`.
- Prices are `Plan` rows, one per Stripe Price. Staging and prod entered at
  `/admin/plans` from a checklist; dev via seeds.
- **Changing a price:** new Stripe Price → new Plan row → **hide** the old row.
  Never delete it.

## Findings

### Confirmed already in place

| Area | Detail |
|---|---|
| Per-account billing | `Account::Billing` calls `pay_customer` (`lib/jumpstart/app/models/account/billing.rb`) |
| Plans as rows | `Plan` has `stripe_id`, `amount` (cents), `interval`, and — importantly — **`hidden`** plus `hidden`/`visible` scopes, and `contact_url` |
| Free plan helper | **`Plan.free` already exists** (`lib/jumpstart/app/models/plan.rb:21`) and creates a hidden $0 plan |
| Roles | `AccountUser::ROLES = [:admin]`; ownership transfer via `Accounts::TransfersController` |
| Trials off | `trial_period_days` defaults to 0 |
| API accounts | `Api::V1::AccountsController` is **read-only** (`index`, `show`) |

### Gaps 1–11

| # | Verdict | Detail |
|---|---|---|
| 1 | **OK (confirmed)** | `config/jumpstart.rb` has `account_types: "personal"`; `AccountUsersController#require_non_personal_account!` blocks invites |
| 2 | **Needs work — worse than stated** | `Users::RegistrationsController#sign_up:39` destroys `current_user.accounts.where(personal: false)`. With `account_types: "personal"` the signup account **is** personal, so the cleanup **never fires at all** — not even on the new-user-through-invite path the original audit credited as working |
| 3 | **OK (confirmed)** | No premium check anywhere. Only Jumpstart's own docs mention `premium_features` |
| 4 | **Corrected — original finding wrong** | Staging's pricing page does **not** redirect home. It renders "Cove Dev Plan — $19/month". A Plan row exists (see gap 9) |
| 5 | **OK (confirmed verbatim)** | `/billing` on staging reads "You are not currently subscribed." Pricing shows only paid plans |
| 6 | **OK (confirmed)** | `Pay::Customer#subscribed?` excludes `past_due`. `Account#premium?` must not use it |
| 7 | **Needs work — worse than stated** | `config/initializers/pay.rb:32` finds the plan by `processor_plan`; line 36 then calls `plan.amount`. A deleted Plan row is a **`NoMethodError` on nil**, not a degraded page |
| 8 | **OK (confirmed)** | No `student_limit` on `accounts` (see `db/schema.rb`); `account_resource.rb` has no such attribute. Also **no complimentary-Premium flag or note** |
| 9 | **Needs work — already happened** | `render.yaml:12` runs `db:prepare` with `RAILS_ENV=staging`; `db/seeds.rb:5` guards only `production`. **Staging was seeded with demo data on 2026-09-09** |
| 10 | **OK (confirmed, live)** | `/users/edit` on staging shows "Delete my account — This will permanently erase all data associated with your account." `owned_accounts` is `dependent: :destroy` |
| 11 | **OK (confirmed, narrowly)** | Only `POST /api/v1/users` creates accounts; the API accounts controller is read-only |

### New gaps

| # | Severity | Detail |
|---|---|---|
| 12 | **High** | Staging has a system admin `superadmin@cove.test` whose password (`password`) is published in `db/seeds.rb`, on a public host. `hello@covehomeschool.com` is **not** an admin, and `Jumpstart.grant_system_admin!` is console-only — which Render's free tier doesn't provide — so this seeded account is currently the **only** way into staging `/admin` |
| 13 | **High** | `config/initializers/pay.rb:14` builds receipt recipients from `account.owner.email` plus optional `billing_email`. With two parent admins who can both manage billing, **the second parent never receives a receipt** |
| 14 | **High** | Flipping `account_types` to `"team"` for COV-72 opens `/accounts/new` and `/accounts/:id/create` (gated by `ensure_team_accounts_enabled`, `accounts_controller.rb:109`) and leaves `PATCH /accounts/:id/switch` live. Both contradict "one person belongs to exactly one family, no account switching." No view currently links to the switcher, but the routes are reachable directly |
| 15 | Medium | `db/seeds.rb` creates a **non-personal** "Cove Team" account while `account_types` is `"personal"` — a state the config forbids. An `AIDEV-NOTE` already flags the inverse dependency |
| 16 | Medium | `register_with_account?` is `!personal_accounts?`. Flipping to `"team"` makes `Api::V1::UsersController#create` call `owned_accounts.first_or_initialize` **and** fire the `create_default_account` callback — a double-account risk |
| 17 | ~~Medium~~ **Resolved 2026-09-15** | Stripe's **"Send finalized invoices and credit notes to customers" was ON** in the Cove sandbox, violating the all-email-through-Loops rule. Turned off. Note this must be re-checked in **live mode**, where it defaults on (gap 18) |
| 18 | **High** | **No Cove sandbox configuration transfers to live mode.** Webhook endpoint, portal configuration, Smart Retries, and all prices must be recreated on the parent account for launch. This is the real scope of COV-78 |
| 19 | ~~Medium~~ **Resolved 2026-09-15** | The "Cove sandbox" environment was marked **Private** — no teammate could see the environment the app actually runs against. Access changed to All team members, and the sandbox pinned |
| 20 | **High** | Staging's only Plan row has a **blank Stripe ID** and `fake_processor_id: cove_dev`. Staging checkout therefore cannot reach Stripe at all — staging billing is **not** end-to-end functional, contrary to the original audit's claim |
| 21 | Medium | Two `User` records exist for Jordan — id 6 `hello@covehomeschool.com` (password) and id 7 `jordan.d.bowman@gmail.com` (Google OAuth, `ConnectedAccount #1`) — each owning its own personal account. **Signing in with Google creates a new user even when an email user exists**; there is no account linking. Directly relevant to "one person, one family" |
| 22 | Low | Staging's signed-out homepage is still the stock "Welcome to Jumpstart" marketing page |

## Stripe — recorded settings

### Two sandboxes (the most important finding)

The Cove Stripe account has **two** test environments, and the dashboard's
default is not the one the app uses:

| Name | ID | Access | Webhook | Events | Deliveries |
|---|---|---|---|---|---|
| Test mode | `acct_1Tw253Au4G4fKTCY` | All team members | "COV-47 staging verification" (`we_1U0vQDAu4G4fKTCYzLA8RBfC`) | 6 | 0 |
| **Cove sandbox** | `acct_1Tw25AAVvDn1V5lJ` | **Private** | "empowering-sensation" (`we_1Tw2D1AVvDn1V5lJd0VXwYfu`) | 61 | 0 |

**Cove sandbox is the one the app's credentials point at.** All products,
prices, customers, and subscriptions live there. The Test mode sandbox holds
only a stale COV-47 endpoint missing `checkout.session.completed`,
`invoice.payment_succeeded`, `customer.subscription.created`, and
`customer.updated`.

`config/credentials/production.yml.enc` currently holds **test-mode** keys
(`pk_test_51Tw25A…` / `sk_test_…`) for Cove sandbox — expected pre-launch,
and exactly what COV-78 must replace.

The local Stripe CLI was authenticated to an unrelated account, **"Thistle
Books sandbox" `acct_1TjWnFHjfMLxj7fZ`**. Re-auth with
`stripe login --project-name cove` and invoke with `--project-name cove`.

### Products and prices (Cove sandbox)

| Object | State |
|---|---|
| `prod_UxCn3QqXwxUsnZ` "Cove Dev Plan" | active, `price_1TxIO4…` $19/mo active |
| `prod_V1G4ntA6OAIVVY` "COV-47 Verification (Yearly)" | **archived**, but `price_1U1DYf…` $99/yr **still active** |

**No $9/mo or $84/yr price exists yet.** Both must be created for COV-72.

### Webhook coverage (Cove sandbox, 61 events)

All six families the ticket asked about are subscribed: `customer.subscription.*`,
`checkout.session.completed`, `invoice.payment_succeeded`,
`invoice.payment_failed`, `charge.*`, `customer.updated`. **OK.**

### Customer portal (`bpc_1U6FhrAVvDn1V5lJQ3lDjC6T`, default)

| Feature | State | Matches rules? |
|---|---|---|
| Payment method update | enabled | ✅ |
| Subscription cancel | enabled, `mode=at_period_end`, `proration_behavior=none` | ✅ no refunds |
| Subscription update (plan switching) | **disabled** | ✅ app does `swap` |
| Invoice history | enabled | — |
| Customer update | name, email, address, phone | ⚠️ portal email edits are separate from the account's `billing_email` |

### Failed payments (Cove sandbox)

| Setting | Value |
|---|---|
| Smart Retries | **on — up to 8 attempts within 2 weeks** |
| If all retries fail → subscription | **cancel the subscription** ✅ |
| If all retries fail → invoice | leave past-due |
| Recurring payment incomplete 15 days | cancel the subscription |
| Dispute opened | leave the subscription past-due |

This already matches the `past_due`-keeps-Premium rule: the family keeps
Premium for the ~2-week retry window, then the subscription **cancels** (rather
than going `unpaid`, which Pay handles ambiguously and the customer can't
self-serve out of).

### Customer emails (Cove sandbox)

**All off** — trial reminder, upcoming renewals, expiring cards, card payment
failed, bank debit failed. This is **correct** under the all-email-through-Loops
rule, with one exception: **"Send finalized invoices and credit notes to
customers" was ON** and has been turned off (gap 17).

Consequence: Stripe sends nothing during the 2-week retry window, so a **Loops
dunning sequence is required, not optional**. `invoice.payment_failed` and
`customer.subscription.updated` already reach `/webhooks/stripe`, so the app has
what it needs to emit the events.

## Loops — recorded settings

`planStatus` **did not exist** and was **created during this audit** via
`POST /v1/contacts/properties` (`{"name":"planStatus","type":"string"}`). It
now lists as `planStatus` / "Plan Status" / string.

Answering the ticket's question: Loops exposes an explicit property-creation
endpoint, and the property now exists, so COV-73 can write it without relying
on auto-creation.

Other custom properties: `__critical_audience`, `__marketing_audience`,
`__domain`.

## Staging — recorded state

Seeded on 2026-09-09 by `db:prepare`. Signed in as `superadmin@cove.test`.

**Accounts (8):** Olivia Owner, Andy Admin, Molly Member, Sofia Subscriber,
Sydney Super, Cove Team (all seeds) + two "Jordan Bowman" personal accounts
(ids 7, 8) from 2026-09-10.

**Users (7):** five seeded + Jordan ×2 (see gap 21).

**Plans (1):** id 1 "Cove Dev Plan", 1900, month, **blank Stripe ID**,
`fake_processor_id: cove_dev` (gap 20).

**Pay subscriptions (1):** the seeded fake-processor `cove_dev` subscription.
**Zero real Stripe activity on staging.**

`/admin/accounts` has no student-limit or complimentary-Premium field (gap 8).

## Every place an account can be created, joined, switched, or deleted

| Surface | Route / code | Currently reachable? |
|---|---|---|
| Signup auto-creates | `User::Accounts#create_default_account` (after_create) | **Yes** |
| Google OAuth signup | `Users::OmniauthCallbacksController` → new `User` → same callback | **Yes** — and creates a duplicate user (gap 21) |
| API user create | `POST /api/v1/users` | **Yes** (unauthenticated) |
| New account UI | `GET/POST /accounts` | No — `ensure_team_accounts_enabled` blocks it. **Opens with `"team"`** (gap 14) |
| Accept invite (new user) | `Users::RegistrationsController#sign_up` | Orphan account left behind (gap 2) |
| Accept invite (existing user) | `AccountInvitationsController#update` → `AccountInvitation#accept!` | Orphan account left behind |
| Switch account | `PATCH /accounts/:id/switch` | Route live; no UI links to it. **Must be removed for COV-72** |
| Delete family | `DELETE /accounts/:id` | Blocked for personal by `prevent_personal_account_deletion` |
| Delete own login | `DELETE /users` from `/users/edit` | **Yes** — cascades to owned accounts and cancels subscriptions (gap 10) |
| Admin create/delete | `/admin/accounts`, `/admin/users` | Superadmin only |

## Scope

**In:** recording findings only. No code changes.

**Stripe cleanups approved by Jordan:**

1. ✅ **Done 2026-09-15 via API** — archived the leftover COV-47 price
   `price_1U1DYfAVvDn1V5lJnu8hqCnk` ($99/yr, `active=false`). Its product was
   already archived. Only `price_1TxIO4…` ($19/mo) remains active in Cove
   sandbox.
2. ✅ **Done 2026-09-15 by Jordan in the dashboard** — deleted the stale
   "COV-47 staging verification" endpoint (`we_1U0vQDAu4G4fKTCYzLA8RBfC`). It
   lived in the **Test mode** sandbox, and the credentials key is scoped to
   Cove sandbox, so the API couldn't reach it (`No such webhook endpoint`).
3. ✅ **Done 2026-09-15 by Jordan in the dashboard** — turned **off** "Send
   finalized invoices and credit notes to customers". Not exposed in the
   public API: `settings.billing` is `nil` and `settings.invoices` carries
   only tax IDs and `hosted_payment_method_save`.
4. ✅ **Done 2026-09-15 by Jordan** — Cove sandbox access changed to **All
   team members**, and the sandbox **pinned** so the dashboard lands there by
   default. Both live under `⋯` on the sandbox row at
   `dashboard.stripe.com/acct_1Tw253Au4G4fKTCY/sandboxes` (parent-account
   context, not inside the sandbox). Gaps 17 and 19 are closed.
5. Consolidate all test work on Cove sandbox — noting gap 18: none of it
   carries to live.

**Staging recommendation — reset, not convert.** Staging data is disposable and
is entirely seed data plus two duplicate Jordan logins; there is no real Stripe
activity and the only Plan row has no Stripe ID. Wipe and re-provision without
seeds, and narrow the `db/seeds.rb` guard so it doesn't run on staging.

### How staging gets its first admin (must land before the reset)

Resetting staging without seeds removes `superadmin@cove.test`, which is
currently the **only** way into `/admin` (gap 12). Because Render's free tier
has no console or one-off jobs, `Jumpstart.grant_system_admin!` cannot be run
by hand, so **the reset would otherwise lock us out of `/admin/plans`** — which
COV-72 and COV-78 both depend on for entering real Plan rows. Three changes,
in this order:

1. **Narrow the seed guard.** Change `db/seeds.rb:5` from
   `unless Rails.env.production?` to `if Rails.env.local?`, so demo users are
   development/test only and never reach staging again. This also resolves
   gaps 9 and 15.
2. **Add an idempotent staging admin bootstrap.** A rake task that creates
   exactly one user from a Render env var (e.g. `STAGING_ADMIN_EMAIL`) with a
   **randomly generated** password, then calls
   `Jumpstart.grant_system_admin!`. Chain it into `render.yaml`'s
   `startCommand` after `db:prepare` — `preDeployCommand` and console are not
   available on the free tier, but `startCommand` is. Because `startCommand`
   runs on **every boot**, the task must find-or-create, grant admin only if
   not already granted, and **never reset an existing user's password**.
3. **Obtain the password by reset, not by env var.** Don't store an admin
   password in Render. Let the task generate a random one, then use the app's
   "Forgot password" flow to set a real one. Staging mail already routes
   through Loops via `STAGING_EMAIL_RECIPIENT_ALLOWLIST`, so the reset email
   will arrive.

Net effect: a real admin tied to a personal address, no credentials published
in the repo, and no console dependency.

**Deferred (follow-up tickets):**

- **Staging seed guard + admin bootstrap (gaps 9, 12, 15) — blocks the staging
  reset.** See "How staging gets its first admin" above.
- **A boot-time guard asserting the expected Stripe account id in staging**, so
  a credentials mix-up between the two sandboxes fails loudly instead of
  silently writing to the wrong environment (gap 18's near-miss).
- Loops dunning sequence for the 2-week retry window (not covered by COV-45).
- Receipts to both parent admins (gap 13).
- Removing `/accounts/new` and `/accounts/:id/switch` when `"team"` is enabled
  (gap 14) — belongs in COV-72.
- Account linking so Google sign-in doesn't fork a second user (gap 21).
- Recreating all Stripe configuration in live mode (gap 18) — COV-78.
- Branding staging's signed-out homepage (gap 22).

## Open Questions

The still-open product questions this audit raised (sales tax, mid-year
plan-interval switches, ToS/refund pages, downgraded-family UX) moved into
[`docs/product/product-brief.md`](../product/product-brief.md). What's left
here are the ones this audit itself resolved:

- **Existing staging accounts** — resolved: reset (above).
- **Loops property setup** — resolved: `planStatus` created.
- **Staging's first admin after the reset** — resolved: seed guard narrowed to
  `Rails.env.local?` plus an idempotent bootstrap rake task in `startCommand`,
  password obtained via "Forgot password". See "How staging gets its first
  admin" above.
- **Which Stripe test environment is canonical** — resolved: **Cove sandbox**
  (`acct_1Tw25AAVvDn1V5lJ`). Test mode cannot be deleted (it's built into the
  account and isn't counted against the 5-sandbox quota), so it stays but is
  left empty. Cove sandbox is now pinned and shared with all team members.

## More Info

The product rules and open questions this audit surfaced now live in
[`docs/product/product-brief.md`](../product/product-brief.md).
