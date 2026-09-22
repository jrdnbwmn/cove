> Ticket: COV-72
> Branch: feature/cov-72-family-accounts-two-parent-admins
> Plan created: docs/plans/cov-72-family-accounts-two-parent-admins.md

# Feature: Family accounts with two parent admins

## Problem

Premium attaches to the account, so "account = family" must be true before any
billing work builds on it. Today accounts are personal, can't hold a second
parent, and nothing stops one person from belonging to several. This ticket
makes the family account real and enforces one-person-one-family in the
database, not just in the UI.

## Approach

Keep Jumpstart's existing `team` account machinery and enforce the family rules
around it. `account_types` flips from `"personal"` to `"team"` by **hand-editing**
`config/jumpstart.rb` (never the Jumpstart config generator — see AGENTS.md:
it regenerates the whole file and creates a root `Procfile` this repo
deliberately does not have).

The one-family invariant is a **unique index on `account_users.user_id`**.
Membership is the constraint. The rejected alternative was denormalizing
`users.account_id` onto the user: it reads better, but `AccountUser` already
carries the admin role, invitation acceptance, ownership checks, and per-seat
subscription quantity, so a parallel column means two sources of truth that can
disagree — or rewriting engine code we don't own and must re-merge on upgrade.

Abandoned families are **archived, not destroyed**, so an existing user who
joins another family keeps their billing history intact. This is what lets a
previously-subscribed parent join self-serve instead of hitting a support wall.

Account linking (gap 21) is in scope because without it the invariant is
unenforceable: Google sign-in currently mints a **second `User` row** for the
same human, and a unique index on `user_id` cannot see that two users are one
person. Staging already has this in real data (users 6 and 7 are both Jordan).

## Acceptance Criteria

- [ ] A parent who signs up ends up with exactly one family account and is its owner
- [ ] An invited new user joins the inviting family as admin, with no other account
- [ ] An existing user with a joinable family accepts an invite, joins, and their old family is archived with billing history intact
- [ ] An existing user with an active/`past_due` subscription is blocked with "cancel Premium first" and keeps their family
- [ ] An existing user whose family has another member is blocked with a specific "contact support" message and keeps their family
- [ ] A user can't create a second family or belong to two families (web or API)
- [ ] A family can't hold more than two parents
- [ ] Both parents can reach billing and start checkout
- [ ] Both parents receive receipts
- [ ] Only the owner can delete the family or transfer ownership
- [ ] The owner can't delete their login while another parent is in the family
- [ ] A second parent who deletes their login leaves; the family, subscription, and owner are untouched
- [ ] After ownership transfer and the old owner leaving, the subscription stays active
- [ ] Google sign-in with an existing verified email signs into the existing user; no second user, no second family
- [ ] An invitation can only be accepted by the address it was sent to
- [ ] Adding a second parent does not change subscription quantity

## Prototype

None.

## Data Model

### Migration

```ruby
add_column    :accounts, :archived_at, :datetime
add_index     :accounts, :archived_at
Account.update_all(personal: false)
add_check_constraint :accounts, "personal = false", name: "accounts_personal_must_be_false"

add_index :account_users, :user_id, unique: true
```

`accounts.personal` already defaults to `false` in `db/schema.rb`. It is kept
(dropping it means forking engine code that references it) but pinned false by
a check constraint plus a model validation.

**The migration includes a destructive data step.** The unique index will fail
against existing data — seeded users belong to two accounts each (their personal
one and "Cove Team"). The migration first collapses each user to one membership:
keep the one for the account they own, else the oldest, delete the rest. This is
acceptable **only because no production exists** (`render.yaml`'s production
block is dormant) and staging is disposable seed data being wiped anyway. It
carries an `AIDEV-NOTE` saying exactly that so it isn't mistaken for a pattern.
In practice the dev path is `db:reset`; the data step exists so the migration
doesn't explode on a stale local database.

No new columns on `users`. Account linking attaches a `ConnectedAccount`
(already polymorphic on `owner`) to the existing user.

### Archived families

```ruby
scope :active,   -> { where(archived_at: nil) }
scope :archived, -> { where.not(archived_at: nil) }
```

Deliberately **not** a `default_scope` — those leak into every association and
`unscoped` is a blunt escape hatch. Little is needed anyway: an archived family
has zero members, so `current_user.accounts` excludes it for free. Only two
places filter explicitly — `User#create_default_account` (an archived owned
account must not count as "already has a family") and the one-family check.

### Model surface

| Addition | Purpose |
|---|---|
| `User#family` | The one account. Makes the invariant legible without denormalizing `users.account_id`. |
| `Account#parents` | Reads better than `admins` at call sites; same records. |
| `Account#archive!` | Sets `archived_at`, leaves Pay records intact. |
| `Account#joinable_by?(user)` | The three-outcome check below. |
| `FamilyInvitationAcceptance` | Service in `app/services/`, invoked `.new(...).call` to match `AdminBootstrap` and `LoopsWebhookEventProcessor`. Wraps archive + membership move in one transaction. |

### Max two parents

The unique index gives one-family-per-person but **not** two-parents-per-family.
That needs a model validation (`account_users_count < 2`, cheap via the existing
counter cache) plus a controller guard so a direct POST can't bypass a hidden
button. Postgres can't express it without a trigger, which isn't worth adding.
This is the one family rule enforced only in Ruby.

### Receipts (gap 13)

`config/initializers/pay.rb:14` changes from `account.owner.email` to both
admins' emails. `Account::Billing#email` (the Stripe *customer* email —
`billing_email` or owner's) is a different thing and stays as-is.

### Per-seat billing removal

`AccountUser` includes `UpdatesSubscriptionQuantity`, which fires
`after_commit on: [:create, :destroy]` and calls
`subscription.change_quantity(account.per_unit_quantity)` where
`per_unit_quantity` is `account_users_count`. It's gated on
`plan.charge_per_unit?`, so it's inert today — but if anyone ever ticks
`charge_per_unit` on the Premium plan in `/admin/plans`, **inviting the second
parent silently doubles the bill**, with no error.

Cove is flat-per-family permanently, so the mechanism is removed rather than
tested around:

```ruby
# app/models/account_user.rb
include Ownership, Roles   # was: Ownership, Roles, UpdatesSubscriptionQuantity
```

App code, so nothing to fork. Gets an `AIDEV-NOTE` — Jumpstart upgrades touch
`app/models/` templates and could silently restore the include. A regression
test asserts a second parent leaves subscription quantity at 1.
`Account#per_unit_quantity` stays in the engine, unused and harmless.

### current_account

With the switcher gone, **stop deriving `current_account` from the signed
`account_id` cookie**; derive it from the user's single membership. This deletes
a whole bug class: removed parent holding a cookie for their old family,
archived family in a cookie, cookie pointing at a family you were never in.

## Screens / Flows

### Signup

Parent signs up (email or Google) → one family account, they're owner and admin.
**No family-name field**: flipping to `"team"` makes Jumpstart render one, and we
suppress it. Auto-named **"%{name}'s Family"** (rewriting the existing
`team_name: "%{name}'s Team"` key), renameable later. "The Bowman Family" was
rejected — last-name parsing breaks on single names, hyphenates, and non-Western
name orders.

### Google sign-in with an existing email

Verified matching address → attach the `ConnectedAccount` to the existing user and
sign in. No second user, no second family. Flash confirms the link so the identity
merge isn't invisible. Unverified → refuse, route to password sign-in.

### Inviting the second parent

Owner invites by email from family settings. Invitee joins **as admin** — no role
picker, both parents are always admins. Invite button only shows while the family
has one parent.

`AlertComponent` (`variant: :info`) above the submit discloses what's being handed
over:

> **The other parent will be an admin.** They'll be able to see and manage
> everything in your family, including your students and your billing — starting
> or canceling Premium, changing the payment method, and viewing past receipts.
> They'll also receive billing emails and receipts. They won't be able to delete
> the family or transfer ownership; only you can do that.

The same clarity appears in the invitation email and acceptance screen ("You'll be
an admin of this family, including its billing") and as a standing line under the
non-owner in the parents list ("Admin · can manage billing") — access should be
visible later, not only at the moment of invitation.

`AlertComponent#description` renders with `.html_safe`; this copy is static and
developer-authored, so the catalog's XSS note doesn't bite.

### Accepting — invitee has no login yet

They sign up through the invite link and land directly in the inviting family as
admin. **No second family is ever created.** Today's code creates one and tries to
clean it up in `Users::RegistrationsController#sign_up:39` — and with `personal`
accounts that cleanup never fires at all (gap 2). We create the right thing once.

### Accepting — invitee already has a login

```ruby
joinable? = account_users.count == 1
          && students.none?          # no-op until the students ticket
          && no active-or-past_due subscription
```

1. **Joinable** → one transaction: old family archived, membership moved, admin of
   the new family. Billing history preserved on the archived family.
2. **Active or `past_due` subscription** → blocked, "cancel your Premium first,
   then accept," linking to billing. Actionable, not a dead end.
3. **Another member** → blocked, specific message naming the blocker, then contact
   support. Merge is permanently wrong here: a family holds at most two parents, so
   merging either strands the third person or produces a three-parent family.

**Acceptance is bound to the invited email.** `AccountInvitationsController#update`
currently accepts for `current_user`, whoever that is — a forwarded invitation is
enough to join. Pre-existing Jumpstart behavior, but this ticket sharpens it: the
joiner becomes a billing admin **and** their own family gets archived, so a
mis-accepted invite is destructive to the wrong person's data. Compare the
invitation's email to `current_user.email` and refuse with "this invitation was
sent to someone else."

### Ownership transfer

Owner only, to the other parent (already an admin). Old owner stays as an admin.
Subscription untouched. `Accounts::TransfersController` already exists; copy changes
to "family." This is the page the blocked owner-delete links to.

### Removing the other parent

Owner only. The removed parent gets **a fresh empty family** and lands in it — never
signed in with zero families. They don't take students or history with them: right
for the "added the wrong email" case, harsh for an actual separation, which support
handles.

### Deleting your own login

- **Owner with a second parent** → blocked *before* the confirm dialog, with a
  transfer link.
- **Owner alone** → allowed; family and subscription go with them.
- **Second parent** → allowed; they just leave. Copy changes from "permanently erase
  all data" to something accurate — the family continues without them.

### Deleting the family

Owner only. Confirmation states the subscription **ends immediately with no refund**,
consistent with pricing, checkout, and cancel copy.

### Removed

Accounts index, `/accounts/new`, `POST /accounts`, and `PATCH /accounts/:id/switch` —
routes deleted, not just unlinked (gap 14) — plus their links in `_account_menu`,
`_user_menu`, `_account_navbar`, and `_navbar.html+native`. Several live under
`lib/jumpstart/app/views/`; check both paths.

`personal_team_description` ("Your personal account is private. Create a new account
to share with your team.") is deleted outright — it describes a feature that no
longer exists.

### API

`POST /api/v1/users` (gap 16): with `"team"`, `register_with_account?` flips true and
the controller calls `owned_accounts.first_or_initialize` **while**
`create_default_account` also fires — two accounts. Delete that branch; the callback
is the single path. The unique index catches regressions.

## Edge cases

| Case | Behavior |
|---|---|
| Two invites accepted at once | `RecordNotUnique` from the new index, rescued into "you're already in a family" — not a 500. The index is the backstop because check-then-insert is racy. |
| Inviting someone already in the family | Blocked at invite time. Today it "works," then fails confusingly at acceptance. |
| Parent removed mid-session | Next request they're in their fresh empty family — no stale cookie, because `current_account` no longer reads one. |
| Transfer, then old owner deletes login | Subscription stays active: after transfer they own nothing, and `pay_should_sync_customer?` fires on the owner change to move the Stripe customer email. Explicit test. |
| Google email case | Match case-insensitively; the OAuth payload is external and shouldn't be trusted to be normalized. |
| Matched user already linked to a different Google account | Refuse gracefully rather than attaching a second identity. |
| Stale/expired invite token | Existing `find_by!` rescue redirects with "not found." |

**Must verify, not assume:** COV-71 gap 10 claims deleting a login "cascades to owned
accounts and cancels subscriptions." `dependent: :destroy` destroys the
`Pay::Customer` row locally, but a destroyed local row does not by itself cancel the
Stripe subscription — that's the difference between a clean teardown and continuing
to bill a family that no longer exists. If it doesn't cancel, add an explicit cancel
before destroy.

## Scope

**In:**

- `account_types` → `"team"` by hand-edit
- Unique index on `account_users.user_id`; `archived_at`; `personal` check constraint
- Max-two-parents validation + controller guard
- Signup creates exactly one family, owner + admin, auto-named
- Invite → second parent as admin, with disclosure copy
- Existing-user acceptance: archive-and-join / cancel-first / contact-support
- Acceptance bound to the invited email
- Remove switcher, `/accounts/new`, accounts index — routes and links
- API user-creation double-account fix
- Self-delete guards (owner blocked / non-owner leaves)
- Family deletion with no-refund warning
- Receipts to both parents (gap 13)
- Remove `UpdatesSubscriptionQuantity` from `AccountUser` + regression test
- `current_account` from membership, not cookie
- Google account linking on verified email match (gap 21)
- "family" copy throughout
- Seeds: two-parent family and a subscribed family, development only; fixtures updated
- Staging wipe and re-provision (after merge and deploy)
- Record the parent issue's decisions in AGENTS.md → "Current Project Decisions"

**Deferred:**

- **Student merge on invite acceptance.** The right product answer for a joiner whose
  family has students, but unbuildable here: there is no `Student` model yet, so
  `students.none?` is a literal no-op and case 3a is **unreachable**. Deferring costs
  zero reachable cases. Two constraints to carry into the students ticket: (1) both
  parents likely entered **the same children**, so a silent merge creates duplicate
  kids — it needs a review step ("deselect any already there"); (2) the combined total
  can exceed the target family's `students_allowed` (1 Free / 10 Premium), which
  collides with the downgrade "pick which stay editable" rule.
- Loops dunning sequence for the 2-week retry window.
- Boot-time guard asserting the expected Stripe account id in staging.
- Branding staging's signed-out homepage (gap 22).
- Live-mode Stripe configuration (COV-78).

## Open Questions

- **Does destroying a `Pay::Customer` cancel the Stripe subscription?** Must be
  verified during implementation; if not, add an explicit cancel before destroy.
- **`_navbar.html+native.erb`** — the Hotwire Native navbar links to `accounts_path`
  unconditionally. The link is removed, but this is code-correct and **visually
  unverified**; no simulator run.
- **Staging first admin.** `admin:bootstrap` reads `BOOTSTRAP_ADMIN_EMAIL` and
  **no-ops when unset**. No bootstrap-created user exists on staging, so there is no
  positive evidence the path works. After the wipe, the seeded superadmin and
  `hello@covehomeschool.com` are both gone and that task is the only thing between us
  and a staging box with zero admins and no console to fix it. Verify behaviorally
  before wiping — set the var to an address not yet on staging, redeploy, confirm a
  new admin appears.

## Staging

Confirmed 2026-09-16: all 8 seeded accounts and 7 users from the 2026-09-09 seeding
are still present. COV-79 shipped **code only** (seed guard, `AdminBootstrap`,
`admin.rake`, `render.yaml`) and never touched the staging database — the reset was
always scoped here, as COV-71's "blocks the staging reset" wording indicates.

`superadmin@cove.test` (user 5, published password in `db/seeds.rb`, system admin on
a public host — gap 12) was **deleted 2026-09-16** via `/admin/users/5`. That session
turned out to be signed in as user 5, so the deletion signed the browser out.
`/admin` access was then **confirmed 2026-09-16** via `hello@covehomeschool.com`
(user 6, `Admin true`, granted 2026-09-15) — so the deletion took effect and did
not lock us out.

**Order of operations:** verify `BOOTSTRAP_ADMIN_EMAIL` → merge → deploy → wipe and
re-provision the Render Postgres instance. Wiping first would re-provision into the
old schema and immediately re-create stale-shaped accounts.

Gap 21 is confirmed live in staging data: users 6 and 7 are the same human, two
logins, two families, `ConnectedAccount #1` on the Google one.

## More Info

`docs/product/product-brief.md`, `strategy-brief.md`, and `ux-notes.md` are empty.
The product rules this design assumes — pricing, family rules, student limits,
billing behavior, comped Premium, Loops `planStatus` — live in
`docs/product/product-brief.md`. The COV-71 audit that first recorded them is
archived at `docs/designs/done/cov-71-monetization-family-audit.md`.

Prices will change; **no feature logic may depend on a price, amount, plan name, or
Stripe ID** (COV-71).
