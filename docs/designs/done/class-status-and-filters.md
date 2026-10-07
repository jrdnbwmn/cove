> Ticket: COV-111
> Branch: feature/cov-111-class-status-and-filters
> Plan created: docs/plans/class-status-and-filters.md

# Feature: Classes — status and filters

## Problem
Parents need to mark classes as finished or stopped without deleting them, and
to find classes in a growing list by learner, subject, and status. Today every
class lives in one flat list forever.

This is ticket 2 of 2 for Classes (ticket 1, COV-110, built the model and
management — see `docs/designs/done/classes-model-and-management.md`).

## Approach
- **Statuses** are stored as two timestamps on `courses`, `completed_at` and
  `archived_at` (matching how learners store archive), with a DB check
  constraint that a class can't be both. No `status` column.
- **Status actions** are two small nested singular resources, mirroring
  `Learners::ArchivesController`:
  - `resource :completion, only: %i[create destroy]` → `Courses::CompletionsController`
    (POST = complete, DELETE = reopen)
  - `resource :archive, only: %i[create destroy]` → `Courses::ArchivesController`
    (POST = archive, DELETE = restore)
  - Each is ~20 lines, scoped through `Current.account.courses`, and redirects
    back to where the parent was (`redirect_back_or_to courses_path`) so the
    current tab and filters stay put.
- **Filters** on `/classes` are a plain GET form: two `SelectComponent`s with
  `submit_on_change: true` (existing feature — no new JS) plus a hidden
  `status` field. Status itself is **underline tabs with counts**
  (`UiTabsComponent`, link mode), same as Learners' Active/Archived, per
  ux-notes ("A list's Active/Archived switch uses underline tabs with counts;
  other filters use a filter control").
- Filter state lives only in the URL (`/classes?learner=12&subject=math&status=completed`),
  so back/refresh keep it. No cookies or session.
- **"…" menu** on class cards, same `DropdownComponent` pattern as
  `learners/_learner_card` (hidden forms tied by the HTML `form` attribute,
  because the menu portals to `<body>`).
- No new components, no new Stimulus controllers, no new gems.

## Acceptance Criteria
Tests first. Test names describe user behavior:

- A parent can mark a class complete, and it's hidden from the default (Active) list.
- A parent can see completed classes on the Completed tab, and reopen one.
- A parent can archive a class, find it under Archived, and restore it.
- A class can't be both completed and archived (model validation and DB constraint).
- Only an active class can be completed or archived; a stale/duplicate request changes nothing and shows an alert.
- A class can be created and completed right away with no activity.
- A parent can still edit a completed class (and an archived one); saving doesn't change its status.
- Delete works in every status and always confirms.
- A parent can filter classes by learner (active learners, read-only included).
- A parent can filter classes by subject, ignoring case ("Math" and "math" are one option).
- Filters combine, and survive a page refresh (they're in the URL).
- Switching tabs keeps the learner and subject filters; tab counts follow them.
- A filter with no matches shows "No classes match these filters." and "Clear filters", which keeps the current tab.
- No classes at all shows the COV-110 empty state (no toolbar, no tabs).
- An unknown/foreign/archived learner id or unknown status in the URL is ignored, not an error.
- Another family's class can't be completed, archived, reopened, or restored (404).
- Completed/archived cards show "Completed 9 Sep 2025" / "Archived 12 Mar".
- Toasts use the agreed copy; the word "Done" never appears.

## Prototype
None.

## Data Model

### Migration: add to `courses`
| Column | Type | Rules |
|---|---|---|
| `completed_at` | datetime, nullable | Set by Complete, cleared by Reopen. Never a form field. |
| `archived_at` | datetime, nullable | Set by Archive, cleared by Restore. Never a form field. |

- Check constraint `courses_not_completed_and_archived`:
  `completed_at IS NULL OR archived_at IS NULL` (same style as
  `accounts_personal_must_be_false`).
- No new indexes — queries are already narrowed by the indexed `account_id`
  and a family has dozens of classes.
- Existing rows have both `nil` → Active. No data migration.
- The timestamps are kept so classes can be sorted by date later (not built now).

### `Course` model additions
- **Scopes:** `active` (both nil), `completed` (`completed_at` set), `archived` (`archived_at` set).
- **Predicates:** `active?`, `completed?`, `archived?`.
- **Transitions:** `complete!`, `archive!` (active only, set `Time.current`);
  `reopen!` (completed only), `restore!` (archived only) clear the timestamp.
  Wrong status → add a model error and return `false` (no exception, no change).
- **Validation** mirroring the constraint: "A class can't be both completed and archived."
- **Filter scopes:**
  - `taken_by(learner)` — joins enrollments, `where(enrollments: {learner_id: learner.id})`.
  - `with_subject(subject)` — `where("lower(subject) = ?", subject.downcase)`.
- **Subject filter options:** class method returning the family's distinct
  subjects across **all statuses**, one per case-insensitive group (the most
  common spelling; oldest on a tie), sorted A–Z. Separate from the existing
  `subject_options_for` (which mixes in suggestions for the form).
- **Learner filter options:** `Current.account.learners.active.ordered` (read-only included).

### Fixtures (`courses.yml`)
- Add `completed` (with subject + a learner) and `archived` (no subject), company family.
- Timestamps as `<%= 2.days.ago %>` — not `Time.current` (AGENTS.md fixture rule).
- Existing `one`, `two`, `no_subject`, `shared` stay active.

## Screens / Flows

### `/classes` page
**Primary tasks:** 1. Find a class and open it. 2. Mark a class complete. 3. Add a class. 4. Look back at past classes.

- **Header:** unchanged (title, description, **Add class** when ≥1 class exists, on every tab).
- **Toolbar** (shown when the family has ≥1 class), above the tabs:
  - GET form → `courses_path`. Two `SelectComponent`s, `submit_on_change: true`:
    - **Learner** — "All learners" (default) + active learners. Param `learner` (id).
    - **Subject** — "All subjects" (default) + subjects in use. Param `subject`.
    - Accessible labels "Filter by learner" / "Filter by subject".
  - Hidden `status` field so changing a filter keeps the tab.
  - Desktop: side by side, left-aligned, ~14rem each. Phones: stacked full width.
- **Status tabs:** `UiTabsComponent(mode: :links, variant: :underline)` with
  counts (same markup as `learners/index`): **Active · Completed · Archived**.
  Param `status` (`active` default, `completed`, `archived`). Each tab link
  keeps learner/subject; counts follow those filters (computed with COUNT
  queries, not by loading records). Phones: tabs scroll sideways.
- **Cards:** existing `courses/_course_card`, plus:
  - Completed/archived: muted line under the subject — "Completed %{date}" /
    "Archived %{date}" using the existing `friendly_date` helper.
  - "…" menu (top right, `DropdownComponent`, label "Actions for %{name}"):
    - Active: Edit, Complete, Archive, Delete
    - Completed: Edit, Reopen, Delete
    - Archived: Edit, Restore, Delete
    - Delete opens the existing confirmation (lazy modal), same as learner cards.
  - Cards look the same in every status otherwise (no muting, no badge).
- **States:**

| When | Shows |
|---|---|
| Family has no classes | Existing `EmptyStateComponent` ("No classes yet"); no toolbar, no tabs |
| Learner/subject filter set, no match | Muted "No classes match these filters." + outline **Clear filters** (link to current tab, no learner/subject) |
| Active tab, no filters, none active | "No active classes. Add one, or find past classes under Completed and Archived." + **Add class** |
| Completed tab, no filters, empty | "No completed classes yet." |
| Archived tab, no filters, empty | "No archived classes." |

Only the first-run state uses the large empty-state component.

- After Add class from any tab: stay on that tab with toast (new class is active).

### Edit modal
**Primary tasks:** 1. Correct name, subject, or learners. 2. Change status. 3. Delete.

- Form unchanged; editable in every status. Save keeps the status; toast "Saved."
- **Status row** between the learner picker and the footer, divider above:
  - Small medium-weight label "Status", then "Active" / "Completed 9 Sep 2025" / "Archived 12 Mar".
  - Outline buttons (right of the text on desktop; full width below on phones):
    - Active: **Complete class**, **Archive class**
    - Completed: **Reopen class**
    - Archived: **Restore class**
  - Each is its own small `form_with` outside the main form (forms can't nest —
    same as Learners' Archive button).
- Footer unchanged: Delete class (left), Cancel, Save.
- Clicking a status button with unsaved edits asks "Discard unsaved changes?"
  first (existing unsaved-changes behavior). **Implementation note:** confirm
  `ui_modal_unsaved_changes_controller.js` catches these submits, not only modal
  close; if not, extend it minimally.
- Status change: modal closes, toast, page returns to same tab + filters.
- No confirmation for status changes (all reversible). Delete still confirms.
- Add modal: no Status row.

### Copy
| Where | Text |
|---|---|
| Tabs | "Active" · "Completed" · "Archived" |
| Filter defaults | "All learners" · "All subjects" |
| Filter labels (sr) | "Filter by learner" · "Filter by subject" |
| No match | "No classes match these filters." · "Clear filters" |
| Nothing active | "No active classes. Add one, or find past classes under Completed and Archived." |
| Nothing completed | "No completed classes yet." |
| Nothing archived | "No archived classes." |
| Card / modal date | "Completed %{date}" · "Archived %{date}" |
| Modal status label | "Status" · "Active" |
| Modal buttons | "Complete class" · "Archive class" · "Reopen class" · "Restore class" |
| Menu items | "Edit" · "Complete" · "Archive" · "Reopen" · "Restore" · "Delete" |
| Menu button label | "Actions for %{name}" |
| Toast: complete | "%{name} is complete. Nice work." |
| Toast: reopen | "%{name} is active again." |
| Toast: archive | "%{name} archived." |
| Toast: restore | "%{name} restored." |
| Alert: already completed/archived | "%{name} is already completed." · "%{name} is already archived." |
| Alert: not active | "Only an active class can be completed or archived." |
| Validation | "A class can't be both completed and archived." |

Never use "Done" (reserved for schedule blocks).

## Edge Cases
- **Wrong status** (other parent changed it, stale tab, double click): model
  refuses, nothing changes, redirect back to same tab/filters with an alert toast.
- **Both statuses:** model validation; DB constraint is the backstop.
- **Another family's class:** 404 in all controllers (`Current.account.courses.find`).
- **Signed out:** sign-in redirect.
- **Editing completed/archived:** saves normally; status and date unchanged.
  Read-only learner rules from COV-110 apply in every status.
- **Filter params:**
  - Learner id foreign, archived, or non-numeric → ignored (show all learners).
  - Subject no longer in use → applied; shows the no-match state with Clear filters.
  - Unknown status → Active.
  - Mixed-case subjects in data → one option; filter matches case-insensitively.
- **Archived learner still enrolled:** not in the learner filter; enrollments stay hidden (COV-110 behavior).
- **Delete** in any status → confirmation → back to same tab/filters where possible, else `/classes`.
- **Performance:** tab counts via COUNT queries (or one grouped count); cards
  keep COV-110's single active-learner lookup (no per-card queries).
- **Accessibility:** labeled filters, existing accessible tab markup, status
  date is text (not color), labeled "…" buttons.

## Docs
- `docs/product/product-brief.md` Classes section: add status rules — Active /
  Completed / Archived; only an active class can be completed or archived;
  completed → reopen, archived → restore, both back to active; completing
  doesn't lock editing; any class can be completed right away; delete works in
  every status; `/classes` filters by learner, subject, status.
- AGENTS.md: no change (glossary already says classes are "completed").
- Architecture diagrams and component catalog are updated by `/close-out`.

## Scope
**In:** migration + constraint; `Course` scopes, transitions, validation, filter
scopes, subject filter options; `Courses::CompletionsController`,
`Courses::ArchivesController` + routes; `/classes` toolbar, status tabs, states;
card date line and "…" menu; edit-modal Status row; toasts/alerts; fixtures;
product-brief update.

**Deferred:**
- Schedule block behavior on complete/archive/delete (schedule ticket).
- Grades, credits, school year.
- Sorting by completion/archive date (timestamps kept for it).
- Bulk complete/archive.
- Setting a completion date by hand.

## Open Questions
None.
