> Ticket: COV-120
> Branch: feature/cov-120-remove-free-learner-limit

# Plan: Remove the Free learner limit

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 | 1 | Raise and backfill the default cap | Master | ✅ |
| 2 | 1 | 1 | Enforce the new superadmin minimum | Master | ✅ |
| 3 | 2 | 2 | Give every plan the same capacity | Master |✅ |
| 4 | 2 | 2 | Remove learner editability rules and replace locale copy | Master |✅ |
| 5 | 2 | 2 | Allow all active learners in classes | subagent |✅ |
| 6 | 2 | 3 | Remove read-only controller behavior and routes | Master |✅ |
| 7 | 2 | 3 | Delete the picker flow and read-only view | Master |✅ |
| 8 | 2 | 3 | Simplify learner list and limit modal | Master |✅ |
| 9 | 2 | 4 | Make every active learner card editable | Master |✅ |
| 10 | 2 | 4 | Simplify LearnerPickerComponent | subagent |✅ |
| 11 | 2 | 4 | Remove class screen read-only states | subagent |✅ |
| 12 | 2 | 5 | Update picker previews and examples | subagent |✅ |
| 13 | 2 | 5 | Resolve pricing capacity and preserve typography demo | subagent |✅ |
| 14 | 2 | 5 | Apply approved pricing cards and footnote | Master |✅ |
| 15 | 2 | 6 | Update billing copy and browser expectations | subagent |✅ |
| 16 | 2 | 6 | Update Terms of Service | subagent |✅ |
| 17 | 2 | 6 | Remove kept flag and obsolete fixtures | Master |✅ |
| 18 | 2 | 7 | Complete learner and class browser regressions | Master |✅ |
| 19 | 3 | 8 | Update product documentation | Master | |
| 20 | 3 | 8 | Run final verification and inspect the diff | Master | |

## Prerequisites

- Design: [docs/designs/remove-free-learner-limit.md](../designs/remove-free-learner-limit.md). The local copy matches the supplied design.
- Prototype: None. Preserve the existing layouts and interaction patterns.
- Feature branch exists: `feature/cov-120-remove-free-learner-limit`.
- Before Rails commands, prepend `/Users/jordan/.local/share/mise/shims` to `PATH` and confirm `ruby -v` reports `4.0.5`.
- Use existing fixtures and literal records for additional test states; no FactoryBot, Faker, or new gems.
- Catalog components already cover this work: `UiModalComponent`, `ButtonComponent`, `AddTileComponent`, `CardComponent`, `DropdownComponent`, `CheckboxComponent`, `LearnerPickerComponent`, and `PlanCardComponent`. No new component is required.
- Phase 1 can deploy independently. Phase 2 is one coupled release: model API removal, callers, routes, locales, and column removal must ship together. Its checkpoints are local reviews. Phase 3 documents and validates the completed behavior.
- Inspect each task's diff and run its focused checks before starting another task. Keep parallel batches within approximately seven changed files. Rails test processes run sequentially.
- Shared file ownership stays with Master: models, routes, migrations, schema, and `config/locales/en.yml`.
- Use the approved design's exact copy. Leave unrelated gating, billing behavior, agreement metadata, architecture diagrams, and component catalog updates outside this implementation.

## Approved sequencing adjustment

Checkpoint 1 also updates existing test setup/default-count expectations in `learner_test.rb`, `learners_index_test.rb`, `plan_pricing_helper_test.rb`, and `public_test.rb` for the new default/minimum. Behavior changes remain in their assigned tasks. Approved during execution.

Phase 2 gate adjustment approved during execution: checkpoints 2–5 use focused tests and local review; full-suite failures from remaining coupled callers are recorded. A green full suite is required when Phase 2 is complete.

Checkpoint 3 local review: stale-route tests pass; learner request/list test errors remain in the card/Delete Cancel callers owned by Task 9. Full suite: 1301 runs, 5 failures, 95 errors. Rerun these focused files after Task 9.

Checkpoint 5 also updates the existing exact Free description expectation in `test/integration/plans_test.rb`, discovered by the full suite. Remaining failures are billing callers (Task 15) and learner-form capacity setup (Task 18).

Task 18 learner-form cap setup/copy adjustment was brought into checkpoint 6 to make the full suite green after removal of all production callers. The remaining Task 18 browser acceptance work stays at checkpoint 7. All five downgraded-family learner fixtures remain necessary for the five-learner regression; only their obsolete flags were removed.

## Tasks

### Task 1 [Master]: Raise and backfill the default cap

**Skills:** safe-migration, write-tests
**Reference:** `db/migrate/20261006213137_rename_students_to_learners.rb`, `test/migrations/rename_students_to_learners_test.rb`

**In scope:**

- Four files: generated migration, `db/schema.rb`, new `test/migrations/raise_default_learner_limit_test.rb`, and `test/migrations/rename_students_to_learners_test.rb`.
- Change the default from 10 to 15; raise existing values below 15 while preserving 15 and higher.
- Follow the design's explicit migration behavior: rollback restores only the default to 10, retaining raised rows.

**NOT in scope:** Removing `kept_on_free`, changing entitlement behavior, or modifying historical migration files.

**Build order:**

1. **Test:** Add tests using migration-local database operations for values below 15, exactly 15, and 20; assert the new default and that rollback preserves raised values. Update the old rename test's current-schema expectation from 10 to 15.
2. **Implement:** Generate `RaiseDefaultLearnerLimit` with `bin/rails generate migration`; implement its default change and backfill without depending on the runtime `Account` model.
3. **Verify:** Run migrate → `bin/rails db:rollback:primary STEP=1` → migrate. Prepare the test database, then run:
   `bin/rails test test/migrations/raise_default_learner_limit_test.rb test/migrations/rename_students_to_learners_test.rb`.
   Inspect the primary schema diff and restore only generated noise in the cable/cache/queue dumps.

### Task 2 [Master]: Enforce the new superadmin minimum

**Skills:** write-tests
**Reference:** `app/models/account.rb`, `test/integration/madmin/accounts_test.rb`

**In scope:**

- Four files: `app/models/account.rb`, `test/models/account_test.rb`, `test/fixtures/accounts.yml`, and `test/integration/madmin/accounts_test.rb`.
- Validate integer `learner_limit >= Account.default_learner_limit`.
- Change the complimentary fixture's explicit cap from 10 to 15.
- Replace test overrides below 15 with valid capacities where those tests are exercising other behavior.

**NOT in scope:** Changing Madmin implementation, removing Free capacity rules yet, or changing subscription logic.

**Build order:**

1. **Test:** Assert that 14, fractions, blank values, and negative values fail; 15 and 20 succeed. Through Madmin, verify saving 20 works and saving 14 preserves the stored value.
2. **Implement:** Use a runtime validation threshold derived from `Account.default_learner_limit`; update fixture and affected test setup.
3. **Verify:** `bin/rails test test/models/account_test.rb test/integration/madmin/accounts_test.rb`.
4. Run **review-changes-mini for checkpoint 1, Tasks 1–2**, exactly once after both tasks finish.

### Task 3 [Master]: Give every plan the same capacity

**Skills:** write-tests
**Reference:** `Account#can_add_learner?` and existing capacity tests in `test/models/account_test.rb`

**In scope:**

- Two files: `app/models/account.rb` and `test/models/account_test.rb`.
- Remove `FREE_LEARNER_LIMIT`, `learners_allowed`, all Free-picker methods, `invalid_learner_pick`, and the Free-limit memo reset in `reload`.
- Use `learners.active.count < learner_limit`.
- Rewrite the AIDEV-NOTE around one family cap, support increases, flat pricing, and unchanged Stripe quantity.

**NOT in scope:** Changing `premium?`, `plan_status`, paid-entitlement memoization, or parent limits.

**Build order:**

1. **Test:** Cover Free, paid Premium, and complimentary capacity at 14/15 and 15/15; Free with cap 20; archived learners excluded; and fresh counts after the association has loaded. Remove obsolete picker and memoization tests.
2. **Implement:** Remove the old API and simplify capacity calculation.
3. **Verify:** `bin/rails test test/models/account_test.rb`. Remaining application callers are removed by the dependent Phase 2 tasks before the release gate.

### Task 4 [Master]: Remove learner editability rules and replace locale copy

**Skills:** write-tests
**Reference:** `Learner#within_learner_limit`, `LearnerLimitConcurrencyTest`, `config/locales/en.yml`

**In scope:**

- Three files: `app/models/learner.rb`, `test/models/learner_test.rb`, and `config/locales/en.yml`.
- Remove `editable?` and the kept-flag update in `archive!`; retain the family-row lock.
- Replace both limit errors with `:learner_limit`, passing `account.learner_limit`.
- Add all approved modal, restore, pricing, and billing copy; remove obsolete learner Free-limit/read-only keys, including the enrollment error and picker badge key.

**NOT in scope:** Changing name uniqueness, color assignment, or unrelated translations, including the typography `pricing_sample` string.

**Build order:**

1. **Test:** Cover Free adding its third learner and continuing to 15; refusal at 15 with the exact soft error; cap 20 on Free; restoration below/at the cap; editing and archiving while over the cap. Update the existing concurrency test to start at 14/15 and assert exactly one successful addition.
2. **Implement:** Simplify learner behavior and replace locale branches. Use the exact approved modal title/body, Close / Email us labels, restore line, pricing descriptions/features/footnote, and billing description. Remove kept-flag and editability tests.
3. **Verify:** `bin/rails test test/models/learner_test.rb`. Assert the concurrent loser receives the soft error and the final active count is 15.

### Task 5 [subagent]: Allow all active learners in classes

**Skills:** write-tests
**Reference:** `app/models/enrollment.rb`, `Course#assign_learners`

**In scope:**

- Three files: `app/models/enrollment.rb`, `test/models/enrollment_test.rb`, and `test/models/course_test.rb`.
- Rename validation to `learner_is_active`; retain archived, duplicate, and family checks.
- Replace read-only refusal tests with successful enrollment behavior for a Free family above the old limit.

**NOT in scope:** Changing `Course#assign_learners`, class status behavior, or archived-enrollment preservation.

**Build order:**

1. **Test:** Assert active learners can join classes after downgrade; archived and other-family learners still cannot; existing archived enrollments remain preserved.
2. **Implement:** Remove only the editability branch from enrollment validation.
3. **Verify:** `bin/rails test test/models/enrollment_test.rb test/models/course_test.rb`.
4. Master runs **review-changes-mini for checkpoint 2, Tasks 3–5**, exactly once after all three tasks finish. If delegated work ran in parallel, Master waits for the whole batch.

### Task 6 [Master]: Remove read-only controller behavior and routes

**Skills:** write-tests
**Reference:** `app/controllers/learners_controller.rb`, `config/routes.rb`, `test/integration/learners_test.rb`

**In scope:**

- Four files: learner controller, routes, `test/integration/learners_test.rb`, and deletion of `test/integration/learners_kept_test.rb`.
- Remove learner `show`, read-only redirects, and the kept resource.
- Keep edit/update/delete/destroy scoped to the current family.
- Keep the resource's PATCH and DELETE routes; exclude only GET show.

**NOT in scope:** Removing CRUD or archive routes, changing authentication, or adding replacement redirects.

**Build order:**

1. **Test:** Assert a Free family above the old limit can edit and save every active learner; another family's records remain inaccessible. Assert GET `/learners/:id`, GET `/learners/kept/edit`, and PATCH `/learners/kept` return 404, with no changes from stale submissions.
2. **Implement:** Remove controller branches and use `resources :learners, except: :show`; remove the kept route block and obsolete test file.
3. **Verify:** `bin/rails test test/integration/learners_test.rb`. Include stale URLs as literal requests so tests do not depend on removed helpers.

### Task 7 [Master]: Delete the picker flow and read-only view

**Skills:** write-tests
**Reference:** Stale-route coverage from Task 6; existing `pick-limit` usage search

**In scope:**

- Delete four files: `app/controllers/learners/kept_controller.rb`, `app/views/learners/kept/edit.html.erb`, `app/views/learners/show.html.erb`, and `app/javascript/controllers/pick_limit_controller.js`.
- The Stimulus controller's only caller is the removed kept form.

**NOT in scope:** Removing shared checkbox/modal controllers or unrelated picker functionality.

**Build order:**

1. **Test:** Use Task 6's 404 and mutation assertions as the regression tests.
2. **Implement:** Delete the four obsolete files.
3. **Verify:** `bin/rails test test/integration/learners_test.rb`; confirm no remaining `pick-limit` markup or removed route-helper references.

### Task 8 [Master]: Simplify learner list and limit modal

**Skills:** write-tests, style-ui
**Reference:** Existing learners index, limit modal, and catalog `UiModalComponent`, `ButtonComponent`, `AddTileComponent`
**Prototype:** None; preserve the current layout.
**Primary tasks:** 1. See every learner at a glance 2. Add a learner 3. Edit, archive, or restore a learner

**In scope:**

- Four files: `app/views/learners/index.html.erb`, `app/views/learners/_limit_modal.html.erb`, deletion of `_free_limit_banner.html.erb`, and `test/integration/learners_index_test.rb`.
- Remove the banner and plan branches; use the family cap for the modal.
- Preserve header and tile Add actions. At capacity, both open the same soft modal.
- Use the approved restore-blocked line and support link on every plan.

**NOT in scope:** Redesigning the list, changing tabs, or adding automatic modal opening.

**Build order:**

1. **Test:** Assert Add-form triggers below the cap on every plan; both limit-modal triggers at the cap; exact title/body and Close / Email us; no plan name, pricing link, or upgrade prompt in the modal. Cover a Free cap of 20 and restore availability below/at capacity.
2. **Implement:** Remove plan-specific rendering and reuse the existing support subject.
3. **Verify:** `bin/rails test test/integration/learners_index_test.rb`.
4. Run **review-changes-mini for checkpoint 3, Tasks 6–8**, exactly once after all three finish.

### Task 9 [Master]: Make every active learner card editable

**Skills:** write-tests, style-ui
**Reference:** Existing stretched-card/modal and same-dialog delete patterns
**Prototype:** None; preserve the current layout.
**Primary tasks:** 1. See every learner at a glance 2. Add a learner 3. Edit, archive, or restore a learner

**In scope:**

- Four files: `_learner_card.html.erb`, `_delete_content.html.erb`, `test/system/learners_system_test.rb`, and `test/integration/learner_archives_test.rb`.
- Every active card opens Edit and offers Edit / Archive / Delete.
- Remove read-only badges and branches.
- In `_delete_content`, the link-based Cancel always returns to Edit; retain direct Close behavior for list/archived confirmations.

**NOT in scope:** Changing dropdown positioning, replacing dialogs, or changing delete/archive semantics.

**Build order:**

1. **Test:** Replace the read-only browser flow with editing and Delete→Cancel behavior after downgrade. Verify all five learners remain usable, archive succeeds, and restore succeeds below capacity but fails at capacity with the soft error.
2. **Implement:** Simplify active-card branches and the Cancel link.
3. **Verify:** Run sequentially:
   `bin/rails test test/integration/learner_archives_test.rb`,
   then `bin/rails test test/system/learners_system_test.rb`.

### Task 10 [subagent]: Simplify LearnerPickerComponent

**Skills:** write-tests, style-ui
**Reference:** Catalog `LearnerPickerComponent` and `CheckboxComponent`
**Prototype:** None; preserve the fieldset and checkbox layout.
**Primary tasks:** No class-screen Primary tasks were specified in the design; retain learner selection in the existing class form.

**In scope:**

- Three files: `app/components/learner_picker_component.rb`, its template, and `test/components/learner_picker_component_test.rb`.
- Remove `read_only_ids:`, `read_only?`, `disabled?`, badge rendering, and the checkbox's derived disabled option.
- Preserve names with color dots, selected values, help/errors, empty state, and hidden clearing input.

**NOT in scope:** Changing the shared checkbox component or adding new picker behavior.

**Build order:**

1. **Test:** Assert all supplied learners are selectable, selected checkboxes remain checked, selections can be cleared, and no read-only badge appears. Use a normal validation error in the error-state test.
2. **Implement:** Remove the read-only API and template branch.
3. **Verify:** `bin/rails test test/components/learner_picker_component_test.rb`.

### Task 11 [subagent]: Remove class screen read-only states

**Skills:** write-tests, style-ui
**Reference:** Existing class form/card and catalog `LearnerPickerComponent`
**Prototype:** None; preserve the current layout.
**Primary tasks:** No class-screen Primary tasks were specified in the design; retain class creation, editing, and learner visibility.

**In scope:**

- Four files: `app/views/courses/_form.html.erb`, `_course_card.html.erb`, `test/integration/courses_index_test.rb`, and `test/integration/courses_test.rb`.
- Remove `read_only_ids` computation/argument and learner badges.
- Replace request-level read-only failures with successful class creation and editing on Free.

**NOT in scope:** Changing filters, class statuses, or archived-learner display rules.

**Build order:**

1. **Test:** Assert formerly restricted active learners can be selected and saved; class cards show their names without badges; filters include them. Preserve cross-family and archived-learner coverage.
2. **Implement:** Remove read-only branches from form and card.
3. **Verify:** `bin/rails test test/integration/courses_index_test.rb test/integration/courses_test.rb`.
4. Master runs **review-changes-mini for checkpoint 4, Tasks 9–11**, exactly once after all three finish, waiting for any parallel batch to return.

### Task 12 [subagent]: Update picker previews and examples

**Skills:** write-tests, style-ui
**Reference:** Picker preview, kitchen sink example, and class form tests
**Prototype:** None; preserve existing example layouts.
**Primary tasks:** No Primary tasks apply to development previews.

**In scope:**

- Four files: `test/components/previews/learner_picker_component_preview.rb`, `app/views/dev/kitchen_sink/show.html.erb`, `app/controllers/courses_controller.rb`, and `test/integration/course_forms_test.rb`.
- Remove the read-only preview and kitchen-sink argument; use a relevant ordinary error example.
- Remove the obsolete memoized-Free-check explanation from the courses controller.
- Verify class forms expose all active learners after downgrade.

**NOT in scope:** Changing the component catalog, other kitchen-sink examples, or class query behavior.

**Build order:**

1. **Test:** Add form assertions that a Free family above two learners sees enabled learner inputs; archived learners remain absent.
2. **Implement:** Update examples and the controller comment.
3. **Verify:** `bin/rails test test/integration/course_forms_test.rb`; inspect the picker's default/error/empty previews and kitchen sink during final browser verification.

### Task 13 [subagent]: Resolve pricing capacity and preserve typography demo

**Skills:** write-tests
**Reference:** `app/helpers/plan_pricing_helper.rb`, existing helper tests

**In scope:**

- Three files: pricing helper, `test/helpers/plan_pricing_helper_test.rb`, and `app/views/dev/typography/show.html.erb`.
- Rename the helper to `pricing_learner_limit`.
- Return the signed-in family's cap on every plan, otherwise the database default.
- Replace the typography demo's removed constant reference with its existing demo count, preserving its exact rendered text.

**NOT in scope:** Editing `dev.typography.show.pricing_sample`, pricing amounts, or cache implementation.

**Build order:**

1. **Test:** Cover signed-out default 15 and signed-in Free, paid, and complimentary families with raised caps.
2. **Implement:** Rename the helper and preserve the typography demo's current count of 2.
3. **Verify:** `bin/rails test test/helpers/plan_pricing_helper_test.rb`; smoke-check the typography page in final browser verification.

### Task 14 [Master]: Apply approved pricing cards and footnote

**Skills:** write-tests, style-ui
**Reference:** Pricing partials, catalog `PlanCardComponent`, and signed-out cache in `_plans.html.erb`
**Prototype:** None; preserve existing card and billing-frequency layouts.
**Primary tasks:** 1. Compare Free and Premium 2. Start Free or get Premium

**In scope:**

- Four files: pricing `_free_card.html.erb`, `_premium_card.html.erb`, `show.html.erb`, and new `test/integration/pricing_learner_copy_test.rb`.
- Apply the approved descriptions and complete feature lists.
- Render the learner asterisk in an `aria-hidden="true"` span through the existing feature array.
- Replace the old contact line with the plain-text footnote using `pricing_learner_limit`.

**NOT in scope:** Changing prices, checkout actions, billing intervals, shared card API, or the existing cache key.

**Build order:**

1. **Test:** Assert exact descriptions/features in monthly and yearly panels; visually present, accessibility-hidden asterisks; visible footnote and mailto link. Cover signed-out 15 and Free/Premium cap 20. Verify no old count-based learner copy. Check the shared cards on the public homepage too.
2. **Implement:** Use Rails tag/safe-join helpers for the asterisk; avoid blanket HTML trust. Retain the cache key's existing default-cap component.
3. **Verify:** `bin/rails test test/integration/pricing_learner_copy_test.rb test/integration/public_test.rb`.
4. Master runs **review-changes-mini for checkpoint 5, Tasks 12–14**, exactly once after all three finish, waiting for any parallel batch to return.

### Task 15 [subagent]: Update billing copy and browser expectations

**Skills:** write-tests, style-ui
**Reference:** `app/views/billing/_plan_state.html.erb`, existing billing copy/system tests
**Prototype:** None; preserve the billing layout.
**Primary tasks:** No billing Primary tasks were specified; retain the existing plan summary and billing actions.

**In scope:**

- Three files: billing `_plan_state.html.erb`, `test/integration/billing_policy_copy_test.rb`, and `test/system/pricing_and_billing_system_test.rb`.
- Stop passing a count to the Free description.
- Show “Everything you need to run school for the whole family. Free forever.”
- Update browser expectations for approved pricing and billing copy.

**NOT in scope:** Changing subscription, cancellation, renewal, payment, or complimentary behavior.

**Build order:**

1. **Test:** Assert the Free billing description is exact and contains no learner count; verify pricing actions and frequency switching still work with the new features.
2. **Implement:** Remove count interpolation and update obsolete assertions.
3. **Verify:** Run the integration test, then the system test sequentially.

### Task 16 [subagent]: Update Terms of Service

**Skills:** write-tests, style-ui
**Reference:** `app/views/users/agreements/_terms_of_service.html.erb`, `test/integration/terms_page_test.rb`
**Prototype:** None; preserve the existing legal-page layout.
**Primary tasks:** No Terms Primary tasks were specified; retain readable public legal content.

**In scope:**

- Two files: the Terms partial and `test/integration/terms_page_test.rb`.
- Replace §6 and the §7 downgrade paragraph with the exact approved text.
- Replace the existing blanket assertion against numeric learner counts with assertions matching the approved 15-active-learner paragraph.

**NOT in scope:** Changing other legal sections, Privacy Policy, agreement dates, or reacceptance behavior.

**Build order:**

1. **Test:** Assert the complete approved paragraphs, archived-learner exclusion, and absence of Free-limit/read-only wording.
2. **Implement:** Change only the two approved paragraphs.
3. **Verify:** `bin/rails test test/integration/terms_page_test.rb test/integration/public_test.rb`.

### Task 17 [Master]: Remove kept flag and obsolete fixtures

**Skills:** safe-migration, write-tests
**Reference:** `db/migrate/20261004044708_add_kept_on_free_to_students.rb`, current learner/enrollment fixtures

**In scope:**

- Four files: generated removal migration, `db/schema.rb`, `test/fixtures/learners.yml`, and new `test/migrations/remove_kept_on_free_from_learners_test.rb`.
- Remove all fixture `kept_on_free` attributes and records used solely by deleted picker/read-only tests.
- Retain ordinary family/enrollment fixtures still needed by surviving tests; verify every reference before deleting a fixture.
- Remove the column reversibly with its boolean type, default, and null constraint specified.

**NOT in scope:** Deleting learner data, rewriting historical migrations, or introducing deployment compatibility infrastructure.

**Build order:**

1. **Test:** Assert the column is absent. Verify rollback restores boolean/default-false/not-null characteristics, then reapply the migration.
2. **Implement:** Generate the migration, clean obsolete fixtures, and regenerate the primary schema. The brief deploy-window learner-save failure is the design's accepted risk.
3. **Verify:** Run migrate → `bin/rails db:rollback:primary STEP=1` → migrate, then prepare the test database and run the new migration test plus learner/enrollment/course model tests. Restore only generated auxiliary-schema noise.
4. Master runs **review-changes-mini for checkpoint 6, Tasks 15–17**, exactly once after all three finish. If Tasks 15–16 ran in parallel, wait for both, inspect their five-file batch, then perform Task 17.

### Task 18 [Master]: Complete learner and class browser regressions

**Skills:** write-tests, style-ui
**Reference:** Existing learner forms and learner/class system tests
**Prototype:** None; preserve existing layouts at phone and desktop widths.
**Primary tasks:** Learners — 1. See every learner at a glance 2. Add a learner 3. Edit, archive, or restore a learner. Class-screen Primary tasks were not specified.

**In scope:**

- Up to three files: `test/integration/learner_forms_test.rb`, `test/system/learners_system_test.rb`, and `test/system/courses_system_test.rb`.
- Remove remaining old-cap assumptions.
- Exercise actual downgrade behavior with five learners, rather than relying only on a preexisting Free fixture.
- Cover third-learner creation, both Add triggers at capacity, cap 20, restore states, and usable class checkboxes after downgrade.

**NOT in scope:** Refactoring the system-test framework or unrelated interaction tests.

**Build order:**

1. **Test:** Add any missing acceptance coverage before making necessary corrections; preserve existing modal, dirty-form, archive, and filtering assertions.
2. **Implement:** Limit changes to remaining obsolete expectations and test setup. Route any uncovered production defect back to its owning task.
3. **Verify:** Run learner form tests and the two system files sequentially. Capture learner limit/restore states, class form, and pricing at desktop/phone sizes under `.context/`; confirm exact copy, no badges, and working dialog actions.
4. Run **review-changes-mini for checkpoint 7, Task 18**, exactly once.

### Task 19 [Master]: Update product documentation

**Skills:** engineering:documentation
**Reference:** The design's “Docs to update” section

**In scope:**

- Two files: `docs/product/product-brief.md` and `docs/product/ux-notes.md`.
- Apply the supplied Free/Premium table text, shared soft-cap rules, active-only counting, downgrade behavior, and class wording.
- Update the UX limit interaction to soft Email us copy on every plan.

**NOT in scope:** Editing `AGENTS.md`, historical docs, diagrams, component catalog, or unrelated product decisions.

**Build order:**

1. **Test:** Compare each requested documentation change against the completed behavior and approved design.
2. **Implement:** Apply only the specified product and UX changes.
3. **Verify:** Inspect `git diff -- docs/product/product-brief.md docs/product/ux-notes.md` and run `git diff --check`.

### Task 20 [Master]: Run final verification and inspect the diff

**Skills:** review-changes-mini
**Reference:** Design acceptance criteria and `.github/workflows/ci.yml`

**In scope:** Verification, evidence, and final scope review; no planned file changes.

**NOT in scope:** Opening or merging a PR, running the next workflow command, or updating close-out artifacts.

**Build order:**

1. **Test:** Audit acceptance coverage, including migration backfill, default/minimum 15, cap 20, concurrent additions, restores, downgrade editability, stale-route 404s, and exact pricing/billing/Terms copy.
2. **Implement:** No additional implementation is planned. Resolve any failure through its owning task and rerun the affected checks.
3. **Verify:** Run sequentially:
   - `bin/rails test`
   - `PARALLEL_WORKERS=4 bin/rails test:system`
   - `bin/rubocop`
   - `bin/erb_lint --lint-all -f compact`
   - `git diff --check`

   Search current application/configuration/tests for removed APIs, dead translation references, removed route helpers, and `pick-limit`. Inspect `git diff origin/main...HEAD`, the working-tree diff, and `git status`; include new files in the review. Confirm only the two intended migrations and primary schema changes remain.
4. Run **review-changes-mini for checkpoint 8, Tasks 19–20**, exactly once after documentation and all checks are complete. Report actual results and any remaining blocker. Name `/review-changes` as the next command and stop.

## Task Dependencies

- Task 2 depends on Task 1.
- Task 3 depends on Phase 1; Task 4 depends on Task 3; Task 5 depends on Task 4's enrollment locale cleanup.
- Tasks 6–9 depend on the new model behavior. Task 7 follows Task 6's stale-route tests.
- Task 10 depends on Task 4; Task 11 depends on Tasks 5 and 10.
- Task 12 depends on Tasks 10–11.
- Tasks 12 and 13 can run in parallel: seven files total, separate ownership. Master runs their verification sequentially.
- Task 14 depends on Tasks 4 and 13.
- Tasks 15 and 16 can run in parallel after Task 14: five files total. Their Rails checks run sequentially.
- Task 17 follows all removed-column consumers and fixture-test updates.
- Task 18 follows all Phase 2 implementation.
- Tasks 19–20 follow Phase 2, sequentially.
- Phase 2 ships only when all its tasks pass together. Intermediate removal of model methods, translation keys, and callers must not be deployed.
- Component catalog and architecture updates remain for the separately invoked close-out workflow.
