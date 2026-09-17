> Ticket: COV-80
> Branch: fix/cov-80-hide-family-delete-non-owner
> Plan created: docs/plans/cov-80-hide-family-deletion-control-non-owner.md

# Feature: Hide Family deletion control from non-owner parent admins

## Problem
On the Family edit page, the Delete control renders for any non-personal
account regardless of who's viewing it. A second parent admin (invited via
COV-72) sees a destructive Delete button that the server will reject if
clicked — contradicting the Family permissions model and creating a
misleading, unsafe UI. Separately, the Family member-permissions page title
calls `t(".title")` without the `user:` interpolation its translation
requires, so the page can render/raise on a raw `%{user}` placeholder
instead of the member's name.

## Approach
Two small, isolated view fixes — no controller or model changes, since
server-side owner authorization for `AccountsController#destroy` is already
correct (`require_account_owner!`, accounts_controller.rb:5,41-43) and
already has regression tests (`test/integration/accounts_test.rb:14,22`).

1. `app/views/accounts/edit.html.erb`: change the Delete button's condition
   from `!@account.personal?` to `@account.owner?(current_user)` — matching
   the pattern already used correctly on `accounts/show.html.erb`.
2. `app/views/account_users/edit.html.erb`: pass `user:` to the `.title`
   interpolation on line 1, matching the fallback (`name || email`) already
   used for `.description` on line 22.

Audited other destructive controls in account-related views
(`accounts/account_invitations/edit.html.erb` revoke-invitation button,
`account_users/edit.html.erb`'s own remove-parent button) — both are
correctly gated by admin/not-owner-row checks per the two-admin model and
are out of scope per the ticket's non-goals (parent removal authorization
unchanged).

## Acceptance Criteria
- Family owner visiting Family settings sees the Delete Family control.
- Non-owner parent admin visiting Family settings does not see it.
- Non-owner `DELETE` request remains server-rejected (already covered).
- Owner deletion behavior unchanged.
- Family member-permissions page title interpolates the member's name, never
  a raw `%{user}` placeholder.
- Relevant Minitest coverage passes, along with the full Rails suite.

## Prototype
None — this is a visibility-condition fix to existing markup, not a new UI.

## Data Model
No changes. Uses existing `Account#owner?(user)`
(`lib/jumpstart/app/models/account/types.rb:37`).

## Screens / Flows
- **Family edit page** (`accounts/edit.html.erb`): owner sees Delete button;
  non-owner admin does not.
- **Family member-permissions page** (`account_users/edit.html.erb`): title
  reads "Edit permissions for <name>" for any viewer with access, never a
  raw placeholder.

## Scope
**In:**
- Condition fix on the Delete button in `accounts/edit.html.erb`.
- Interpolation fix on the title in `account_users/edit.html.erb`.
- Integration/view test coverage for both roles seeing/not-seeing the
  Delete control, and for the title rendering correctly.

**Deferred:** Nothing — this is the full scope of the ticket.

## Open Questions
None.

## More Info
Existing fixtures already model the two-admin scenario needed for tests:
`accounts.yml:company` (owner: `one`) with `account_users.yml:company_admin`
(user `one`, owner) and `company_regular_user` (user `two`, non-owner
admin) — no new fixtures needed.
