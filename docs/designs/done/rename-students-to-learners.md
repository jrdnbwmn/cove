> Plan created: docs/plans/rename-students-to-learners.md
> Ticket: COV-109
> Branch: chore/cov-109-rename-students-to-learners

# Feature: Rename "students" to "learners"

## Problem
Cove's terminology is changing from "student" to "learner". The new word must be the only one the product uses: in the UI, URLs, code, database, legal pages, and living docs. Otherwise the vocabulary splits between what users see and what developers read.

## Approach
A full, straight-swap rename in one PR, built in staged checkpoints so tests pass at each one:

1. **Database + model:** one reversible migration renames `students` → `learners` and `accounts.student_limit` → `accounts.learner_limit`, including indexes. `Student` → `Learner`, `Account#students` → `#learners`, and all related constants/methods/locale keys.
2. **Controllers, routes, views, CSS:** `/students` → `/learners` (no redirects), `Students::*` → `Learners::*`, views/partials/directories, `--student-<key>` → `--learner-<key>` tokens, Stimulus/JS if any, Madmin resource.
3. **Copy:** UI strings, pricing/billing, public pages, Terms of Service and Privacy Policy (new wording, "Last updated" bumped, `prompt_when_updated` stays `false`).
4. **Docs:** living docs only (see Scope).

Capitalization and sentence structure stay as they are; only the noun is swapped (Student → Learner, students → learners, "student logins" → "learner logins", "student data" → "learner data").

## Acceptance Criteria
- No user-visible page, email, error message, or toast says "student".
- `/learners` routes work and `/students` routes no longer exist.
- Existing rows survive the migration (count before = count after), and the migration is reversible.
- The unique index on `(account_id, lower(name))` exists under the new name.
- Every `Learner::COLORS` key has a matching `--learner-<key>` CSS token.
- `bin/rails test` and relevant system tests pass.
- `grep -ri student` over the repo returns only the allowed leftovers (see Scope).

## Prototype
None

## Data Model
No new models, associations, or fields.

| Thing | Before | After |
|---|---|---|
| Table | `students` | `learners` |
| Account column | `accounts.student_limit` | `accounts.learner_limit` |
| Unique index | `index_students_on_account_id_and_lower_name` | `index_learners_on_account_id_and_lower_name` |
| Account index | `index_students_on_account_id` | `index_learners_on_account_id` |
| Foreign key | `students` → `accounts` | `learners` → `accounts` |
| Model | `Student` | `Learner` |
| Association | `Account has_many :students` | `has_many :learners` |

One `change` migration using `rename_table`, `rename_column`, and an explicit `rename_index` for the expression index (Rails does not reliably rename it with the table). Row-preserving.

Code names that follow: `FREE_STUDENT_LIMIT` → `FREE_LEARNER_LIMIT`, `default_student_limit`, `can_add_student?`, `students_allowed`, `over_free_student_limit?`, `student_pick_needed?`, `keep_students_on_free`, `students_empty?`, `:has_students` → `:has_learners`, `within_student_limit`, error keys `:student_limit_free` / `:student_limit_premium`, `premium_student_limit` helper, locale keys in `config/locales/en.yml`, Madmin `account_resource.rb`, fixtures (`students.yml` → `learners.yml`, `student_limit` in `accounts.yml`), `db/seeds.rb`.

`kept_on_free`, `grade_level`, and the color keys are unchanged.

## Screens / Flows
Layout, components, and hierarchy do not change. Only copy, URLs, and token names change.

| Screen | New URL | Primary tasks |
|---|---|---|
| Learners index | `/learners` | 1. See every learner in the family. 2. Add a learner. 3. Archive or delete one. |
| Learner card (partial) | n/a | 1. Identify the learner (name, color, grade). 2. Reach edit/archive/delete. |
| New / edit learner | `/learners/new`, `/learners/:id/edit` | 1. Enter name and grade. 2. Pick a color. |
| Learner record | `/learners/:id` | 1. See the learner's details. 2. Edit them. |
| Delete confirmation | `/learners/:id/delete` | 1. Confirm permanent deletion. 2. Back out safely. |
| Limit modal | (modal) | 1. Understand why they can't add another. 2. Upgrade or archive. |
| Keep-on-free picker | `/learners/kept/edit` | 1. Choose which 2 learners stay editable. |
| Sidebar | n/a | Navigate to the section. |

Archive/restore live at `/learners/:id/archive`. The `/learners/kept/edit` scope must stay above `resources :learners` in `config/routes.rb` (existing AIDEV-NOTE, update its wording).

Copy-only changes outside the section: pricing (free card, premium card, plans, `show`), billing plan state, About, Refunds, Terms of Service, Privacy Policy, dev pages (kitchen sink, typography), Madmin accounts admin, `family_invitation_acceptance.has_learners` message.

Existing sentences keep their structure; if any reads awkwardly with "learner", flag it in the plan for a product decision rather than rewording it. Copy follows `docs/product/ux-notes.md`.

## Scope
**In:**
- Migration, model, and every code name listed above.
- Routes and controllers (`LearnersController`, `Learners::ArchivesController`, `Learners::KeptController`), view directory `app/views/learners/`, partials (`_learner_card`, etc.).
- `--learner-<key>` CSS tokens and the `application.css` AIDEV-NOTE.
- All UI, locale, pricing, billing, public, Terms, and Privacy copy. Terms and Privacy "Last updated" bumped to the merge date in `config/initializers/agreements.rb`; `prompt_when_updated: false` (no re-accept).
- Tests: rename files (`students_*_test.rb`, `student_*_test.rb`, `student_test.rb`, `students_system_test.rb`, fixtures) and update all references. Keep `add_student_limit_to_accounts_test.rb` working against the original migration.
- Living docs: `docs/product/` (product-brief, ux-notes, strategy-brief), the `AGENTS.md` glossary and notes, `docs/architecture/*.mermaid`, `docs/COMPONENT_CATALOG.md`.
- New test: every `Learner::COLORS` key has a `--learner-<key>` token.
- After migrating locally, `git checkout --` the unrelated schema dumps (`cable`, `cache`, `queue`) per the AGENTS.md gotcha.

**Deferred / not doing:**
- Redirects from `/students/*` (only staging exists).
- Renaming or rewording anything beyond the noun swap.
- Editing archived docs in `docs/plans/done/` and `docs/designs/done/`.
- Editing old migration files (history).

**Allowed leftover "student" after the rename** (anything else is a bug): old migrations in `db/migrate/`, the new rename migration, archived done docs, and this ticket's design/plan docs.

## Open Questions
- Does `config/initializers/filter_parameter_logging.rb` filter by attribute name only? Expected yes (`name`, `grade_level`); confirm in the plan. Only its comment should change.
- Does Render's `startCommand` run migrations before boot? Confirm in the plan (affects the deploy-ordering edge case).
- Does the test environment raise on missing translations? If not, check renamed locale keys manually.

## More Info
- Edge-case handling: run the migration on seeded data and compare row counts; check the renamed index; all `Learner::COLORS` keys need tokens; no schema-dump noise in the diff.
- Delivery: one PR, staged commits in the checkpoint order above, tests green at each.
- Glossary in `AGENTS.md` currently says "Student = a record owned by the family, not a login." This becomes **Learner**.
