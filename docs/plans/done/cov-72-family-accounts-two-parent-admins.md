> Ticket: COV-72
> Branch: feature/cov-72-family-accounts-two-parent-admins

# Plan: Family accounts with two parent admins

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Add family schema constraints and deterministic membership cleanup | Master | ✅ |
| 2 | 1 | 1 | Normalize fixtures to one family per user | Master | ✅ |
| 3 | 1 | 1 | Add Account family lifecycle and safe subscription teardown | Master | ✅ |
| 4 | 1 | 2 | Add User family/default-family behavior and family terminology | Master | ✅ |
| 5 | 1 | 2 | Enforce membership uniqueness, two-parent capacity, and flat billing | Master | ✅ |
| 6 | 1 | 2 | Derive current account from membership and close nested-account creation | Master | ✅ |
| 7 | 1 | 3 | Make web signup create exactly one family | subagent | ✅ |
| 8 | 1 | 3 | Make API signup create exactly one family | subagent | ✅ |
| 9 | 1 | 3 | Remove account index/create/switch routes and dead controller actions | Master | ✅ |
| 10 | 1 | 4 | Remove desktop account switching and expose singular Family settings | subagent | ✅ |
| 11 | 1 | 4 | Remove fallback/native switching links and test-only switching | subagent | ✅ |
| 12 | 1 | 4 | Enable team accounts and rebuild development seeds | Master | ✅ |
| 13 | 2 | 5 | Link verified Google identities to existing users | Master | ✅ |
| 14 | 3 | 6 | Implement transactional family invitation acceptance | Master | ✅ |
| 15 | 3 | 6 | Enforce invitation capacity, admin role, and email binding | subagent | ✅ |
| 16 | 3 | 6 | Accept invitations during signup without a throwaway family | Master | ✅ |
| 17 | 4 | 7 | Implement owner-only parent removal and safe ownership transfer | subagent | ✅ |
| 18 | 4 | 7 | Guard login deletion for family owners | Master | ✅ |
| 19 | 4 | 7 | Make family deletion owner-only and cancel billable subscriptions first | Master | ✅ |
| 20 | 5 | 8 | Build invitation and acceptance disclosure UI | subagent | ✅ |
| 21 | 5 | 8 | Update family roster and destructive-action UI | Master | ✅ |
| 22 | 5 | 8 | Send receipts to both parents and verify billing access | Master | ✅ |
| 23 | 6 | 9 | Update and verify the live Loops invitation email | Master | ✅ |
| 24 | 6 | 10 | Refresh architecture and project-decision documentation | Master | ✅ |
| 25 | 6 | 10 | Run release verification and prepare the staging reset handoff | Master | |

## Prerequisites

- Design: [`docs/designs/cov-72-family-accounts-two-parent-admins.md`](../designs/cov-72-family-accounts-two-parent-admins.md)
- Dependency handoff: [`docs/designs/cov-71-monetization-family-audit.md`](../designs/cov-71-monetization-family-audit.md) remains active and must not be archived.
- Prototype: None.
- Feature branch exists: `feature/cov-72-family-accounts-two-parent-admins`.
- Before Rails commands, prepend `/Users/jordan/.local/share/mise/shims` to `PATH` and confirm `ruby -v` reports 4.0.5.
- Component catalog scanned: `AlertComponent`, `ButtonComponent`, `FormFieldComponent`, `TableComponent`, `AvatarComponent`, and `BadgeComponent` cover the UI. No new component is required.
- Use Jumpstart overrides under `app/` where available; do not unnecessarily modify vendored controller/model implementations under `lib/jumpstart/`.
- Approval confirms these planning assumptions:
  - Removed plural “Accounts” navigation becomes a singular “Family” link to the current family’s settings.
  - Archived prior families preserve billing history during invite acceptance, but still follow existing deletion behavior if their former owner later deletes their login. Permanent retention after user deletion requires a separate ownership/anonymization design.
- Before Task 24, identify the Claude-side source that generates `AGENTS.md`; do not edit the generated file directly.
- Browser/dashboard operations use an authenticated session. Jordan enters private email addresses, passwords, and authentication challenges.
- No staging database reset may occur before merge, exact-SHA deployment, successful admin-bootstrap evidence, and explicit destructive-action confirmation.

## Tasks

### Task 1 [Master]: Add family database constraints

**Skills:** safe-migration, write-tests
**Reference:** Read `db/migrate/20240222020825_add_index_to_account_users_for_account_id_and_user_id.rb`, `db/schema.rb`, and `test/migrations/add_signup_completion_required_to_users_test.rb`.

**In scope:**

- Generate `EnforceFamilyAccountConstraints`.
- Add `accounts.archived_at` with an index.
- Convert every account to `personal: false`, make `personal` non-null, and add `accounts_personal_must_be_false`.
- Deterministically retain one membership per user: oldest owned family first, otherwise oldest membership.
- Archive accounts left memberless and recalculate every affected `account_users_count`.
- Add a unique index on `account_users.user_id`.
- Include an `AIDEV-NOTE` explaining the destructive pre-production cleanup and non-restorable rollback data.

**NOT in scope:**

- New `users.account_id` columns, student data, production backfills, or database triggers.
- Removing the existing composite membership index.

**Build order:**

1. **Test:** add `test/migrations/enforce_family_account_constraints_test.rb` for the column/index, non-null false-only contract, named check constraint, unique user index, and corrected fixture counters.
2. **Implement:** generate and complete the migration; use migration-local table classes or SQL rather than application models.
3. **Verify:** run `bin/rails db:migrate`, `bin/rails db:rollback:primary STEP=1`, `bin/rails db:migrate`, then the migration test. Inspect all schema dumps and retain only the intended primary-schema change.

### Task 2 [Master]: Normalize the fixture catalog

**Skills:** write-tests
**Reference:** Read `test/fixtures/accounts.yml`, `account_users.yml`, `account_invitations.yml`, and the fixture rules in `AGENTS.md`.

**In scope:**

- Make each user appear in at most one `AccountUser`.
- Make `accounts(:company)` the two-parent family, with both parents admins.
- Reassign the former solo-account fixtures to users without another membership.
- Make all family fixtures non-personal and give each an exact `account_users_count`.
- Keep invitation fixtures on one-parent families so acceptance remains reachable.
- Add `test/models/family_fixture_contract_test.rb`.

**NOT in scope:**

- Factories, randomized fixture data, or deleting useful intent-named fixtures.
- Broad behavior-test rewrites unrelated to family assumptions.

**Build order:**

1. **Test:** assert globally unique fixture memberships, owner/admin membership, false-only personal state, accurate counters, and no family over two parents.
2. **Implement:** update the three fixture files while preserving association-by-label conventions.
3. **Verify:** `bin/rails test test/models/family_fixture_contract_test.rb`

### Task 3 [Master]: Add Account family behavior

**Skills:** write-tests
**Reference:** Read `app/models/account.rb`, `lib/jumpstart/app/models/account/types.rb`, `lib/jumpstart/app/models/account/billing.rb`, and Pay 11.6.2’s subscription-destruction behavior.

**In scope:**

- Add `active` and `archived` scopes without a default scope.
- Reject `personal: true` and expose `parents` as the existing admin users.
- Implement `archive!` without destroying Pay records.
- Implement `joinable_by?` for one-parent, student-free, non-active/non-`past_due` families; tolerate the absent `Student` association until that ticket ships.
- Add explicit active-and-`past_due` cancellation before destructive family deletion. Do not rely on Pay’s callback, which omits `past_due` and runs after commit.

**NOT in scope:**

- Student merging, default scopes, subscription-plan naming, or price-based logic.
- Permanent retention of an archive after its former owner explicitly deletes their login.

**Build order:**

1. **Test:** extend `test/models/account_test.rb` for scopes, parents, false-only validation, archive preservation, joinability blockers, and active/`past_due` cancellation-before-destroy behavior.
2. **Implement:** add the smallest model methods needed by later service/controller tasks.
3. **Verify:** `bin/rails test test/models/account_test.rb`
4. **Checkpoint 1 review:** run `review-changes-mini` once for Tasks 1–3.

### Task 4 [Master]: Add User family behavior and terminology

**Skills:** write-tests
**Reference:** Read `app/models/user.rb`, `lib/jumpstart/app/models/user/accounts.rb`, and `config/locales/en.yml`.

**In scope:**

- Add `User#family`, selecting the user’s one active membership.
- Override `create_default_account` in app-owned code to create one non-personal `"%{name}'s Family"` with the user as owner/admin.
- Ignore archived owned accounts when deciding whether a user needs a family.
- Add a transient, non-persisted invitation-signup flag that skips default creation.
- Change account/team/member terminology in `config/locales/en.yml` to user-facing family/parent language.
- Remove `personal_team_description`.

**NOT in scope:**

- Persisting a family foreign key on `users`.
- Changing model class names or Jumpstart database table names.

**Build order:**

1. **Test:** extend `test/models/user_test.rb` for one active family, default naming/ownership/admin status, archived ownership, and the invitation skip flag.
2. **Implement:** add the app-owned overrides and locale copy.
3. **Verify:** `bin/rails test test/models/user_test.rb`

### Task 5 [Master]: Enforce parent membership rules

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/models/account_user.rb`, `account_user/ownership.rb`, and `test/models/per_seat_subscription_test.rb`.

**In scope:**

- Generate an app-owned `app/models/account_user.rb` override.
- Preserve `Ownership` and `Roles`; omit `UpdatesSubscriptionQuantity` with an upgrade-warning `AIDEV-NOTE`.
- Require every family member to be an admin.
- Validate global user membership uniqueness and a maximum of two parents.
- Retain the database index as the race-condition backstop.
- Change per-seat regression coverage so adding/removing a second parent leaves quantity at `1`.

**NOT in scope:**

- Removing the reusable Jumpstart quantity concern or `Account#per_unit_quantity`.
- Database triggers or general-purpose roles.

**Build order:**

1. **Test:** extend `test/models/account_user_test.rb` and invert `test/models/per_seat_subscription_test.rb`.
2. **Implement:** generate the Jumpstart override and add the validations/includes.
3. **Verify:** `bin/rails test test/models/account_user_test.rb test/models/per_seat_subscription_test.rb`

### Task 6 [Master]: Derive the current family and close nested-account creation

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/concerns/set_current_request_details.rb`, `authentication.rb`, and `test/integration/multitenancy_test.rb`.

**In scope:**

- Generate app-owned overrides for both concerns.
- Resolve `Current.account` from `current_user.family`, never the signed account cookie.
- Create one default family only when the signed-in user genuinely has no membership.
- Remove `owned_accounts_attributes` from permitted signup parameters.
- Test stale/foreign cookies, archived families, and no-family fallback behavior.

**NOT in scope:**

- Changing configured domain/subdomain tenancy behavior beyond eliminating account selection for normal session tenancy.
- New cookies or client-side state.

**Build order:**

1. **Test:** rewrite the session-tenancy cases around a single family and prove stale account cookies cannot select another family.
2. **Implement:** generate the two concern overrides and remove nested account creation parameters.
3. **Verify:** `bin/rails test test/integration/multitenancy_test.rb test/controllers/users/registrations_controller_test.rb`
4. **Checkpoint 2 review:** run `review-changes-mini` once for Tasks 4–6.

### Task 7 [subagent]: Make web signup create one family

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/users/registrations_controller.rb` and `test/controllers/users/registrations_controller_test.rb`.

**In scope:**

- Generate the app-owned registrations-controller override.
- Remove the prebuilt `owned_accounts` branch.
- Let `User#create_default_account` create the one auto-named family.
- Prove ordinary signup produces one account, one membership, and owner/admin status.
- Prove crafted nested account attributes cannot create a second family.

**NOT in scope:**

- Invitation acceptance, login deletion, OAuth, or family-name input.
- Marketing-consent behavior changes.

**Build order:**

1. **Test:** add ordinary and crafted-request registration cases under team-account configuration.
2. **Implement:** remove controller-side family building while preserving existing Cove consent behavior.
3. **Verify:** `bin/rails test test/controllers/users/registrations_controller_test.rb`

### Task 8 [subagent]: Make API signup create one family

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/app/controllers/api/v1/users_controller.rb` and its existing controller test.

**In scope:**

- Generate an app-owned API users-controller override.
- Remove `owned_accounts.first_or_initialize`.
- Ignore/reject crafted nested account attributes through the shared sanitizer.
- Assert exactly one auto-named family and one owner/admin membership.

**NOT in scope:**

- New API family-management endpoints.
- Changes to token response shape.

**Build order:**

1. **Test:** replace the existing variable one-or-two-account expectation with the single-family contract.
2. **Implement:** remove the duplicate builder.
3. **Verify:** `bin/rails test test/controllers/api/v1/users_controller_test.rb`

### Task 9 [Master]: Remove account creation and switching routes

**Skills:** write-tests
**Reference:** Read `config/routes/accounts.rb`, `lib/jumpstart/app/controllers/accounts_controller.rb`, and `test/integration/accounts_test.rb`.

**In scope:**

- Retain only account `show`, `edit`, `update`, and `destroy`, plus nested transfer/parent/invitation routes.
- Remove `GET /accounts`, `GET /accounts/new`, `POST /accounts`, and `PATCH /accounts/:id/switch`.
- Generate an app-owned `AccountsController` without dead index/new/create/switch actions.
- Replace removed-index redirects with the current family or root.
- Remove the integration `switch_account` helper.

**NOT in scope:**

- Removing read-only API account `index/show`.
- Family deletion authorization, handled in Task 19.

**Build order:**

1. **Test:** update `test/integration/accounts_test.rb` to assert removed routes are unroutable and retained family-settings routes still work.
2. **Implement:** narrow routes, add the controller override, and remove the helper.
3. **Verify:** `bin/rails test test/integration/accounts_test.rb`
4. **Checkpoint 3 review:** after Tasks 7–9 return, the master runs `review-changes-mini` once for the whole checkpoint.

### Task 10 [subagent]: Remove desktop account switching

**Skills:** write-tests, style-ui
**Reference:** Read the app navigation partials and `test/system/app_shell_system_test.rb`.
**Prototype:** None — preserve the current shell layout.

**In scope:**

- Remove the account-switcher render from `_left_nav`.
- Remove the now-unused `_account_menu`.
- Replace the plural Accounts link in `_user_menu` with singular Family → `account_path(current_account)`.
- Replace the switching system test with direct Family-settings navigation coverage.

**NOT in scope:**

- Redesigning the menus or adding a new navigation component.
- Native navigation, handled separately.

**Build order:**

1. **Test:** update `test/system/app_shell_system_test.rb` for no account menu and a working Family link.
2. **Implement:** update the three app partials.
3. **Verify:** `bin/rails test:system test/system/app_shell_system_test.rb`

### Task 11 [subagent]: Remove fallback/native switching surfaces

**Skills:** write-tests, style-ui
**Reference:** Read the vendored `_account_navbar`, `_navbar.html+native`, account show view, and system-test account helper.
**Prototype:** None.

**In scope:**

- Replace plural Accounts links with the current Family settings route.
- Remove the account-show switch button.
- Remove the appended test-only switch route and system helper.
- Record native-navbar visual verification as blocked without a simulator.

**NOT in scope:**

- Native-app redesign or simulator setup.
- Account-settings content.

**Build order:**

1. **Test:** add route/link assertions to the existing account and app-shell coverage.
2. **Implement:** update the two vendored navigation partials, account show header, and system-test base class.
3. **Verify:** run the focused account and app-shell tests.

### Task 12 [Master]: Enable team accounts and rebuild seeds

**Skills:** write-tests
**Reference:** Read `config/jumpstart.rb`, `db/seeds.rb`, and `test/config/seeds_test.rb`.

**In scope:**

- Hand-edit `account_types` from `"personal"` to `"team"`; never use the Jumpstart config generator.
- Seed one two-parent family with both parents admins.
- Seed a separate subscribed family whose quantity remains `1`.
- Remove the three-member team and all personal-account assumptions.
- Preserve the `Rails.env.local?` guard and idempotency.

**NOT in scope:**

- A root `Procfile`, production seeds, real Stripe IDs, or staging mutation.
- Student/demo records.

**Build order:**

1. **Test:** extend the seed test with a development-path structure/idempotency case.
2. **Implement:** hand-edit configuration and rebuild local seed relationships.
3. **Verify:** run `bin/rails test test/config/seeds_test.rb`, then reset/seed a disposable local database and inspect the resulting family/member counts.
4. **Checkpoint 4 review:** run `review-changes-mini` once for Tasks 10–12. Phase 1 must be fully green before deployment because the team flip, schema constraint, signup path, routes, and navigation are coupled.

### Task 13 [Master]: Link verified Google identities

**Skills:** write-tests
**Reference:** Read `lib/jumpstart/lib/jumpstart/omniauth/callbacks.rb`, `test/integration/jumpstart/omniauth_callbacks_test.rb`, and `test/integration/users/google_oauth_test.rb`.

**In scope:**

- Treat a present `auth.info.email` from the locked Google adapter as verified.
- Match existing users case-insensitively.
- Attach the new `ConnectedAccount`, sign in the existing user, and show explicit link confirmation.
- Refuse when verified email is absent or when the user already has a different Google UID.
- Preserve known-UID sign-in and brand-new OAuth signup behavior.
- Assert no second `User`, family, or membership is created.

**NOT in scope:**

- Merging two existing user rows or changing stored OAuth payloads.
- Additional OAuth providers.

**Build order:**

1. **Test:** add verified match, case-insensitive match, unverified/missing email, and different-Google-identity cases.
2. **Implement:** update the existing callback branch with an `AIDEV-NOTE`.
3. **Verify:** run both OAuth integration test files.
4. **Checkpoint 5 review:** run `review-changes-mini` once for Task 13.

### Task 14 [Master]: Implement family invitation acceptance

**Skills:** write-tests
**Reference:** Read `app/services/admin_bootstrap.rb`, `app/models/account.rb`, and `lib/jumpstart/app/models/account_invitation.rb`.

**In scope:**

- Add `FamilyInvitationAcceptance` with `.new(invitation:, user:).call`.
- Return a clear result/errors contract for success, cancel-Premium-first, contact-support, wrong-email, already-in-family, full-family, and race outcomes.
- Lock the user, source family, and target family.
- In one transaction: remove the old membership, archive the joinable old family, add the target admin membership, and consume the invitation.
- Preserve the archived family and Pay history.
- Rescue unique-index races into a user-facing family-membership error.

**NOT in scope:**

- Student merging, support tooling, or deleting archived families.
- Controller redirects or view copy.

**Build order:**

1. **Test:** add `test/services/family_invitation_acceptance_test.rb` covering every outcome, rollback, archive preservation, admin role, and concurrent backstops.
2. **Implement:** add the service and an app-owned `AccountInvitation` override/delegation surface.
3. **Verify:** run the service and account-invitation model tests.

### Task 15 [subagent]: Enforce invitation creation and acceptance guards

**Skills:** write-tests
**Reference:** Read both existing invitation controllers and their integration tests.

**In scope:**

- Generate app-owned nested and public invitation controller overrides.
- Force `admin: true`; remove role parameters.
- Reject case-insensitive existing-family emails, duplicate emails, and invitations when the member-plus-pending-invite capacity is exhausted.
- Bind acceptance to `current_user.email` case-insensitively.
- Delegate existing-user acceptance to `FamilyInvitationAcceptance`.
- Redirect to the joined family or actionable billing/support destination.

**NOT in scope:**

- Invitation signup or view layout.
- Adding a third role.

**Build order:**

1. **Test:** update both invitation integration suites for capacity, forced admin, email binding, blocker-specific messages, and direct-POST guards.
2. **Implement:** add thin controller overrides.
3. **Verify:** run both invitation integration test files.

### Task 16 [Master]: Accept invitations during signup

**Skills:** write-tests
**Reference:** Read the app-owned registrations controller from Task 7 and `test/integration/account_invitations_test.rb`.

**In scope:**

- Set the invitation skip-default-family flag before user persistence.
- Bind the submitted email unconditionally to the invitation email.
- Use `FamilyInvitationAcceptance` after signup.
- Prove no temporary or orphan family is created.
- Preserve account-created email and marketing-consent behavior.
- Update the end-to-end invitation system test for one-family semantics.

**NOT in scope:**

- Existing-user acceptance logic already owned by Task 15.
- Marketing opt-in for invited users.

**Build order:**

1. **Test:** add exact account/membership count assertions, crafted-email rejection, mail behavior, and the end-to-end new-invitee path.
2. **Implement:** extend the registrations override.
3. **Verify:** run the registrations, invitation integration, and invitation system tests.
4. **Checkpoint 6 review:** after Tasks 15–16 return, the master runs `review-changes-mini` once for Tasks 14–16.

### Task 17 [subagent]: Remove a second parent safely

**Skills:** write-tests
**Reference:** Read `AccountUsersController`, `Accounts::TransfersController`, and their integration tests.

**In scope:**

- Make parent removal owner-only.
- Transactionally remove the non-owner and create their fresh empty family.
- Leave the original family, owner, and subscription untouched.
- Keep ownership transfer owner-only and limited to the other existing parent.
- Prove transfer followed by old-owner login deletion preserves the family and subscription.
- Replace removed `accounts_path` redirects.

**NOT in scope:**

- Separation/student transfer workflows.
- Removing the owner directly.

**Build order:**

1. **Test:** rewrite former regular-member tests around two admin parents and add removal/transfer/subscription cases.
2. **Implement:** generate the two controller overrides.
3. **Verify:** run account-user and transfer integration tests.

### Task 18 [Master]: Guard login deletion

**Skills:** write-tests
**Reference:** Read the app registrations override, `Api::V1::MeController`, and their tests.

**In scope:**

- Block an owner with another parent and direct them to transfer ownership.
- Permit a sole owner to delete their login and family.
- Permit a non-owner parent to delete their login, leaving the family and subscription intact.
- Apply the same rules to web and API deletion.
- Preserve archived-family behavior according to the approved assumption.

**NOT in scope:**

- Soft deletion, anonymization, or permanent archive retention after explicit login deletion.
- New recovery flows.

**Build order:**

1. **Test:** add web/API cases for all three roles and subscription preservation.
2. **Implement:** extend the registrations override and add an app-owned API `MeController`.
3. **Verify:** run both controller test files.

### Task 19 [Master]: Delete a family safely

**Skills:** write-tests
**Reference:** Read the app-owned `AccountsController`, `Account#cancel_billable_subscriptions!`, and account integration tests.

**In scope:**

- Require ownership, not merely admin status.
- Cancel active and `past_due` subscriptions before deleting local records.
- Abort deletion if remote cancellation fails.
- Redirect safely without the removed account index.
- Test owner success, second-parent refusal, active cancellation, and `past_due` cancellation.

**NOT in scope:**

- Refunds, grace periods, or Stripe configuration.
- Deleting archived families during invitation acceptance.

**Build order:**

1. **Test:** add controller-level authorization and cancellation-order coverage.
2. **Implement:** extend the Accounts override with a thin owner guard and model delegation.
3. **Verify:** run account model and integration tests.
4. **Checkpoint 7 review:** run `review-changes-mini` once for Tasks 17–19.

### Task 20 [subagent]: Build invitation disclosure UI

**Skills:** write-tests, style-ui
**Reference:** Use the scanned `AlertComponent`, `FormFieldComponent`, and `ButtonComponent` APIs.
**Prototype:** None — preserve current page hierarchy.

**In scope:**

- Remove invitation role pickers from new/edit screens.
- Add the static admin/billing disclosure with `AlertComponent variant: :info`.
- Add matching acceptance/signup disclosure.
- Keep labels visible and use existing form components.
- Preserve the existing invite name/email fields and actions.

**NOT in scope:**

- New components, layout redesign, or dynamic HTML in alert descriptions.
- Loops email content, handled in Task 23.

**Build order:**

1. **Test:** rely on and extend the invitation render assertions from Tasks 15–16 for no role controls and exact disclosure content.
2. **Implement:** update the four invitation/signup views.
3. **Verify:** run both invitation integration suites and the registration controller test.

### Task 21 [Master]: Update family roster and destructive-action UI

**Skills:** write-tests, style-ui
**Reference:** Use `TableComponent`, `BadgeComponent`, `AlertComponent`, and `ButtonComponent`.
**Prototype:** None — retain the existing settings layout.

**In scope:**

- Show at most two parents and pending invitations.
- Label the owner and show “Admin · can manage billing” under the second parent.
- Show Invite only when a slot is available.
- Show parent removal only to the owner.
- Show family deletion only to the owner, with immediate-end/no-refund confirmation.
- On login settings, replace the owner-with-parent delete button with a transfer warning/link; give non-owner deletion accurate copy.

**NOT in scope:**

- New roster layout, student rows, or separation workflows.
- Changing visual hierarchy beyond the required conditional content.

**Build order:**

1. **Test:** extend existing account, account-user, and registration render assertions for every conditional state.
2. **Implement:** update account show/edit and registration edit views plus Devise deletion copy.
3. **Verify:** run the focused integration/controller tests and `test/system/team_invitation_system_test.rb`.

### Task 22 [Master]: Verify billing access and receipt delivery

**Skills:** write-tests
**Reference:** Read `config/initializers/pay.rb`, account receipt tests, subscription tests, checkout tests, and Loops recipient fan-out coverage.

**In scope:**

- Send receipts to all family admins plus optional `billing_email`, deduplicated.
- Leave `Account::Billing#email` unchanged as the Stripe customer email.
- Prove the non-owner parent can open billing and start checkout.
- Prove adding/removing the second parent never changes subscription quantity.
- Preserve recipient-specific Loops idempotency behavior.

**NOT in scope:**

- Real Stripe staging configuration, pricing changes, or COV-78 work.
- Sending billing mail to non-parent contacts.

**Build order:**

1. **Test:** add both-parent receipt assertions and convert former regular-member billing tests to second-parent success cases.
2. **Implement:** update only the Pay recipient lambda; rely on the earlier role and quantity changes.
3. **Verify:** run account, subscription, checkout, per-seat, and Loops-delivery tests.
4. **Checkpoint 8 review:** run `review-changes-mini` once for Tasks 20–22.

### Task 23 [Master]: Update the live Loops invitation

**Skills:** loops-cli, loops-lmx, loops-email-sending-best-practices
**Reference:** Fetch transactional ID `cmsdr01rw02s00j3ozshehy4f` fresh from team `cove-cli`; do not trust the historical message ID.

**In scope:**

- Unset ambient `LOOPS_API_KEY`, select `--team cove-cli`, and verify team identity.
- Fetch the current message and revision.
- Preserve the three-variable contract: `inviter_name`, `account_name`, `invitation_url`.
- Add family terminology and the admin/billing/receipt disclosure.
- Apply the update revision-safely, preview, publish, and trigger one real invitation.
- Let Jordan privately supply the verification recipient and confirm received rendering/CTA.

**NOT in scope:**

- Creating a duplicate transactional email.
- Persisting API keys, recipient addresses, or private inbox screenshots.

**Build order:**

1. **Test:** validate the revised LMX locally and preview against representative variables.
2. **Implement:** update the existing message using its current revision, then publish.
3. **Verify:** inspect the fetched published content and confirm one real received email.
4. **Checkpoint 9 review:** run `review-changes-mini` once over the external-state evidence for Task 23.

### Task 24 [Master]: Refresh architecture and project decisions

**Skills:** engineering:documentation
**Reference:** Read the final implementation and the architecture diagrams used during preflight.

**In scope:**

- Update `docs/architecture/data-model.mermaid` for archived families and the one-membership constraint.
- Update `docs/architecture/routes-map.mermaid` for the reduced account routes.
- Update `docs/architecture/app-structure.mermaid` for the acceptance service and app-owned Jumpstart overrides.
- Record the family decisions in the source that generates `AGENTS.md`, then regenerate it through the established one-way process.
- Document flat-per-family billing, two admin parents, owner-only destructive actions, no switching, and archived-family behavior.

**NOT in scope:**

- Editing generated `AGENTS.md` directly.
- Archiving the active COV-71 audit.
- Product documentation for students, complimentary Premium, or COV-78.

**Build order:**

1. **Test:** compare the implemented schema/routes/service paths with all three diagrams and list stale nodes.
2. **Implement:** update the diagrams and, once identified, the authoritative Claude-side project-decision source.
3. **Verify:** render/parse the Mermaid files where supported and inspect the regenerated `AGENTS.md` diff.

### Task 25 [Master]: Run release verification and prepare staging

**Skills:** review-changes-mini, browser:control-in-app-browser
**Reference:** Follow the mise, schema-drift, Render, and linked-worktree rules in `AGENTS.md`.

**In scope:**

- Run migration status, the full Rails suite, system tests, RuboCop, `git diff --check`, `git diff`, and `git status --short`.
- Browser-smoke signup, family settings, invite/acceptance blockers, parent removal, transfer, login deletion guard, billing access, and removed routes.
- Confirm native navbar remains a named visual-verification limitation if no simulator is available.
- Before merge, behaviorally verify `BOOTSTRAP_ADMIN_EMAIL`: Jordan privately supplies a new staging address, Render redeploys, and `/admin` access is confirmed while the existing admin remains available.
- Record real Stripe receipt/cancellation verification as deferred to COV-78 because staging lacks a usable Stripe plan/subscription.

**NOT in scope:**

- Merging the PR.
- Resetting staging before the merged SHA deploys and Jordan confirms the destructive action.
- Production configuration or live-mode Stripe work.

**Build order:**

1. **Test:** run `ruby -v`, `bin/rails db:migrate:status`, `bin/rails test`, `bin/rails test:system`, and `bin/rubocop`.
2. **Implement:** fix only task-scoped failures; remove debug artifacts and unrelated schema noise.
3. **Verify:** run `git diff --check`, `git diff origin/main...`, and `git status --short`; complete the browser smoke test and pre-merge bootstrap proof.
4. **Checkpoint 10 review:** run `review-changes-mini` once for Tasks 24–25, after all code, docs, external state, and verification evidence are available.

## Task Dependencies

- Tasks 1–6 are sequential shared foundations. Their migration, fixtures, base models, and request context must not be delegated concurrently.
- Tasks 7 and 8 can run in parallel after Task 6. Task 9 can proceed alongside them because its file set is separate, but checkpoint 3 waits for all three.
- Tasks 10 and 11 can run in parallel after Task 9. Task 12 runs after both so the `"team"` flip never leaves stale route helpers or navigation.
- Task 13 depends on Phase 1’s single-family creation.
- Task 14 establishes the acceptance contract. Tasks 15 and 16 can run in parallel only after Task 14.
- Tasks 17–19 depend on the one-family invariant and acceptance service. They touch separate controllers but remain sequential where an app override is shared.
- Tasks 20–22 can run as a parallel batch after the lifecycle behavior and locale contract are stable.
- Task 23 is sequential external state and runs only after the final invitation copy is approved in-app.
- Task 24 waits for all implementation paths to settle. Its `AGENTS.md` portion is blocked until the authoritative generator source is identified.
- Task 25 depends on all earlier tasks.
- Jordan reviews and merges the pull request; no agent merges it.
- After Jordan reports the merge and explicitly asks to continue, verify the PR and exact Render-deployed SHA. Require successful bootstrap logs before requesting confirmation to reset/re-provision only `cove-staging-db`.
- After explicit destructive confirmation, reset/re-provision staging, verify `DATABASE_URL` relinking, redeploy, and require a second successful bootstrap on the clean database.
- Then verify no `@cove.test` demo users remain, `/admin` works, removed account routes return unavailable responses, signup creates one family, and verified Google linking creates no duplicate user/family.
- If browser control, authentication, Render relinking proof, or inbox access is unavailable, report the exact evidence gap as blocked rather than inferring success.
