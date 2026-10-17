> Ticket: COV-122
> Branch: feature/cov-122-classes-list-as-rows
> Plan created: docs/plans/classes-list-as-rows.md

# Feature: Classes list as rows

## Problem

The curriculum-mixer parent wants every class in one place, with "where is each kid in each book" visible at a glance. Cards don't scale to that. Rows give each class one scannable line and leave room for later progress text ("Lesson 42 of 120 · Finishes about May").

## Approach

Keep `CoursesController#index` and its URL-only filter state. Swap the card grid for a single `.row-list` box of rows (same pattern as billing charges). Add a `q` search param and Pagy pagination (12 per page, like billing). No new models, migrations, Stimulus controllers, or components:

- `Course.search(term)` scope: case-insensitive `ILIKE` on `name` OR `subject`, with `%`/`_` escaped via `sanitize_sql_like`.
- The search box is a `FormFieldComponent` (hidden label, search icon on the left) inside the existing filter GET form. It submits on Enter, with no JS.
- New `courses/_course_row.html.erb` replaces `_course_card.html.erb` (delete the card partial). The "…" menu, its hidden status forms, and the lazy Delete modal move over unchanged.
- The inline add row is a new `row` option on `application/_modal_trigger_button` (next to `tile`), passed through `courses/_add_trigger` and `application/_lazy_modal`.
- `CourseListReturn::LIST_PARAMS` gains `q` and `page`, so modal actions return to the same tab, filters, search, and page.

## Acceptance Criteria

- On phone and desktop, `/classes` lists classes as rows with name, subject, learners, and (on Completed/Archived) the status date: everything the cards showed.
- Tabs, counts, filters, and the "…" menu (Edit, Complete/Archive or Reopen/Restore, Delete) work as before.
- With more than 12 classes in the current view, search and pagination appear. Searching "math" finds a class named "Math 5" and one whose subject is "Math".
- Search, tab, and filters combine. Tab counts follow the search as well as the learner and subject filters.
- Clicking a row opens the class's Edit modal.
- On the Active tab with at least one class, the list ends (on the last page) with a muted "+ Add class" row that behaves exactly like the header's Add class.
- Changing the tab, a filter, or the search resets to page 1. Returning from a modal action keeps tab, filters, search, and page, and clamps to the last page if that page no longer exists.

## Prototype

None.

## Data Model

No changes. Search reads the existing `courses.name` and `courses.subject` columns. No index needed (a family has at most a few hundred classes).

## Screens / Flows

### `/classes`

**Primary tasks:** 1. Find a class and see who takes it and its subject at a glance. 2. Open a class to edit it. 3. Change its status from the "…" menu. 4. Add a class. 5. Narrow the list by tab, learner, subject, or search.

**Unchanged:** the page header (title, description, Add class), the status tabs with counts, the learner and subject filters, the no-classes-at-all empty state, the Active-empty state, and the Completed/Archived empty text.

**Toolbar** (top of the list, existing GET form): `[Search classes]` `[All learners ▾]` `[All subjects ▾]`. Search sits first (left). On phone, all three stack full width, as the filters do today.
- Search box: `FormFieldComponent`, `label_hidden: true`, label "Search classes", placeholder "Search classes", search icon in `with_addon_left`, param `q`. Enter submits the whole form (hidden `status` plus filters plus `q`). No page param, so it resets to page 1.
- The search box renders when the current view (tab plus learner plus subject, before search) has **more than 12 classes**, **or** a search is active (so it can always be seen and cleared).
- Clearing the box and pressing Enter removes the search.

**Tabs:** links carry `learner`, `subject`, and `q` (never `page`). Counts follow learner, subject, and search.

**List:** one bordered `.row-list` box with dividers, in the existing order (`Course.ordered`: subject, then name). Twelve per page.

**Row, desktop (≥ sm):** no column headers; fixed-width columns line up across rows:

```
Math 5                         Math            ● Mia  ● Leo      3 Jun 2026    ⋮
Name (flexible, wraps)         Subject ~12rem  Learners ~16rem   Date (C/A)    menu
```

- Name: medium weight, wraps. Subject: muted. A missing subject leaves its column blank so the columns stay aligned.
- Learners: color dots via `learners/name_with_dot`, wrapping inside the column. With no visible learners, muted "No learners" (existing copy). Archived learners are hidden (existing `@learners_by_id` lookup).
- Status date column only on the Completed/Archived tabs (`course_status_date`, e.g. "Completed 3 Jun 2026"). Nothing on Active.
- Row padding 12–16px. Hover tints the row background.

**Row, phone:** stacks name, then subject, then learners, then date. The "…" button is pinned top-right.

**Row click:** same technique as the cards. A full-row stretched button (`card_link_classes`) opens the lazy-loaded Edit modal (`edit_course_path`). The "…" menu sits above it (z-10) and keeps its portaled-menu-plus-hidden-forms pattern.

**"+ Add class" row:** muted, borderless, plus icon, same words as the header button ("Add class"), rendered below the list box. Shown only on the Active tab, when there are results, on the **last page**. Opens the same Add modal.

**Pagination:** `PaginationComponent` below the list, only when there's more than one page. Pagination links keep all list params.

**No results:**
- Search or filter matches nothing, search active: "No classes match your search or filters." plus a "Clear all" button.
- Filter matches nothing, no search: existing "No classes match these filters." plus "Clear filters".
- Both buttons keep the tab and clear learner, subject, and search.

**Returning from modals:** after Save, Delete, Complete/Archive, or Reopen/Restore, the redirect uses `course_list_return_path`, which now keeps `q` and `page` too. If the page is past the end, show the last page that has results. If nothing is left, show the right empty or no-match state.

### Copy (new keys, `courses.index`)

- `search_label` / placeholder: "Search classes"
- `no_match_search`: "No classes match your search or filters."
- `clear_all`: "Clear all"

### Docs

`docs/product/product-brief.md` → Classes, after the `/classes` tabs line, add: "Classes are listed as rows. Past 12 classes, the list adds search, which matches class name and subject and combines with the tab and filters." Also update the counts sentence: "Counts follow the learner and subject filters **and the search**."

## Edge Cases

- Blank or whitespace-only `q` means no search. It's dropped from the URL, so the box can disappear again at 12 or fewer classes.
- `%` and `_` match literally. Leading and trailing whitespace is trimmed. `q` is truncated to 100 characters.
- Array/hash params (`?q[]=x`) are ignored (existing `string_param`). A junk `page` (`abc`, `0`, negative) means page 1. A page past the end means the last page.
- A search that matches nothing on this tab but matches on others shows the no-match state, and the tab counts show where the matches are.
- With a search active and 12 or fewer results, the search box stays and pagination hides.
- Search doesn't match learner names (the learner filter covers that).
- Scoped to `Current.account`. The echoed search value is escaped by Rails. The return path only honors `q`/`page` as strings on `/classes`.

## Scope

**In:** row layout (desktop columns, phone stacking), search (name plus subject, Enter to submit), Pagy pagination at 12 per page, the inline "+ Add class" row, the return path keeping search and page, new no-match copy, the product-brief update, and tests.

**Deferred (ticket Out of scope):**
- Progress text on rows: position ("Lesson 42 of 120") and finish estimate ("Finishes about May").
- Rows opening a class page (arrives with Lessons on classes). Rows open the Edit modal for now.

## Open Questions

- Implementation detail for write-plan: confirm how Pagy 43 handles an out-of-range page (an overflow option, or clamp by hand in the controller).

## More Info

- Budget: a weekly glance. Nothing new to enter.
- Ticket size S. If it grows, split search and pagination into their own issue.
- UX notes rules applied: "Past 12 items: rows, plus search and pagination together"; "No tables. Rows may align columns on desktop; they stack on phones"; the inline add is "a borderless muted last row ('+ Add …') in row lists", shown only where a new item would appear.
