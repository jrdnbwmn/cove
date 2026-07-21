> Ticket: COV-24
> Branch: jrdnbwmn/cov-24-fixtures-test-convention
> Plan created: docs/plans/test-data-convention.md

# Feature: Fixtures-only test-data convention

## Problem
Feature slices are about to start landing, and without a written rule each
slice will invent its own way of providing test data (fixtures vs. factories
vs. inline setup). This locks in one convention — fixtures-only — and writes
it where every slice will see it, so slices are faster to build and review.

## Approach
Document the already-settled convention in `AGENTS.md` under the existing
`## Testing` section as a new `### Test data` subsection. The convention
mirrors what the current Jumpstart suite already does (`accounts.yml`,
`users.yml`, `account_users.yml`, `plans.yml`), so there is nothing new to
build — the existing fixtures *are* the reference implementation.

**Decision (settled — do not reopen without a product call):**
- **Fixtures-only.** Minitest fixtures in `test/fixtures/*.yml`, the
  Jumpstart/Rails default already in use.
- **No FactoryBot, no Faker** — no new gems. Values are hand-written literals.
- Rationale: zero new machinery, fixtures double as a readable data catalog,
  and it matches how the existing suite already works.

**No new test helper.** The ticket allowed a thin `sign_in_as` / `switch_account`
helper *only if it removed real duplication*. It doesn't — both already exist:
- `sign_in(user)` — provided by Devise's `Test::IntegrationHelpers`, already
  included in `test_helper.rb` and used across ~20 test files.
- `switch_account(account)` — already defined in `test_helper.rb` (integration
  tests) and `application_system_test_case.rb` (system tests).

Adding a `sign_in_as` alias would just be a redundant wrapper over Devise's
`sign_in`. Instead the doc points slices at these two existing helpers.

## Acceptance Criteria
- The convention is written into `AGENTS.md` under `## Testing` where slices
  will see it, covering: fixtures-only, naming, association-by-label,
  ERB-for-computed-values, the no-FactoryBot/Faker rule, and the existing
  sign-in / switch-account helpers.
- No new gems and no new test helper are added.
- `bin/rails test` stays green (documentation-only change, so this is a
  regression check, not new coverage).

## Prototype
None.

## Data Model
No model or schema changes. This ticket only documents how fixtures are
authored. The existing fixtures are the reference:
- `test/fixtures/accounts.yml`, `users.yml`, `account_users.yml`,
  `plans.yml` — show generic + intent-named records and label references.

## Screens / Flows
None (no UI).

## Convention to document (content for `AGENTS.md` → `## Testing` → `### Test data`)

**Fixtures-only.** Test data lives in `test/fixtures/<table>.yml` (Minitest
fixtures, the Jumpstart/Rails default). Every new model gets a fixture file
with a small, named, hand-written set of records.

- **No FactoryBot, no Faker, no new gems.** Values are hand-written literals.
  If a slice believes it genuinely needs a factory library, stop and raise it
  as a product decision first — do not add it unilaterally.
- **Naming.** Use generic labels `one` and `two` for the baseline records,
  plus intent-named labels for records that exist to exercise a specific state
  (e.g. `subscribed`, `invited`, `admin`, `hidden`). This matches the existing
  `accounts.yml` / `users.yml` style and lets fixtures double as a readable
  data catalog.
- **Associations by label, never IDs.** Reference other fixtures by their
  fixture name (`owner: one`, `account: company`, `user: two`). Rails resolves
  the label to the record's id at load time. Never hard-code numeric ids.
- **Literals by default; ERB only for computed values.** Prefer plain literal
  values. Use ERB only where a literal can't express the value — e.g.
  timestamps (`<%= Time.current %>`) or derived secrets
  (`<%= Devise::Encryptor.digest(User, UNIQUE_PASSWORD) %>`), as `users.yml`
  already does. Don't use ERB to generate fake/random data.
- **Signing in / switching accounts in tests.** Reuse the existing helpers —
  don't reinvent them:
  - `sign_in(user)` (Devise) in integration and system tests.
  - `switch_account(account)` (defined in `test_helper.rb` and
    `application_system_test_case.rb`) to set the current account.

## Scope
**In:**
- Add the `### Test data` subsection to `AGENTS.md`.
- Confirm `bin/rails test` is green.

**Deferred:**
- Dev/demo seed data in `db/seeds.rb` — ticket COV-25.
- Per-slice seed pattern — ticket COV-26.

## Open Questions
None.
