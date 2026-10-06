> Ticket: COV-109
> Branch: chore/cov-109-rename-students-to-learners

# Plan: Rename "students" to "learners"

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Swap student → learner in locale copy (`en.yml` values) | Master | ✅   |
| 2    | 1     | 1          | Swap copy on Terms + Privacy, bump "Last updated" | Clone  | ✅   |
| 3    | 1     | 1          | Swap hardcoded copy: public pages, sidebar, dev pages, previews | Clone  | ✅   |
| 4    | 2     | 2          | Migration: rename table, column, indexes | Master |      |
| 5    | 2     | 2          | Rename app code: model, controllers, routes, views, CSS, locale keys | Master |      |
| 6    | 2     | 2          | Rename tests and fixtures; full suite green | Master |      |
| 7    | 3     | 3          | Update living docs: product docs + AGENTS.md | Clone  |      |
| 8    | 3     | 3          | Update architecture diagrams + component catalog | Clone  |      |
| 9    | 3     | 3          | Final sweep: grep, full + system tests, rollback, browser check | Master |      |

## Prerequisites

- Design: `docs/designs/rename-students-to-learners.md`
- Prototype: None (visual design unchanged — this is a word swap)
- Feature branch exists: `chore/cov-109-rename-students-to-learners`
- Shell: `export PATH="$HOME/.local/share/mise/shims:$PATH"` before any
  `bin/rails` / `bin/rubocop`; confirm `ruby -v` reports 4.0.5.

## Why this order (differs from the design's checkpoint order)

The design listed database → code → copy → docs. This plan does **copy
first**. Copy is the only part that needs judgment (which words are
user-facing text). Once every user-visible "student" is already "learner",
Phase 2 becomes a blind, mechanical rename of everything left, with no risk
of leaving half-changed sentences. Each phase still leaves the app working
and tests green.

## Open questions from the design — resolved

- **`filter_parameter_logging.rb`** filters by attribute name (`:name`,
  `:grade_level`), not model name. Only its AIDEV-NOTE comment changes.
- **Render migrations before boot:** yes — `render.yaml` `startCommand` is
  `bundle exec rails db:prepare admin:bootstrap && bundle exec rails server`.
  During a zero-downtime deploy the *old* instance can serve for a few
  seconds after the new one migrates, so staging may show a brief error.
  Acceptable for staging-only; no action.
- **Missing translations raise in tests:** yes —
  `config.i18n.raise_on_missing_translations = true` in `test.rb` and
  `development.rb`. A missed locale-key rename fails loudly.

## Rename map (applies to all Phase 2 tasks)

Apply in this order, case-sensitive, so longer forms are replaced first:

| From | To |
|---|---|
| `Students` | `Learners` |
| `students` | `learners` |
| `STUDENT` | `LEARNER` (e.g. `FREE_STUDENT_LIMIT`) |
| `Student` | `Learner` |
| `student` | `learner` |

This covers identifiers (`students_path`, `@student`, `student_limit`,
`has_students`, `students_nav_active?`), i18n keys (`students.index.title`,
`activerecord.errors.models.student`), CSS (`--student-sage`,
`.student-color`, `data-student-color`), data attributes
(`data-student-actions`, `data-student-card-link`, `data-student`), and
file/directory names. Every "a student" becomes "a learner" (same article),
so no grammar fixes are needed.

**Never touch** (allowed leftovers): `db/migrate/*` files that already
exist, `docs/plans/done/`, `docs/designs/done/`,
`docs/designs/rename-students-to-learners.md`, this plan.

Rename files with `git mv` so history follows them.

## Tasks

### Task 1 [Master]: Swap student → learner in locale copy (`en.yml` values)

**Skills:** write-tests
**Reference:** `config/locales/en.yml`, `docs/product/ux-notes.md`

**In scope:**

- In `config/locales/en.yml`, change "student"/"students"/"Student"/"Students"
  **inside quoted values only** (about 40 values, e.g. lines ~55, 131,
  296–315, 350–356, 375–376, 548–549, 708–710, 720–792, 830–839).
- Update every test that asserts on that copy to expect "learner" wording.

**NOT in scope:**

- YAML **keys** (`students:`, `has_students:`, `more_students_html:`,
  `student:` under `activerecord.errors.models`, `student_limit_free:`) and
  interpolation names (`%{student_limit}`). Those are renamed in Task 5.
- Hardcoded view copy (Tasks 2–3). Ruby identifiers, routes, URLs.

**Build order:**

1. **Test:** Find text assertions: `grep -rn -i "student" test | grep -i
   "assert_text\|assert_select\|assert_match\|assert_includes\|assert_equal\|has_text\|has_content"`.
   Change the expected strings that come from `en.yml` to "learner" wording.
   Run `bin/rails test` — expect failures (red).
2. **Implement:** Edit the `en.yml` values. If any line reads awkwardly with
   "learner", leave it swapped as-is and add it to a "Flag for Jordan" list
   in your report — do not reword.
3. **Verify:** `bin/rails test` — green. Then
   `grep -n -i student config/locales/en.yml` should show keys and
   `%{student_limit}` only, no prose.

### Task 2 [Clone]: Swap copy on Terms + Privacy, bump "Last updated"

**Skills:** write-tests
**Reference:** `config/initializers/agreements.rb` (AIDEV-NOTE explains
`prompt_when_updated`)

**In scope:**

- `app/views/users/agreements/_terms_of_service.html.erb` and
  `_privacy_policy.html.erb`: swap every student → learner in prose,
  headings ("4. Learner information", "6. Learner limits"), and the
  AIDEV-NOTE ("learner logins ship").
- `config/initializers/agreements.rb`: set `updated:` for both agreements to
  today's date (`Time.zone.parse("YYYY-MM-DD 00:00:00")`). Leave
  `prompt_when_updated: false`.
- `test/integration/terms_page_test.rb` and
  `test/integration/billing_policy_copy_test.rb`: update expected text.

**NOT in scope:**

- Any rewording beyond the noun swap. Setting `prompt_when_updated: true`.
- `public/refunds.html.erb` (Task 3).

**Build order:**

1. **Test:** In `terms_page_test.rb`, update the "student" assertion to
   "learner" and assert the page shows the new "Last updated" date. Update
   `billing_policy_copy_test.rb` the same way. Run them — red.
2. **Implement:** Edit the two agreement partials and `agreements.rb`.
3. **Verify:** `bin/rails test test/integration/terms_page_test.rb
   test/integration/billing_policy_copy_test.rb` — green. `grep -i student`
   on the two partials returns nothing.

### Task 3 [Clone]: Swap hardcoded copy: public pages, sidebar, dev pages, previews

**Skills:** write-tests
**Reference:** `test/integration/public_test.rb`

**In scope** (text only; file contents, not filenames):

- `app/views/public/about.html.erb` (lines 8, 15, 17),
  `app/views/public/refunds.html.erb` (line 23 + AIDEV-NOTE).
- `app/views/application/_sidebar.html.erb`: label `"Students"` →
  `"Learners"` (leave `students_path` / `students_nav_active?` — Task 5).
- `app/views/dev/kitchen_sink/show.html.erb` (lines 145, 150),
  `app/views/dev/typography/show.html.erb` (line 119).
- `test/components/previews/page_header_component_preview.rb`,
  `plan_card_component_preview.rb`,
  `ui_modal_component_preview/custom_trigger.html.erb`: demo strings.
- Tests asserting these strings: `test/integration/public_test.rb`,
  `test/system/app_shell_system_test.rb`, and component tests
  (`page_header_component_test.rb`, `ui_modal_component_test.rb`,
  `ui_tabs_component_test.rb`, `button_component_test.rb`,
  `plan_card_component_test.rb`) — only where they assert on literal copy.

**NOT in scope:**

- Route helpers, ERB identifiers, `en.yml`, legal pages.

**Build order:**

1. **Test:** Update expected strings in the tests above. Run them — red.
2. **Implement:** Edit the views and previews.
3. **Verify:** `bin/rails test test/integration/public_test.rb test/components`
   then `bin/rails test:system test/system/app_shell_system_test.rb` — green.
4. **Checkpoint 1 review:** when this task is done, run
   **review-changes-mini** for Checkpoint 1 (Tasks 1–3). If Tasks 1–3 ran as
   a parallel batch, the master runs it once the whole batch returns instead.
   Run it exactly once per checkpoint.

### Task 4 [Master]: Migration: rename table, column, indexes

**Skills:** safe-migration, write-tests
**Reference:** `test/migrations/add_complimentary_premium_to_accounts_test.rb`
for migration-test style; `db/schema.rb` lines 53, 335–345, 405.

**In scope:**

- New migration `db/migrate/<timestamp>_rename_students_to_learners.rb`
  (`bin/rails g migration RenameStudentsToLearners`), using `def change`:
  - `rename_table :students, :learners`
  - `rename_index :learners, "index_students_on_account_id_and_lower_name",
    "index_learners_on_account_id_and_lower_name"` — only if it still has the
    old name after `rename_table` (check `schema.rb`). Add an
    `# AIDEV-NOTE:` explaining why the expression index is renamed explicitly.
  - `rename_column :accounts, :student_limit, :learner_limit`
- New test `test/migrations/rename_students_to_learners_test.rb`.
- Delete `test/migrations/add_student_limit_to_accounts_test.rb`. It asserts
  the **live** `student_limit` column, so it can't survive the rename. Move
  its assertions (integer, not null, default 10) into the new test against
  `learner_limit`.

**NOT in scope:**

- Model/code changes (Task 5). The suite will be red after this task —
  that's expected until Task 6.
- Editing any existing migration file.

**Build order:**

1. **Test:** `rename_students_to_learners_test.rb` asserts, via
   `ActiveRecord::Base.connection`: table `learners` exists and `students`
   does not; `accounts.learner_limit` is integer, not null, default 10;
   indexes `index_learners_on_account_id` and
   `index_learners_on_account_id_and_lower_name` (unique) exist; a foreign key
   from `learners` to `accounts` exists.
2. **Implement:** Before migrating, record row counts:
   `bin/rails runner 'p Student.count, Account.sum(:student_limit)'`. Then
   `bin/rails db:migrate`. Check `schema.rb` for the index names.
   Run `bin/rails db:rollback` then `bin/rails db:migrate` again to prove
   it's reversible. Row count check happens in Task 6 (needs the model).
3. **Schema noise:** `git diff db/cable_schema.rb db/cache_schema.rb
   db/queue_schema.rb` — `git checkout --` them if they only show
   reordering/version bump. In `db/schema.rb`, keep only the rename-related
   lines and the new schema version number; revert unrelated reordering and
   the `[8.1]` annotation by hand.
4. **Verify:** `bin/rails test test/migrations/rename_students_to_learners_test.rb`
   — green (the rest of the suite is red until Task 6).

### Task 5 [Master]: Rename app code: model, controllers, routes, views, CSS, locale keys

**Skills:** write-tests, style-ui
**Reference:** Rename map above.

This task touches many files, but every change is the same mechanical
rename. It is one atomic unit — the app cannot boot between pieces.

**In scope** (apply the rename map to contents, `git mv` files/dirs):

- Models: `app/models/student.rb` → `learner.rb`, `app/models/account.rb`.
- Controllers: `students_controller.rb` → `learners_controller.rb`,
  `app/controllers/students/` → `app/controllers/learners/`
  (`archives_controller.rb`, `kept_controller.rb`).
- Routes: `config/routes.rb` (lines 22–29, including the AIDEV-NOTE; the
  `kept` scope stays above `resources :learners`).
- Views: `app/views/students/` → `app/views/learners/`,
  `_student_card.html.erb` → `_learner_card.html.erb`, plus contents of
  every partial; `app/views/application/_sidebar.html.erb`;
  `app/views/billing/_plan_state.html.erb`; `app/views/pricing/*.html.erb`.
- Helpers/services: `application_helper.rb` (`learners_nav_active?`),
  `plan_pricing_helper.rb` (`premium_learner_limit`),
  `app/services/family_invitation_acceptance.rb`.
- CSS: `app/assets/tailwind/application.css` lines 162–181 (tokens,
  `.learner-color`, `data-learner-color`, AIDEV-NOTE).
- Locale **keys** and interpolation names in `config/locales/en.yml`.
- `lib/jumpstart/app/madmin/resources/account_resource.rb`,
  `config/initializers/filter_parameter_logging.rb` (comment only),
  `db/seeds.rb`.
- New test: every `Learner::COLORS` key has a `--learner-<key>` token and a
  `.learner-color[data-learner-color="<key>"]` rule in `application.css`.

**NOT in scope:**

- Tests and fixtures other than the new token test (Task 6).
- Docs (Tasks 7–8). Existing migrations.

**Build order:**

1. **Test:** Add the token test to `test/models/learner_test.rb` (create the
   file now; Task 6 moves the old model tests into it). Read
   `Rails.root.join("app/assets/tailwind/application.css")` and assert each
   key's token and rule are present. Red.
2. **Implement:** `git mv` files/dirs, then apply the rename map to contents
   of all in-scope files. Then `grep -rn -i student app config lib db/seeds.rb`
   — must return nothing.
3. **Verify:** `bin/rails test test/models/learner_test.rb` — green.
   `bin/rails runner 'p Learner.count, Account.sum(:learner_limit)'` matches
   the counts recorded in Task 4. `bin/rubocop` clean.

### Task 6 [Master]: Rename tests and fixtures; full suite green

**Skills:** write-tests
**Reference:** Rename map above.

**In scope** (`git mv` + rename map on contents):

- `test/fixtures/students.yml` → `learners.yml`; `accounts.yml`
  (`learner_limit`).
- `test/models/student_test.rb` → merge into `test/models/learner_test.rb`
  (created in Task 5); `test/models/account_test.rb`.
- `test/integration/`: `students_test.rb`, `students_index_test.rb`,
  `students_kept_test.rb`, `student_forms_test.rb`,
  `student_archives_test.rb`, `student_privacy_test.rb` → `learner*`
  equivalents; contents of `madmin/accounts_test.rb`,
  `coming_soon_pages_test.rb`, `public_test.rb`.
- `test/system/students_system_test.rb` → `learners_system_test.rb`.
- `test/helpers/application_helper_test.rb` (paths like `"/students"` →
  `"/learners"`), `plan_pricing_helper_test.rb`,
  `test/services/family_invitation_acceptance_test.rb`,
  `test/controllers/users/signup_completions_controller_test.rb`,
  remaining component tests.
- Rename class names to match files (`StudentsTest` → `LearnersTest`, etc.)
  and test descriptions ("parent can add a student" → "…a learner").

**NOT in scope:**

- Changing what any test checks. Only names and expected values change.

**Build order:**

1. **Test/Implement:** `git mv` and apply the rename map.
   `grep -rn -i student test` — must return nothing.
2. **Verify:** `bin/rails test` — full suite green. Then
   `bin/rails test:system test/system/learners_system_test.rb` (run
   sequentially, not alongside another test process). Show both outputs.
3. **Checkpoint 2 review:** when this task is done, run
   **review-changes-mini** for Checkpoint 2 (Tasks 4–6). Run it exactly once
   for this checkpoint.

### Task 7 [Clone]: Update living docs: product docs + AGENTS.md

**Reference:** Rename map above.

**In scope:**

- `docs/product/product-brief.md` (section "## Learners (Built —
  `/learners`)", "## Learner data", `learner_limit`, "learner logins"),
  `docs/product/ux-notes.md`, `docs/product/strategy-brief.md`.
- `AGENTS.md`: glossary line becomes "**Learner** = a record owned by the
  family, not a login." Update the other "student" mentions.

**NOT in scope:**

- `docs/plans/done/`, `docs/designs/done/`, this ticket's design/plan docs.
  Any rewording beyond the swap.

**Build order:**

1. **Implement:** Apply the rename map to the four files.
2. **Verify:** `grep -n -i student docs/product AGENTS.md` returns nothing.

### Task 8 [Clone]: Update architecture diagrams + component catalog

**Reference:** Rename map above.

**In scope:**

- `docs/architecture/data-model.mermaid`, `app-structure.mermaid`,
  `routes-map.mermaid`, `docs/COMPONENT_CATALOG.md`.

**NOT in scope:**

- Regenerating diagrams or the catalog (`/close-out` does that). Text swap only.

**Build order:**

1. **Implement:** Apply the rename map.
2. **Verify:** `grep -n -i student docs/architecture docs/COMPONENT_CATALOG.md`
   returns nothing. Mermaid syntax still valid: entity names have no spaces.

### Task 9 [Master]: Final sweep: grep, full + system tests, rollback, browser check

**Skills:** write-tests

**In scope:**

- Repo-wide check:
  `git grep -n -i student -- . ':!db/migrate' ':!docs/plans/done' ':!docs/designs/done' ':!docs/designs/rename-students-to-learners.md' ':!docs/plans/rename-students-to-learners.md'`
  — must return nothing except the new rename migration.
- `bin/rails test`, then all system tests sequentially with `bin/rails test:system`.
- Reversibility: `bin/rails db:rollback && bin/rails db:migrate`; then clean
  schema-dump noise again (see Task 4 step 3).
- Browser check (dev server via `preview_start`): `/learners` index shows
  colored dots, add/edit modal shows color swatches, `/students` returns 404,
  sidebar says "Learners", `/pricing` says "learners". Screenshot as proof.
- `bin/rubocop`.

**NOT in scope:**

- Fixing anything found here beyond the rename. Report anything else.

**Build order:**

1. Run every check above and show its output.
2. **Checkpoint 3 review:** when this task is done, run
   **review-changes-mini** for Checkpoint 3 (Tasks 7–9). If Tasks 7–8 ran as
   a parallel batch, the master runs it once Task 9 is done. Run it exactly
   once for this checkpoint.

## Task Dependencies

- Tasks 2 and 3 can run in parallel with each other. Task 1 should go first
  or alongside them (separate files — no conflicts).
- Task 4 depends on Checkpoint 1 (copy done, so Phase 2 can be fully mechanical).
- Tasks 4 → 5 → 6 are strictly sequential; the suite is red between them
  and green after Task 6.
- Tasks 7 and 8 can run in parallel with each other, after Task 6.
- Task 9 depends on everything.
