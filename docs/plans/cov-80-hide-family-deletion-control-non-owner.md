> Ticket: COV-80
> Branch: fix/cov-80-hide-family-delete-non-owner

# Plan: Hide Family deletion control from non-owner parent admins

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ------------------------------------------------------------ | ------ | ---- |
| 1    | 1     | 1          | Gate Delete button on `accounts/edit.html.erb` by ownership   | Clone  | ✅   |
| 2    | 1     | 1          | Fix `%{user}` interpolation on `account_users/edit.html.erb`  | Clone  | ✅   |

## Prerequisites

- Design: `docs/designs/cov-80-hide-family-deletion-control-non-owner.md`
- Prototype: None
- Feature branch exists: `fix/cov-80-hide-family-delete-non-owner` (current branch)

## Tasks

### Task 1 [Clone]: Gate Delete button on accounts/edit.html.erb by ownership

**Skills:** write-tests
**Reference:** Read [`app/views/accounts/show.html.erb`] (lines with the
`@account.owner?(current_user)`-gated "Delete family" button) for the exact
pattern to replicate. Read [`test/integration/accounts_test.rb`] for
integration test conventions (fixtures, `sign_in`, no FactoryBot per
`AGENTS.md`).

**In scope:**

- In `app/views/accounts/edit.html.erb`, change the Delete button's
  condition from `if !@account.personal?` to
  `if @account.owner?(current_user)`.
- New test file `test/integration/accounts_edit_test.rb` (or add to
  `test/integration/accounts_test.rb` if you judge that a better fit —
  match its existing `Jumpstart::AccountsTest` class/module naming style)
  covering:
  - Family owner (`users(:one)` on `accounts(:company)`) visiting
    `GET /accounts/:id/edit` sees the Delete control (assert response body
    includes the delete `button_to`'s form action / text — e.g.
    `assert_select "form[action=?][method=?]", account_path(accounts(:company)), "post"`
    combined with checking for a `_method` hidden field of `delete`, or
    simpler: `assert_match` against the delete button's visible text from
    `en.yml`'s `delete` key).
  - Non-owner admin (`users(:two)` on `accounts(:company)`) visiting the
    same page does NOT see the Delete control.
  - Owner visiting a personal account's edit page still does not see the
    control (unchanged existing behavior — `accounts(:one_personal)` or
    whichever personal-account fixture exists; check `test/fixtures/accounts.yml`
    for a `personal: true` fixture before assuming a name).

**NOT in scope:**

- `AccountsController#destroy` or its `require_account_owner!` before_action
  — already correct, already tested in `test/integration/accounts_test.rb:14,22`.
- `accounts/show.html.erb` — already correctly gated, do not touch.
- Any other view.

**Build order:**

1. **Test:** Write the three cases above in the integration test file.
   Run them first and confirm the owner/non-owner assertions fail against
   current code (the non-owner-sees-button assertion should currently fail
   because the bug makes the button appear).
2. **Implement:** Edit `app/views/accounts/edit.html.erb` line with the
   Delete `button_to`, changing the guard condition as described above.
3. **Verify:** `bin/rails test test/integration/accounts_edit_test.rb` (or
   wherever the tests were added), then `bin/rails test` for the full suite.

### Task 2 [Clone]: Fix %{user} interpolation on account_users/edit.html.erb

**Skills:** write-tests
**Reference:** Read [`app/views/account_users/edit.html.erb`] lines 1 and 22
— line 22's `.description` call already does
`t(".description", user: @account_user.user.name || @account_user.user.email)`;
replicate that exact interpolation argument for the `.title` call on line 1.
Read [`config/locales/en.yml`] around line 86 to confirm the `title` key's
`%{user}` placeholder.

**In scope:**

- In `app/views/account_users/edit.html.erb` line 1, change
  `t(".title")` to
  `t(".title", user: @account_user.user.name || @account_user.user.email)`.
- Add/extend an integration test (new file
  `test/integration/account_users_edit_test.rb`, or add to the existing
  `test/integration/account_users_test.rb` if you judge that a better fit)
  asserting `GET /accounts/:account_id/account_users/:id/edit` (check the
  actual route name/helper via `bin/rails routes | grep account_user` if
  unsure) renders the interpolated member name in the response body (e.g.
  `assert_match "Edit permissions for #{users(:two).name}"`) and does NOT
  contain the literal string `%{user}`.

**NOT in scope:**

- The `.description` interpolation on line 22 — already correct, don't
  touch.
- Any other translation key or view.

**Build order:**

1. **Test:** Write the integration test asserting the interpolated title
   and absence of a raw `%{user}` placeholder. Run it first and confirm it
   fails against current code.
2. **Implement:** Edit `app/views/account_users/edit.html.erb` line 1 as
   described above.
3. **Verify:** `bin/rails test test/integration/account_users_edit_test.rb`
   (or wherever added), then `bin/rails test` for the full suite.

**Checkpoint 1 review:** Once both Task 1 and Task 2 are done (they run in
parallel as a batch — Master runs this once the whole batch returns, not
per-task), run `review-changes-mini` covering both tasks together before
proceeding.

## Task Dependencies

- Tasks 1 and 2 touch entirely separate files (different views, different
  test files) and have no dependency on each other — run them in parallel.
