> Ticket: COV-25
> Branch: jrdnbwmn/cov-25-dev-seeds

# Plan: Baseline dev/demo seeds (db/seeds.rb)

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1    | Prod-guarded shell + five personas (users)                        | Master |      |
| 2    | "Cove Team" account + three-role memberships                      | Master |      |
| 3    | Fake Plan + active subscription for subscribed persona            | Master |      |
| 4    | Grant system admin to superadmin persona                          | Master |      |
| 5    | README "Dev login credentials" section                            | Master |      |
| 6    | Full verification (fresh DB seed, idempotency, logins, test suite)| Master |      |

## Prerequisites

- Design: `docs/designs/baseline-dev-seeds.md`
- Prototype: None
- Feature branch `jrdnbwmn/cov-25-dev-seeds` already exists ✓

**A note on testing (read before starting):** `db/seeds.rb` is not test-driven —
per AGENTS.md and the design, the test suite is driven by `test/fixtures/*`, not
seeds. There is deliberately **no Minitest** for these tasks. The "test" for this
feature is the manual verification in Task 6 (fresh-DB seed → idempotent re-run →
per-persona login → `bin/rails test` still green). Do not add a seed unit test;
it's out of scope and non-conventional.

Everything here is Master-assigned: it's all one shared file (`db/seeds.rb`) built
up sequentially, so there's nothing to parallelize across clones.

**Environment reminder:** prepend `export PATH="$HOME/.local/share/mise/shims:$PATH"`
before any `bin/rails` command in this checkout. Confirm `ruby -v` reports 4.0.5
before trusting output.

## Tasks

### Task 1 [Master]: Prod-guarded shell + five persona users

**Reference:** `lib/jumpstart/app/models/user/agreements.rb` (terms/confirmation),
`lib/jumpstart/app/models/user/profile.rb` (`has_person_name` → `name=`),
`test/fixtures/users.yml` (confirmed-user shape).

**In scope:**

- Replace the stock comments in `db/seeds.rb` with a `unless Rails.env.production?` block.
- Add an `AIDEV-NOTE` documenting the `account_types` / `personal_accounts?` assumption
  (auto-personal-account hook must fire) called out in the design.
- Create the five users idempotently via `User.find_or_create_by!(email:) do |u| … end`.
  In the block set: `u.name = "…"`, `u.password = "password"`,
  `u.terms_of_service = "1"`, `u.confirmed_at = Time.current`.
- Personas: `owner@cove.test` (Olivia Owner), `admin@cove.test` (Andy Admin),
  `member@cove.test` (Molly Member), `subscribed@cove.test` (Sofia Subscriber),
  `superadmin@cove.test` (Sydney Super).
- Store the created users in locals (e.g. `owner`, `admin`, `member`) for later tasks.

**NOT in scope:**

- Team account, memberships, roles (Task 2).
- Subscription or plan (Task 3).
- System admin grant (Task 4).

**Build order:**

1. **Implement:** Edit `db/seeds.rb` as above.
2. **Verify:** `bin/rails db:seed` then
   `bin/rails runner 'puts User.where("email like ?", "%@cove.test").pluck(:email, :name).inspect'`
   — expect all five with names, each with an auto-created personal account
   (`u.personal_account.present?`).
3. **Review:** Run review-changes before proceeding. Not optional.

### Task 2 [Master]: "Cove Team" account + three-role memberships

**Reference:** `test/fixtures/accounts.yml` + `account_users.yml` (team + role shape);
design notes on `AccountUser::ROLES == [:admin]`.

**In scope:**

- `team = Account.find_or_create_by!(name: "Cove Team", owner: owner)` with
  `personal: false` set in the create block.
- Idempotent memberships via `AccountUser.find_or_create_by!(account: team, user:)`
  for all three, then assign roles:
  - owner → `roles: { admin: true }`
  - admin → `roles: { admin: true }`
  - member → no roles (plain member)
- Set/update roles on each `AccountUser` after find-or-create so a re-run reconciles
  them (and never duplicates join rows).

**NOT in scope:**

- Any billing/subscription on this account.
- Adding `subscribed`/`superadmin` to the team.

**Build order:**

1. **Implement:** Extend `db/seeds.rb`.
2. **Verify:** `bin/rails db:seed` twice, then
   `bin/rails runner 'a=Account.find_by(name:"Cove Team"); puts a.account_users.map{|au|[au.user.email, au.roles]}.inspect; puts AccountUser.where(account:a).count'`
   — expect 3 rows both runs (owner+admin admin:true, member empty).
3. **Review:** Run review-changes before proceeding. Not optional.

### Task 3 [Master]: Fake Plan + active subscription for subscribed persona

**Reference:** `test/integration/subscriptions_test.rb:60-66`
(`set_payment_processor :fake_processor, allow_fake: true` →
`payment_processor.subscribe(plan: plan.fake_processor_id)`);
`test/fixtures/plans.yml` (`fake_processor_id`).

**In scope:**

- Seed one minimal plan: `Plan.find_or_create_by!(fake_processor_id: "cove_dev")`
  with name/amount/interval in the block (mirror the `per_seat`/`enterprise`
  fixture shape).
- On `subscribed`'s personal account: `set_payment_processor :fake_processor, allow_fake: true`,
  then guard `unless account.payment_processor&.subscribed?` before
  `payment_processor.subscribe(plan: plan.fake_processor_id)`.
- Use `subscribed.personal_account` (auto-created in Task 1) as the target account.

**NOT in scope:**

- Broader plan catalog / multiple billing states (deferred per design).
- Real Stripe/processor sync.

**Build order:**

1. **Implement:** Extend `db/seeds.rb`.
2. **Verify:** `bin/rails db:seed` twice, then
   `bin/rails runner 'u=User.find_by(email:"subscribed@cove.test"); puts u.personal_account.payment_processor.subscribed?'`
   — expect `true` both runs; `Plan.where(fake_processor_id:"cove_dev").count` → 1.
3. **Review:** Run review-changes before proceeding. Not optional.

### Task 4 [Master]: Grant system admin to superadmin persona

**Reference:** `lib/jumpstart/lib/jumpstart.rb:36` (`grant_system_admin!`).

**In scope:**

- `Jumpstart.grant_system_admin!(superadmin)` after the user exists (plain UPDATE,
  naturally idempotent).

**NOT in scope:**

- Any admin data beyond the flag.

**Build order:**

1. **Implement:** Extend `db/seeds.rb`.
2. **Verify:** `bin/rails db:seed`, then
   `bin/rails runner 'puts User.find_by(email:"superadmin@cove.test").admin?'` → `true`.
3. **Review:** Run review-changes before proceeding. Not optional.

### Task 5 [Master]: README "Dev login credentials" section

**Reference:** current `README.md` (very sparse — "Cove app").

**In scope:**

- Add a "Dev login credentials" section: the five emails, the shared password
  `password`, a one-line note that all are pre-confirmed, and the
  `bin/rails db:seed` pointer. Table mirroring the design's roster is fine.

**NOT in scope:**

- Broader README restructuring.

**Build order:**

1. **Implement:** Edit `README.md`.
2. **Verify:** Visual read-through; confirm every seeded email is listed and matches
   `db/seeds.rb`.
3. **Review:** Run review-changes before proceeding. Not optional.

### Task 6 [Master]: Full verification

**In scope:**

- Fresh DB: `bin/rails db:drop db:create db:migrate db:seed` (dev env).
- Re-run `bin/rails db:seed` and confirm no new rows (idempotency) via record counts
  before/after.
- Confirm each persona signs in with its email + `password` (boot a temp server +
  drive `/users/sign_in`, or at minimum assert `User#valid_password?("password")`
  and `confirmed?` for each).
- Spot-check states: subscribed account `subscribed?`, superadmin `admin?`,
  "Cove Team" three roles.
- `bin/rails test` — confirm the suite still passes (fixtures unaffected).

**NOT in scope:**

- Any code changes (this is verification only; fixes loop back to the relevant task).

**Build order:**

1. **Verify:** Run all commands above, showing output.
2. **Review:** Final review-changes over the full diff. Not optional.

## Task Dependencies

- Task 1 must be first — later tasks reference the user locals (`owner`, `admin`,
  `member`, `subscribed`, `superadmin`) and the auto-created personal accounts.
- Task 2 depends on Task 1 (needs `owner`/`admin`/`member`).
- Task 3 depends on Task 1 (needs `subscribed` + its personal account).
- Task 4 depends on Task 1 (needs `superadmin`).
- Tasks 2, 3, 4 are logically independent of each other but all edit the same
  `db/seeds.rb`, so run them sequentially (no clone parallelism).
- Task 5 (README) can be done any time after the persona list is settled
  (i.e., after Task 1).
- Task 6 is last — verifies the whole file end-to-end.
