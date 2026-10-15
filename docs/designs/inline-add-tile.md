> Ticket: COV-118
> Branch: chore/cov-118-add-new
> Plan created: docs/plans/inline-add-tile.md

# Feature: Inline add tile at the end of card lists

## Problem

Parents scanning a list of learners or classes have to look back up to the
page header to add another one. A Notion-style inline "+ Add …" at the end of
the list puts the next action where their eyes already are.

## Approach

Keep the header's primary "Add …" button exactly as it is, and also end the
list with an inline add tile in the same words. Build the tile as a small new
ViewComponent, `AddTileComponent` (card style only), so it lives in the design
system next to `EmptyStateComponent` and future card lists (school plans,
subjects) find it in the catalog. The tile drops into the existing modal
trigger slots the same way `ButtonComponent` does, so it opens exactly what the
header button opens, including the learner limit modal.

Applies to **Learners** and **Classes** only. Parents (family page) and API
tokens are out of scope. The row style is a documented rule in ux-notes for
future row lists, not built now.

## Acceptance Criteria

- Learners Active view with at least one learner ends with a dashed
  "+ Add learner" tile, the same height as the cards around it.
  - Under the limit it opens the "Add learner" modal.
  - At or over the limit it opens the same limit modal as the header button.
- Classes Active tab with at least one class shown (filtered or not) ends with
  a dashed "+ Add class" tile that opens the "Add class" modal. No filter
  values are prefilled.
- No tile on: Archived learners, Completed/Archived classes, a filter with no
  matches, or any empty list. There is never a lone add tile on a page.
- Classes Active tab with no active classes (family has other classes, no
  filter on) shows `EmptyStateComponent` instead of today's plain line.
- The header "Add …" button is unchanged (position, style, still hidden while
  the list is empty).
- The tile is a real `<button>`, keyboard-reachable, with a visible label that
  matches the header button and a visible focus ring.
- `docs/product/ux-notes.md` documents the rule (wording below).
- Tests cover the above; existing tests that click "Add learner"/"Add class"
  are scoped so they don't hit Capybara ambiguous matches.

## Prototype

None. Visual reference: the user's Notion screenshots — gallery view ends with
a bordered "+ New page" card, table view ends with a borderless muted
"+ New page" row. Cove adds a dashed border to the card and uses its own
"Add …" label.

## Data Model

No changes — no migrations, models, routes, or controllers. Reuses
`new_learner_path`, `new_course_path`, and `Account#can_add_learner?`. Both
`create` actions redirect back to the list (full re-render, no Turbo Stream
appends), so the tile stays last after a save with no special handling.

## Screens / Flows

### `AddTileComponent` (new, `app/components/`)

- Args: `text:` (required), `data: {}` (e.g.
  `{action: "click->ui-modal#open:prevent"}`, same as `ButtonComponent`),
  `classes: nil`.
- Renders a `<button type="button">` filling its grid cell: dashed
  `border-neutral-300` border, `CardComponent`'s corner radius, transparent
  background, centered `plus` icon + label in `text-muted-foreground`.
- Hover: border and text darken (matching cards' hover border darkening).
  Focus: visible `--primary` focus ring like the cards.
- Height comes from the grid: both grids already use `auto-rows-fr`, so the
  tile matches the tallest card in its row. The modal trigger wrapper it sits
  in must also fill the cell.
- Long labels wrap and stay centered.
- Lookbook preview: a default tile, and a tile in a 3-column grid next to two
  cards to show height matching. Component test included. Catalog entry is
  added by `/close-out`.

### Learners page

**Primary tasks:** 1. Open a learner to edit 2. Add a learner 3. Switch to
Archived

- Active grid: after the last learner card, render the tile through the same
  branch the header uses — `learners/_add_trigger` when
  `Current.account.can_add_learner?`, otherwise `learners/_limit_modal`. Each
  partial gains an option to render `AddTileComponent` as its trigger instead
  of the button.
- Archived view and empty state: unchanged, no tile.

### Classes page

**Primary tasks:** 1. Open a class to edit 2. Filter by learner or subject
3. Add a class 4. Switch status tab

- Active tab with results: tile after the last card, rendered through
  `courses/_add_trigger` → `application/_lazy_modal` (which gains a tile
  trigger option).
- Active tab empty, no filter on (family has other classes): replace the
  `none_active` line and button with `EmptyStateComponent`:
  - Icon: `book-open`
  - Title: "No active classes"
  - Description: "Find past classes under Completed and Archived, or add a new one."
  - Primary action: `courses/_add_trigger` ("Add class")
  - These two strings replace `courses.index.none_active`.
- Filter with no matches, Completed and Archived tabs, and the family-level
  empty state: unchanged, no tile.

### Copy

Tile labels reuse `learners.index.add` ("Add learner") and
`courses.index.add` ("Add class") so they can't drift from the header button.
The only new copy is the Classes empty-state title and description above.

### ux-notes.md update (same PR)

Add under **Lists**:

> - Adding: the header's primary "Add …" stays, and the list also ends with an inline add in the same words — a dashed card the size of the others in card lists, a borderless muted last row ("+ Add …") in row lists. It appears only after at least one item, on views where a new item would show up (not Archived/Completed tabs, not a filter with no matches). It behaves exactly like the header button, including opening the limit modal at a plan limit. An empty list shows its empty state, never a lone add tile.

Check the surrounding Lists bullets still read consistently with it.

### Edge cases

1. Adding the learner that hits the limit: the redirect re-renders, so both
   tile and header switch to the limit modal.
2. Downgraded / over the free limit: `can_add_learner?` is false → tile opens
   the limit modal, under the existing banner; read-only learner cards stay
   before it.
3. Adding a class while filtered: the new class may not match the filter and
   won't show after the redirect; the "Class added" toast confirms it.
   Accepted — filter prefill is deferred.
4. Last active class completed/archived: Active tab shows the new
   "No active classes" empty state, never a lone tile.
5. Tile alone on a grid row (e.g. 3 cards + tile): fine — "never alone" means
   never the only thing in the list.
6. Modal content fails to load: same lazy modal/frame as the header button; no
   new failure path.
7. Two same-named buttons per page: fine for accessibility (identical action),
   but existing tests must disambiguate. Tests that use "Add learner"/"Add
   class" today: `test/integration/learner_forms_test.rb`,
   `test/integration/learners_index_test.rb`,
   `test/integration/courses_index_test.rb`,
   `test/integration/course_forms_test.rb`,
   `test/system/courses_system_test.rb`,
   `test/system/learners_system_test.rb`.

## Scope

**In:** `AddTileComponent` (card style) with preview and test; inline tile on
Learners (Active) and Classes (Active tab); trigger options on
`learners/_add_trigger`, `learners/_limit_modal`, `application/_lazy_modal`;
Classes "No active classes" empty state; ux-notes Lists rule; test updates.

**Deferred:** Parents (family page) inline invite row; API tokens page; a row
style for `AddTileComponent` (documented in ux-notes, built when the first row
list needs it); prefilling the add form from active filters.

## Open Questions

None.
