> Plan created: docs/plans/classes-model-and-management.md
> Ticket: COV-110
> Branch: feature/cov-110-classes-model-and-management

# Feature: Classes — model and management

## Problem
`/subjects` is a placeholder. Parents need a place to set up the **classes** they
want to track or grade (Algebra 1, Piano, Nature study, a co-op class) and say
which learners take each one. Later features (grades, credits, schedule blocks)
need a class record to hang off.

This is ticket 1 of 2: (1) model and management, (2) status and filters (COV-111).
Completing, archiving, and filtering are **not** in this ticket.

A class is something the family wants to **track or grade**. Casual or one-off
things (outside time, a dentist visit, a museum trip) will be schedule blocks
when the schedule is built, not classes. The UI copy must make this distinction
obvious, without mentioning the schedule (it doesn't exist yet).

## Approach
Standard RESTful Rails resource, server-rendered, with add/edit forms
lazy-loaded into a modal — the same pattern as Learners.

- **Naming.** UI says **Class**. Code uses `Course`, because `class` is a
  reserved word in Ruby (AIDEV-NOTE on the model). The learner–class link is
  `Enrollment` in code; the UI never says "enrollment".
- **Routes.** `resources :courses, path: "classes"` → `/classes`. Actions:
  `index`, `new`, `create`, `edit`, `update`, `destroy`, plus a `delete`
  (confirmation) GET action if needed to swap the modal body, following
  `LearnersController`. No `show` page in v1.
- **Scoping.** Every lookup is `Current.account.courses.find(...)` → another
  family's class is a 404. No Pundit policy (matches Learners); both parents
  are admins and can do everything.
- **Remove Subjects.** Delete the `/subjects` route, `SubjectsController`,
  `app/views/subjects/`, `subjects_nav_active?` helper (+ its test), the
  `subjects:` locale keys, and the subjects tests in
  `test/integration/coming_soon_pages_test.rb`. Sidebar item becomes Classes.
- **Marketing copy.** "Lay out subjects and schedules for every learner in one
  place." → "Lay out classes and schedules for every learner in one place." in
  both `app/views/public/about.html.erb` and `config/locales/en.yml` (pricing
  features). Leave the Terms' legal phrase "subject to reasonable use" alone.
- **New catalog component:** `LearnerPickerComponent` (multi-select learner
  picker), reusable by schedule blocks later. Check RailsBlocks first via
  `/create-component`.
- **No Free limit** on classes.

## Acceptance Criteria
Tests first. Test names describe user behavior:

- A parent can add a class with only a name.
- A parent can add a class with a subject from the list, or with their own subject.
- A subject typed in different casing ("math") is saved in the existing spelling ("Math").
- A class name over 75 characters is rejected; a subject over 50 is rejected.
- Two classes can share a name.
- A class can have several learners, or none.
- The other parent can also add and edit classes.
- A parent can't see or edit another family's classes (404).
- Classes are listed by subject, then name, with no-subject classes last.
- An archived learner disappears from their classes and reappears when restored.
- Editing a class with an archived learner in it keeps that learner's enrollment.
- Deleting a learner removes them from their classes.
- A read-only learner can't be added to a class, even by a direct request (model validation; nothing saves; inline error).
- A read-only learner already in a class is shown as read-only and can be removed.
- Unchecking every learner and saving leaves the class with no learners.
- Deleting a class removes it and its enrollments.
- Deleting a family deletes its classes.
- The sidebar shows Classes, and `/subjects` no longer exists.
- About/pricing copy says "classes", not "subjects".
- `LearnerPickerComponent` has a Lookbook preview and component tests.

## Prototype
None.

## Data Model

### `Course` (new table `courses`)
| Column | Type | Rules |
|---|---|---|
| `account_id` | FK, not null, indexed | `belongs_to :account` |
| `name` | string, not null | required, max 75, whitespace stripped. Duplicates allowed. |
| `subject` | string, nullable | optional, max 50, stripped, blank → `nil` |
| timestamps | | |

- AIDEV-NOTE on the model: UI says "Class"; code says `Course` because `class` is reserved in Ruby.
- `SUBJECT_SUGGESTIONS = ["Math", "Language Arts", "Science", "Social Studies", "World Languages", "Arts", "Health", "Electives"]`.
- **Subject casing:** before validation, if the subject case-insensitively
  matches a suggestion or one of this family's existing subjects, adopt that
  existing spelling.
- **Subject options** for the form: suggestions + this family's distinct custom
  subjects, deduped.
- **Sort scope:** subject present first, then `lower(subject)`, then
  `lower(name)`; no-subject classes last.
- `has_many :enrollments, dependent: :destroy`; `has_many :learners, through: :enrollments`.
- **Visible learners:** a class's learners are shown filtered to active
  (non-archived) at read time — never by removing/re-adding rows. Restoring a
  learner brings them back automatically.
- No color, notes, dates, credits, or grades in v1.

### `Enrollment` (new table `enrollments`)
| Column | Type | Rules |
|---|---|---|
| `course_id` | FK, not null | `belongs_to :course` |
| `learner_id` | FK, not null, indexed | `belongs_to :learner` |
| timestamps | | |

- Unique index on `[course_id, learner_id]` + matching validation (friendly error).
- Validation: `learner.account_id == course.account_id`.
- **No `account_id` column** (decided): the family is derived through the
  course; a stored copy could disagree.
- **On create only:** learner must be active (not archived) and editable
  (`Learner#editable?`, i.e. not read-only). Existing enrollments of read-only
  learners stay valid and can be deleted (that's "remove").
- Empty for now; grades and credits will live here later.

### Existing models
- `Account has_many :courses, dependent: :destroy`.
- `Learner has_many :enrollments, dependent: :destroy`; `has_many :courses, through: :enrollments`.

### Saving learners from the form
Do **not** use `course.learner_ids = [...]` — it would delete enrollments for
archived learners, who aren't in the form. A small model method instead:
- adds enrollments for newly checked learners, looked up only among this
  family's **active** learners (other families' or archived IDs are ignored);
- removes enrollments for unchecked learners that the picker showed (active learners);
- never touches archived learners' enrollments.

Course save + enrollment changes run in one transaction. A read-only learner
submitted → enrollment validation fails → nothing saves → 422 with the inline
error in the modal.

### Fixtures
- `courses.yml`: `one` (with a subject, e.g. Math), `two`, `no_subject`,
  `shared` (two learners) — company family; plus a downgraded-family course for
  the read-only enrollment.
- `enrollments.yml`: by label, including `learners(:archived)` (company) and
  `learners(:read_only)` (downgraded family). Existing learner fixtures:
  `one`, `two`, `archived` (company); `kept`, `kept_two`, `read_only`,
  `read_only_two`, `read_only_three` (downgraded).

## Screens / Flows

### Sidebar
"Classes" (icon `book-open`) → `/classes`, replacing Subjects. `/subjects` 404s.

### `/classes` page
**Primary tasks:** 1. Add a class. 2. Find a class and open it to edit. 3. See at a glance who takes what.

- **Header:** `PageHeaderComponent`, title "Classes", description "Classes are
  what you want to track or grade." Primary action **Add class** shown only
  once at least one class exists (the empty state carries it otherwise — same
  as Learners).
- **List:** one flat grid of `CardComponent`s in sort order (1 column phone,
  2 tablet, 3 desktop — like Learners). Each card:
  - **Name** (medium weight) as a stretched-link button — click anywhere on the
    card opens the edit modal (same pattern as `learners/_learner_card`).
  - **Subject** as a muted line under the name, if set.
  - **Learners** as wrapping color dot + name pairs (reuse
    `learners/_color_dot`). Read-only learners get a small neutral "Read-only"
    `BadgeComponent`. No visible learners → muted "No learners".
  - No "…" menu in v1 (ticket 2 adds it with Complete/Archive).
- **Empty state:** `EmptyStateComponent`, `book-open` icon.
  - Title: "No classes yet"
  - Description: "Add a class for anything you want to track or grade, like Algebra 1, Piano, or Nature study."
  - Action: **Add class**

### Add / edit modal
**Primary tasks:** 1. Name the class. 2. Choose who takes it. 3. Optionally set a subject. 4. (Edit) Delete it.

`UiModalComponent`, lazy-loaded like the learner modals; full-height sheet on
phones. Closing with unsaved changes asks before discarding (existing behavior).
No modal on top of a modal.

- Title: "Add class" / "Edit class".
- **Name** (required, max 75). Hint: "Something you want to track or grade, like Algebra 1 or Piano."
- **Subject:** `SelectComponent` (single, `allow_create`), placeholder "Choose
  or type a subject"; options = suggestions + family custom subjects.
- **Learners:** `LearnerPickerComponent`. Help: "Choose who takes this class. You can leave it empty."
- Buttons bottom right: Cancel, then **Add class** / **Save** (primary rightmost; phones full-width stacked, primary on top).
- After create: modal closes, stay on the list, toast "Class added." After edit: toast "Saved."
- Errors inline, entered values preserved, modal stays open.
- **Edit only — Delete class** (destructive style) at the bottom of the modal.
  Swaps the modal body in place for the confirmation:
  - Heading: "Delete %{name}?" (e.g. "Delete Algebra 1?")
  - Body: "This can't be undone." (The schedule ticket will later add block counts here.)
  - Buttons: Cancel, **Delete class**
  - On confirm: modal closes, card removed, toast "Class deleted."

### `LearnerPickerComponent` (new catalog component)
- Check RailsBlocks first via `/create-component`; otherwise compose a checkbox
  list from `CheckboxComponent`.
- `<fieldset>` with a legend (the field label); one row per **active** learner:
  checkbox, color dot, name. Parent selects any number.
- Read-only learner, not selected: disabled, greyed out, "Read-only on Free" beside the name.
- Read-only learner, already selected: checked, enabled, "Read-only" badge — can be unchecked.
- Archived learners never appear.
- Family has no learners: "No learners yet." with a link to Learners.
- Renders a hidden empty value so unchecking everyone clears the selection
  (same gotcha as `CheckboxComponent`).
- Args roughly: `name:`, `learners:`, `selected_ids:`, `label:`, `help:`, `error:`.
- Works inline (no modal of its own) so schedule blocks can reuse it.
- Lookbook preview states: several learners, some selected, read-only
  selected + unselected, empty, error.

### Copy
| State | Text |
|---|---|
| Page description | "Classes are what you want to track or grade." |
| Empty title | "No classes yet" |
| Empty description | "Add a class for anything you want to track or grade, like Algebra 1, Piano, or Nature study." |
| Name hint | "Something you want to track or grade, like Algebra 1 or Piano." |
| Subject placeholder | "Choose or type a subject" |
| Learners help | "Choose who takes this class. You can leave it empty." |
| Picker read-only reason | "Read-only on Free" |
| Card read-only badge | "Read-only" |
| Card no learners | "No learners" |
| Created toast | "Class added." |
| Updated toast | "Saved." |
| Deleted toast | "Class deleted." |
| Delete confirm | "Delete %{name}?" / "This can't be undone." / "Delete class" |
| Name blank | "Enter a name for this class." |
| Name too long | "Use 75 characters or fewer." |
| Subject too long | "Use 50 characters or fewer." |
| Read-only learner submitted | "%{name} is read-only on Free, so they can't be added to a class." |

## Edge Cases
- **Scoping:** other family's class → 404; submitted learner IDs looked up only
  among this family's active learners (others/archived ignored); signed-out →
  sign-in redirect.
- **Archived learner in a class:** hidden on card and picker; row kept; saving
  the form doesn't touch it; restore shows them again.
- **Learner deleted:** enrollments deleted.
- **Downgraded, nobody picked yet** (all learners read-only): classes still
  work; picker shows everyone greyed out; classes can be created/edited with no
  one added.
- **Re-subscribe:** everyone editable again; no migration needed.
- **Read-only learner unchecked and saved:** removed; re-checking is blocked.
- **Duplicate names** allowed. **Whitespace-only subject** → no subject.
- **Concurrent double-add** of the same learner: unique index; second save shows
  a validation error, not a crash (rescue `ActiveRecord::RecordNotUnique` if needed).
- **Class deleted while the other parent has it open:** their save 404s. No
  special handling (same as Learners).
- **No Free limit:** no banner, no limit modal.
- **Performance:** `Learner#editable?` calls `account.over_free_learner_limit?`
  per learner — the list must not run that query once per learner (compute once
  per request).

## Docs
- **AGENTS.md glossary:** add
  - **Class** = `Course` (UI says class; `class` is reserved in Ruby).
  - **Subject** = a field on a class.
  - **Enrollment** = internal only (learner–class link); never in UI copy.
  - Schedule blocks are **done**; classes are **completed**.
- **product-brief.md:**
  - Add a **Classes (Built — `/classes`)** section: purpose (what the family
    wants to track or grade; casual/one-off things are schedule blocks, not
    classes), no Free limit, grades always belong to a class, evaluations are a
    separate later record, and the learner rules (deleted → enrollments
    removed; archived → kept but hidden, back on restore; read-only → stay
    visible marked "Read-only", can't be added, can be removed; deleting a
    class deletes its enrollments).
  - In the downgrade rule, change "new subjects" to "classes".
- Architecture diagrams and the component catalog are updated by `/close-out`, not during implementation.

## Scope
**In:** `Course` + `Enrollment` models, migrations, fixtures; `/classes` list,
empty state, add/edit/delete modal; `LearnerPickerComponent` + Lookbook preview;
removing Subjects; sidebar; marketing copy; AGENTS.md + product-brief.md updates.

**Deferred:**
- Complete, archive, filters (COV-111).
- "…" menu on class cards (arrives with COV-111).
- Schedule blocks; block counts in the delete confirmation.
- Grades, credits, school year; onboarding.
- Showing a learner's classes on the learner record page.
- "Schedule (Decided, not built)" section in product-brief.md — the block rules
  from the earlier brainstorm couldn't be found; the schedule ticket writes it.

## Open Questions
- The schedule block rules referenced by the ticket ("block rules from the
  brainstorm") weren't found anywhere. To be settled and written into
  product-brief.md by the schedule ticket.
