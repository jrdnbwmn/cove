> Ticket: COV-110
> Branch: feature/cov-110-classes-model-and-management

# Plan: Classes — model and management

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1 | 1 — Data foundation | 1 | Create `courses` and `enrollments` tables | Master | |
| 2 | 1 — Data foundation | 1 | `Course` model, fixtures, Account association | Master | |
| 3 | 1 — Data foundation | 1 | `Enrollment` model, fixtures, Learner association | Master | |
| 4 | 1 — Data foundation | 2 | Save a class's learners safely (`Course#assign_learners`) | Master | |
| 5 | 2 — Learner picker | 3 | Run /create-component for `LearnerPickerComponent` | Master | |
| 6 | 3 — Add and edit | 4 | Class routes, controller (index/new/create/edit/update), copy | Master | |
| 7 | 3 — Add and edit | 4 | Add/edit modal form views | Clone | |
| 8 | 3 — Add and edit | 4 | Classes list, cards, empty state | Clone | |
| 9 | 4 — Delete and navigation | 5 | Delete class with in-modal confirmation | Master | |
| 10 | 4 — Delete and navigation | 5 | Sidebar shows Classes | Master | |
| 11 | 4 — Delete and navigation | 5 | Remove the Subjects page | Master | |
| 12 | 5 — Copy, flow, docs | 6 | Marketing copy says "classes" | Clone | |
| 13 | 5 — Copy, flow, docs | 6 | System test for the full modal flow | Master | |
| 14 | 5 — Copy, flow, docs | 6 | AGENTS.md glossary + product-brief updates | Clone | |
| 15 | 5 — Copy, flow, docs | 7 | Demo classes in local seeds | Clone | |

## Prerequisites

- Design: `docs/designs/classes-model-and-management.md`
- Prototype: None
- Feature branch exists: `feature/cov-110-classes-model-and-management`
- Run Rails commands with `export PATH="$HOME/.local/share/mise/shims:$PATH"`; confirm `ruby -v` reports 4.0.5.
- Fixtures-only Minitest convention (AGENTS.md "Test data").
- Naming everywhere: UI says **Class**, code says `Course`. The UI never says "enrollment".

## Tasks

### Task 1 [Master]: Create `courses` and `enrollments` tables

**Skills:** safe-migration, write-tests
**Reference:** Read the learners table migration in `db/migrate/` and `db/schema.rb`.

**In scope:**

- `courses`: `account_id` (FK, not null, indexed), `name` string not null, `subject` string nullable, timestamps.
- `enrollments`: `course_id` (FK, not null), `learner_id` (FK, not null, indexed), timestamps. Unique index on `[course_id, learner_id]` (also serves `course_id` lookups). **No `account_id` column** (decided in the design).
- DB-level assertions in `test/models/course_test.rb` and `test/models/enrollment_test.rb`: not-null columns, foreign keys, unique pair raises `ActiveRecord::RecordNotUnique`.

**NOT in scope:** Model validations, associations on Account/Learner, fixtures (beyond what the DB tests need inline).

**Build order:**

1. **Test:** DB assertions in the two model test files.
2. **Implement:** Two migrations; migrate to update `db/schema.rb`.
3. **Verify:** `bin/rails test test/models/course_test.rb test/models/enrollment_test.rb`; migrate → `bin/rails db:rollback:primary STEP=2` → migrate. Then `git checkout -- db/cable_schema.rb db/cache_schema.rb db/queue_schema.rb` and `git diff db/schema.rb`.

### Task 2 [Master]: `Course` model, fixtures, Account association

**Skills:** write-tests
**Reference:** Read `app/models/learner.rb` (normalizes, `MAX_LENGTH`, AIDEV-NOTE style) and the `activerecord.errors.models.learner` block in `config/locales/en.yml` (~line 827).

**In scope:**

- Tests first in `test/models/course_test.rb`: valid with only a name; name/subject stripped, whitespace-only subject → `nil`; name > 75 and subject > 50 rejected with the design's messages; two classes can share a name; "math" saves as "Math" (suggestion match); a family's existing custom subject is matched case-insensitively ("co-op" → "Co-op"); `subject_options_for(account)` = suggestions + this family's distinct custom subjects, deduped, never another family's; `ordered` scope = subject present first, `lower(subject)`, `lower(name)`, no-subject last.
- In `test/models/account_test.rb`: deleting a family deletes its classes.
- `app/models/course.rb`: AIDEV-NOTE (UI says Class; `class` is reserved in Ruby), `NAME_MAX_LENGTH = 75`, `SUBJECT_MAX_LENGTH = 50`, `SUBJECT_SUGGESTIONS`, `belongs_to :account`, normalizes, validations, `before_validation` subject-spelling match, `self.subject_options_for(account)`, `scope :ordered`.
- `has_many :courses, dependent: :destroy` in `app/models/account.rb`.
- `test/fixtures/courses.yml`: `one` (subject "Math"), `two`, `no_subject`, `shared` (all `company`), `downgraded_course` (`downgraded`).
- Error copy under `activerecord.errors.models.course` in `en.yml`: "Enter a name for this class.", "Use 75 characters or fewer.", "Use 50 characters or fewer."

**NOT in scope:** Enrollments, learner associations, controllers.

**Build order:**

1. **Test:** Extend `test/models/course_test.rb` and `test/models/account_test.rb`.
2. **Implement:** `app/models/course.rb`, `app/models/account.rb`, `test/fixtures/courses.yml`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/models/course_test.rb test/models/account_test.rb`.

### Task 3 [Master]: `Enrollment` model, fixtures, Learner association

**Skills:** write-tests
**Reference:** Read `app/models/learner.rb` (`editable?`, `archived?`) and `test/fixtures/learners.yml`.

**In scope:**

- Tests first in `test/models/enrollment_test.rb`: learner from another family is invalid; duplicate learner gets the friendly validation error "%{name} is already in this class."; on create, an archived learner is invalid; on create, a read-only learner (`learners(:read_only)`) is invalid with "%{name} is read-only on Free, so they can't be added to a class."; an *existing* read-only enrollment stays valid and can be destroyed.
- In `test/models/learner_test.rb`: deleting a learner removes their enrollments; `learner.courses` works.
- `app/models/enrollment.rb`; `app/models/learner.rb` gets `has_many :enrollments, dependent: :destroy` + `has_many :courses, through: :enrollments`; `course.rb` gets `has_many :enrollments, dependent: :destroy` + `has_many :learners, through: :enrollments`.
- `test/fixtures/enrollments.yml` by label: `shared` ↔ `one` and `two`; `one` ↔ `one`; `two` ↔ `archived` (company); `downgraded_course` ↔ `read_only` and `kept`.
- Enrollment error copy in `en.yml`.

**NOT in scope:** Form-saving logic, visible-learner filtering.

**Build order:**

1. **Test:** `test/models/enrollment_test.rb`, `test/models/learner_test.rb`.
2. **Implement:** `app/models/enrollment.rb`, `app/models/learner.rb`, `app/models/course.rb`, `test/fixtures/enrollments.yml` (+ locale keys).
3. **Verify:** `bin/rails test test/models/enrollment_test.rb test/models/learner_test.rb test/models/course_test.rb`.

When Tasks 1–3 are complete, run `/review-changes-mini` once for checkpoint 1. If any ran as a parallel batch, Master runs it after the batch returns.

### Task 4 [Master]: Save a class's learners safely

**Skills:** write-tests
**Reference:** The design's "Saving learners from the form" section; `Account#over_free_learner_limit?` in `app/models/account.rb` (memoized per Account instance).

**In scope:**

- Tests first in `test/models/course_test.rb`: a class can have several learners or none; checked learners are added; unchecking every learner leaves no active learners; other-family and archived IDs are ignored; an archived learner's enrollment survives a save and reappears after `restore!`; `visible_learners` hides archived learners without deleting rows; a read-only learner submitted → `save` returns false, nothing persists (class nor any enrollment), error on `course.errors[:learners]`; a read-only learner already enrolled can be unchecked (removed).
- `Course#assign_learners(ids)`: looks up IDs only among `account.learners.active`; builds enrollments for newly checked learners; marks enrollments of unchecked *active* learners for destruction; never touches archived learners' rows; all persisted in the same transaction as `save` (autosave on `has_many :enrollments` or an explicit transaction — whichever keeps the error on `:learners`). AIDEV-NOTE on why `learner_ids=` isn't used.
- `Course#visible_learners`: the class's learners filtered to active, `Learner.ordered`.

**NOT in scope:** Controllers/views; the list's query optimisation (Task 8).

**Build order:**

1. **Test:** Extend `test/models/course_test.rb`.
2. **Implement:** `app/models/course.rb` (and `enrollment.rb` only if needed).
3. **Verify:** `bin/rails test test/models/`.

When Task 4 is complete, run `/review-changes-mini` once for checkpoint 2.

### Task 5 [Master]: Run /create-component for `LearnerPickerComponent`

**Skills:** create-component, write-tests, style-ui
**Reference:** `CheckboxComponent` and `BadgeComponent` in `docs/COMPONENT_CATALOG.md`; `app/views/learners/_color_dot.html.erb`; `test/components/checkbox_component_test.rb`; `test/components/previews/checkbox_component_preview.rb`.

**In scope:**

- Check RailsBlocks first (per /create-component); otherwise compose from `CheckboxComponent`.
- Args: `name:`, `learners:`, `selected_ids:`, `read_only_ids: []`, `label:`, `help: nil`, `error: nil`. `read_only_ids` is passed in by the caller so the component never calls `editable?` per learner (decided).
- `<fieldset>` + `<legend>`; one row per learner passed in: checkbox, color dot, name. Read-only + unselected → disabled, greyed, "Read-only on Free". Read-only + selected → checked, enabled, neutral "Read-only" badge. Empty → "No learners yet." with a link to `/learners`. Hidden empty value before the checkboxes so unchecking everyone submits `[""]`. Error/help tied to the fieldset via `aria-describedby`.
- Component tests: `test/components/learner_picker_component_test.rb`.
- Lookbook preview `test/components/previews/learner_picker_component_preview.rb`: several learners, some selected, read-only selected + unselected, empty, error.

**NOT in scope:** Filtering archived learners (caller passes active only), modal behaviour, catalog/kitchen-sink updates (`/close-out` does those).

**Build order:**

1. **Test:** `test/components/learner_picker_component_test.rb`.
2. **Implement:** `app/components/learner_picker_component.rb` + `.html.erb`, preview.
3. **Verify:** `bin/rails test test/components/learner_picker_component_test.rb`; load the preview in `/lookbook`.

When Task 5 is complete, run `/review-changes-mini` once for checkpoint 3.

### Task 6 [Master]: Class routes, controller, and copy

**Skills:** write-tests
**Reference:** `app/controllers/learners_controller.rb`, `config/routes.rb`, `test/integration/learners_test.rb`.

**In scope:**

- Tests first in `test/integration/courses_test.rb`: signed-out → sign-in redirect; a parent can add a class with only a name; with a suggested or a custom subject; the other company parent can add and edit; another family's class → 404 on edit/update; read-only learner submitted → 422, nothing saved; unchecking everyone clears learners; `RecordNotUnique` race → 422 not 500; success redirects to `/classes` with "Class added." / "Saved.".
- `resources :courses, path: "classes", except: :show do get :delete, on: :member end` (delete/destroy bodies in Task 9).
- `CoursesController`: new/create/edit/update; `set_course` via `Current.account.courses.find`; `params.expect(course: [:name, :subject, learner_ids: []])` with `learner_ids` routed through `assign_learners`, not `learner_ids=`; framed 422 responses. Leave `index` minimal (Task 8 fills it).
- All `courses.*` UI copy from the design's Copy table into `en.yml`.

**NOT in scope:** View markup beyond a minimal frame (Tasks 7–8), delete/destroy bodies, removing Subjects.

**Build order:**

1. **Test:** `test/integration/courses_test.rb`.
2. **Implement:** `config/routes.rb`, `app/controllers/courses_controller.rb`, `config/locales/en.yml`.
3. **Verify:** `bin/rails test test/integration/courses_test.rb` (view-dependent assertions go green with Tasks 7–8).

### Task 7 [Clone]: Add/edit modal form views

**Skills:** style-ui, write-tests
**Reference:** `app/views/learners/new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_actions.html.erb`; `SelectComponent` and `FormFieldComponent` in the catalog.
**Primary tasks:** 1. Name the class. 2. Choose who takes it. 3. Optionally set a subject. 4. (Edit) Delete it.

**In scope:**

- `app/views/courses/new.html.erb`, `edit.html.erb`, `_form.html.erb`, `_actions.html.erb` inside `turbo_frame_tag "modal-lazy-content"`. Titles "Add class" / "Edit class".
- Name: `FormFieldComponent`, required, `maxlength` 75, hint "Something you want to track or grade, like Algebra 1 or Piano."
- Subject: `SelectComponent` single, `allow_create: true`, placeholder "Choose or type a subject", options `Course.subject_options_for(Current.account)` — on 422 the submitted value must be in the options so it isn't lost.
- Learners: `LearnerPickerComponent` with active learners, selected = visible learner IDs, `read_only_ids` computed once, help "Choose who takes this class. You can leave it empty.", error `course.errors[:learners].first`.
- Buttons: Cancel, then **Add class** / **Save** (primary rightmost; phones full-width stacked, primary on top). No Delete button yet (Task 9).
- Integration assertions in `test/integration/course_forms_test.rb`: labels, maxlength, preserved values/errors on 422, archived learners absent from the picker.

**NOT in scope:** Delete control, list page, new JavaScript.

**Build order:**

1. **Test:** `test/integration/course_forms_test.rb`.
2. **Implement:** The four view files.
3. **Verify:** `bin/rails test test/integration/course_forms_test.rb test/integration/courses_test.rb`.

### Task 8 [Clone]: Classes list, cards, empty state

**Skills:** style-ui, write-tests
**Reference:** `app/views/learners/index.html.erb`, `_learner_card.html.erb`, `_add_trigger.html.erb`, `_color_dot.html.erb`; `PageHeaderComponent`, `CardComponent`, `EmptyStateComponent`, `BadgeComponent`, `UiModalComponent` in the catalog.
**Primary tasks:** 1. Add a class. 2. Find a class and open it to edit. 3. See at a glance who takes what.

**In scope:**

- Tests first in `test/integration/courses_index_test.rb`: cards in `ordered` sequence (no-subject last); subject line only when set; learners shown, archived hidden, read-only learner gets "Read-only" badge, none → "No learners"; empty state title/description/Add class action, no header Add class when empty; the Free-limit check runs once per request (`assert_queries_match(/COUNT/i, count: 1)` or equivalent on the downgraded family).
- `index` in `CoursesController`: `@courses = Current.account.courses.ordered.includes(:enrollments)`; `@learners_by_id = Current.account.learners.active.ordered.index_by(&:id)` (loaded through `Current.account` so the memoized `over_free_learner_limit?` is shared); `@read_only_ids`. Cards map enrollments through that hash. AIDEV-NOTE on why.
- `app/views/courses/index.html.erb` (header "Classes", description "Classes are what you want to track or grade."), `_course_card.html.erb` (stretched-link name opens edit modal; no "…" menu), `_add_trigger.html.erb`. Grid 1/2/3 columns like Learners. Empty-state icon `book-open`; title "No classes yet"; description "Add a class for anything you want to track or grade, like Algebra 1, Piano, or Nature study."

**NOT in scope:** Filters, complete/archive, "…" menu, sidebar.

**Build order:**

1. **Test:** `test/integration/courses_index_test.rb`.
2. **Implement:** `app/controllers/courses_controller.rb` (index only) + the three views.
3. **Verify:** `bin/rails test test/integration/courses_index_test.rb test/integration/courses_test.rb`.

When Tasks 6–8 are complete, run `/review-changes-mini` once for checkpoint 4. If Tasks 7–8 ran as a parallel batch, Master runs it after both return.

### Task 9 [Master]: Delete class with in-modal confirmation

**Skills:** write-tests, style-ui
**Reference:** `app/views/learners/delete.html.erb`, `_delete_content.html.erb`, `_actions.html.erb`; `LearnersController#delete/#destroy`.

**In scope:**

- Tests first (extend `test/integration/courses_test.rb`): framed confirmation shows "Delete Algebra 1?" / "This can't be undone."; both parents can delete; another family's class → 404; delete removes the class and its enrollments; toast "Class deleted.".
- `delete` + `destroy` actions; `app/views/courses/delete.html.erb` (Cancel → `edit_course_path`, destructive **Delete class**).
- **Delete class** ghost/destructive button in `courses/_actions.html.erb` (edit only), swapping the frame to the confirmation.

**NOT in scope:** Block counts, deleting from the list card.

**Build order:**

1. **Test:** Extend `test/integration/courses_test.rb`.
2. **Implement:** `courses_controller.rb`, `courses/delete.html.erb`, `courses/_actions.html.erb`.
3. **Verify:** `bin/rails test test/integration/courses_test.rb`.

### Task 10 [Master]: Sidebar shows Classes

**Skills:** write-tests
**Reference:** `app/helpers/application_helper.rb` (`subjects_nav_active?`), `app/views/application/_sidebar.html.erb`.

**In scope:**

- `test/helpers/application_helper_test.rb`: replace subjects assertions with `classes_nav_active?` (`/classes` and `/classes/1/edit` active; others not).
- `test/system/app_shell_system_test.rb`: assert the Classes link to `courses_path`.
- Replace `subjects_nav_active?` with `classes_nav_active?`; sidebar item "Classes" → `courses_path`, icon `book-open`.

**NOT in scope:** Deleting the Subjects route/controller/views (Task 11).

**Build order:**

1. **Test:** The two test files.
2. **Implement:** `application_helper.rb`, `_sidebar.html.erb`.
3. **Verify:** `bin/rails test test/helpers/application_helper_test.rb`, then `bin/rails test test/system/app_shell_system_test.rb` (sequentially).

### Task 11 [Master]: Remove the Subjects page

**Skills:** write-tests
**Reference:** `test/integration/coming_soon_pages_test.rb`.

**In scope:**

- Replace the two subjects tests with one: `get "/subjects"` → 404 (routing error) for a signed-in parent.
- Remove `resources :subjects` from `config/routes.rb`; delete `app/controllers/subjects_controller.rb` and `app/views/subjects/`; remove the `subjects:` locale block (~line 706). `grep -rn subjects_path app test` returns nothing.

**NOT in scope:** The Terms' "subject to reasonable use"; email `subject:` keys.

**Build order:**

1. **Test:** Update `test/integration/coming_soon_pages_test.rb`.
2. **Implement:** Route removal, file deletions, locale block.
3. **Verify:** `bin/rails test test/integration/coming_soon_pages_test.rb test/helpers/application_helper_test.rb`.

When Tasks 9–11 are complete, run `/review-changes-mini` once for checkpoint 5.

### Task 12 [Clone]: Marketing copy says "classes"

**Skills:** write-tests
**Reference:** `test/integration/about_page_test.rb`, `test/integration/public_test.rb`.

**In scope:**

- Tests: About page and public/pricing page show "Lay out classes and schedules for every learner in one place." and not the "subjects" version.
- Change the sentence in `app/views/public/about.html.erb` and `config/locales/en.yml` (`value_points.plan.body`).

**NOT in scope:** The Terms' "subject to reasonable use"; other marketing copy.

**Build order:**

1. **Test:** Extend `about_page_test.rb` and `public_test.rb`.
2. **Implement:** The two copy edits.
3. **Verify:** `bin/rails test test/integration/about_page_test.rb test/integration/public_test.rb`.

### Task 13 [Master]: System test for the full modal flow

**Skills:** write-tests
**Reference:** `test/system/learners_system_test.rb`.

**In scope:**

- `test/system/courses_system_test.rb`: add a class with a typed custom subject and two learners → modal closes, card appears, toast "Class added."; blank name → inline error, modal stays open, values kept; edit → "Saved."; Delete class → confirmation swaps in place → confirm → card gone, toast "Class deleted.". Synchronize on visible post-submit state; use CSS `aria-label` selectors where needed (Capybara gotcha).

**NOT in scope:** New app code unless the test exposes a real bug — if so, stop and report it.

**Build order:**

1. **Test:** Write the system test.
2. **Implement:** None expected.
3. **Verify:** `bin/rails test test/system/courses_system_test.rb`, with no other Rails test process running.

### Task 14 [Clone]: AGENTS.md glossary + product-brief updates

**Skills:** none
**Reference:** The design's "Docs" section; `AGENTS.md` glossary; `docs/product/product-brief.md` (downgrade rule ~line 57).

**In scope:**

- AGENTS.md glossary: Class = `Course`; Subject = a field on a class; Enrollment = internal only; schedule blocks are *done*, classes are *completed*.
- product-brief.md: new **Classes (Built — `/classes`)** section (purpose, no Free limit, grades/evaluations, learner rules exactly as listed in the design); downgrade rule "new subjects" → "classes".

**NOT in scope:** "Schedule (Decided, not built)" section; architecture diagrams; component catalog.

**Build order:**

1. **Test:** None (docs only).
2. **Implement:** Edit the two docs.
3. **Verify:** `git diff AGENTS.md docs/product/product-brief.md`.

When Tasks 12–14 are complete, run `/review-changes-mini` once for checkpoint 6. If they ran as a parallel batch, Master runs it after all return.

### Task 15 [Clone]: Demo classes in local seeds

**Skills:** write-tests
**Reference:** The local "Cove Family" block in `db/seeds.rb` (learners seeded with `find_or_create_by!`, ~line 59) and `test/config/seeds_test.rb`.

**In scope:**

- Tests first in `test/config/seeds_test.rb`: development seeds give the "Cove Family" three classes — "Algebra 1" (Math, both demo learners), "Piano" (Arts, Maya), "Nature study" (no subject, no learners); reseeding leaves exactly three classes and no duplicate enrollments. Add `-> { Course.count }` to the staging/production "does not create demo seed data" check.
- In `db/seeds.rb`, right after the demo learners: create the three classes idempotently with `find_or_create_by!(name:)`, and their enrollments with `find_or_create_by!`.

**NOT in scope:** Production/staging seeds; archived or read-only demo cases.

**Build order:**

1. **Test:** Extend `test/config/seeds_test.rb`.
2. **Implement:** `db/seeds.rb`.
3. **Verify:** `bin/rails test test/config/seeds_test.rb`.

When Task 15 is complete, run `/review-changes-mini` once for checkpoint 7. Then run sequentially: `bin/rails test`, `bin/rails test:system`, `bin/rubocop`, `git diff --check`; inspect `git diff origin/main...` before reporting completion.

## Task Dependencies

- Task 1 → Task 2 → Task 3 → Task 4 (sequential).
- Task 5 depends only on the Learner model; it can run in parallel with Tasks 1–4.
- Task 6 depends on Task 4. Tasks 7–8 depend on Tasks 5 and 6 and can run in parallel with each other.
- Task 9 depends on Task 7. Task 10 depends on Task 6 (`courses_path`). Task 11 depends on Task 10 (the sidebar must stop calling `subjects_path` first).
- Tasks 12 and 14 are independent. Task 13 depends on Tasks 7–9. Task 15 depends on Tasks 3–4 (models and associations).
- Each phase is deployable: (1) tables and models, no UI; (2) an unused component; (3) `/classes` works but isn't in nav yet; (4) delete, and nav swaps Subjects → Classes; (5) copy, docs, demo data, end-to-end check.
