> Ticket: COV-124
> Branch: feature/cov-124-school-year
> Plan created: docs/plans/school-year.md

# Feature: School year — Year and time off

## Problem
Cove has no idea which days are school days. Every homeschool family, including year-round,
4-day, and shift-working families, needs a sensible year automatically, a way to add days off
in about 30 seconds, and a live school day count that matches their own, without keeping a
calendar or filling in a long form before school can start.

## Approach
Two new models, `SchoolYear` and `Break` (UI: time off), plus `accounts.time_zone`.
School days are **computed, not stored**: a date is a school day when it's inside the year, on a
school weekday that applied on that date, and not in time off. Counting walks the year's dates
in Ruby (≤ 366).

"Past days keep what happened" is enforced two ways:
- **Dates** (year start/end, time off) — validations forbid changing anything before today.
- **Weekdays** — a `weekday_history` jsonb column on `school_years` remembers earlier weekday
  settings and the last day each applied, so a mid-year change (Mon–Fri → Mon–Thu) never
  re-counts past days.

Logic is split into concerns on `SchoolYear`, matching the `Account` modular-model convention:
- `SchoolYear::Defaults` — builds the default year (mid-year, summer, last-day, and
  in-progress-break rules). Called when a family is created and by the backfill migration.
- `SchoolYear::Counting` — school-day predicate, totals, so far / to go, before Cove, and the
  Edit year "Adds N" preview.

The family's clock is `Account#today`: the current time in `accounts.time_zone`, minus one hour
(the day turns over at 1:00am), as a date. **All school-day logic uses `Account#today`, never
`Date.current`.** Each request also sets `Time.zone` from the family's zone instead of the
parent's, so both parents see the same day and the same timestamps.

`/planner` replaces `/schedules` (which permanently redirects). Tabs are real links (like
Classes' status tabs). Modals use the existing `modal-lazy-content` frame (like learner/class
forms).

## Acceptance Criteria
- A new or existing family has a default year without visiting any page; header line counts
  match by hand.
- A family signing up on 12 Jan gets a year starting 12 Jan with only time off still ahead; one
  signing up on 10 Jul gets next year's default.
- Adding, editing, and deleting time off updates the school day count; Undo restores a deleted
  entry.
- Overlapping time off is flagged inline; Replace it swaps future entries for the new one. If
  any overlapping entry has already started, Replace is unavailable and an Edit link is offered
  in the same modal; no entries are deleted.
- Changing dates or school weekdays never changes counts or records for past days; the end date
  can't move before today.
- Edit year shows "Adds N school days." when the end date moves later, with a skeleton loading
  state while it's computed.
- Changing the family time zone changes which date is "today" for the whole family; a second
  parent in another zone sees the same day.
- `/planner` shows Schedule and School year tabs; `/schedules` redirects to `/planner`.
- Works on phone and desktop.

## Prototype
None.

## Data Model

### `SchoolYear` (new, `school_years`)

| Field | Type | Notes |
|---|---|---|
| `account_id` | FK, not null, indexed | Belongs to the family |
| `starts_on`, `ends_on` | date, not null | DB check: `ends_on > starts_on` |
| `school_weekdays` | integer[], not null | Current setting, Ruby `Date#wday` numbers (0 = Sun … 6 = Sat), e.g. `[1,2,3,4,5]` |
| `weekday_history` | jsonb, not null, default `[]` | Earlier settings, oldest first: `[{"through": "2027-01-11", "days": [1,2,3,4,5]}]`. For a date, use the first entry whose `through` ≥ date; otherwise `school_weekdays` |
| `tracked_from` | date, null | First day in Cove; set only on a family's first year |
| `status` | string, not null, default `"active"` | Only `active` for now (Year planning adds others). "Ended" is derived from dates, never stored |
| `school_starts_at` | time, null | Column only; UI ships in COV-125 |

- `Account has_many :school_years, dependent: :destroy`; `Account#school_year` returns the active
  one.
- `SchoolYear belongs_to :account`; `has_many :breaks, dependent: :destroy`.
- **Unique partial index:** one `active` year per `account_id`.
- **Validations:**
  - at least one school weekday; every value in 0–6
  - `ends_on` after `starts_on`; year at most 12 months long
  - `ends_on` not before `account.today`
  - `ends_on` not before the last time off's `ends_on` ("Spring break ends after this date.
    Change it first.")
  - `starts_on`: free to change before the year begins. Once begun, it can only move **earlier**,
    and only in the family's first year (`tracked_from` present); in later years it's locked.
  - An ended year (`ends_on` < today) can't be edited at all.
- **Saving a weekday change:** if the year has begun, append
  `{through: today - 1, days: old_weekdays}` to `weekday_history`, then set `school_weekdays`.
  If the year hasn't begun, just replace. A second change on the same day replaces the first
  (no zero-length history entry).

### `Break` (new, `breaks`; UI: **time off**)

| Field | Type | Notes |
|---|---|---|
| `school_year_id` | FK, not null, indexed | Belongs to the year |
| `name` | string, not null | |
| `starts_on`, `ends_on` | date, not null | DB check: `ends_on >= starts_on` (one day = same date) |
| `source` | string, not null, default `"added"` | DB check: in `default`, `added`, `repeating`. No `group_id` yet — added with Repeating time off |

- **Validations:**
  - inside its year's `starts_on..ends_on`
  - no overlap with other time off in the same year (model-level only; no `btree_gist` exclusion
    constraint — two parents max, last write wins, overlap re-checked on every save)
  - a new entry can't start before today
  - once started (`starts_on` ≤ today): only `name` and `ends_on` may change, and `ends_on` can't
    move before today
  - a started entry can't be destroyed
- Ordered by `starts_on`.

### `accounts.time_zone` (new column)
String, not null, default `"Mountain Time (US & Canada)"`, validated against
`ActiveSupport::TimeZone` names. A new family copies its first parent's `users.time_zone` when
present, otherwise keeps the default. Backfill: existing families get the default (no parent
zones exist to copy).

### `users.time_zone` (existing column, newly populated)
Nothing in the app currently sets it — it's blank for every real user (only fixtures fill it).
At signup a small Stimulus controller fills a hidden field with the browser's IANA zone
(`Intl.DateTimeFormat().resolvedOptions().timeZone`); the server maps it to an
`ActiveSupport::TimeZone` name and saves it, or leaves it blank if it can't be mapped. No UI.

### `Account#today`
`(Time.current.in_time_zone(time_zone) - 1.hour).to_date`. The one clock for school days,
closing the day, and attendance.

### `SchoolYear::Defaults`
`SchoolYear.create_default_for!(account)`, using `account.today`:

- **Default year** for a school year starting in calendar year Y: start = first Monday on or
  after 15 Aug Y; end = last Friday on or before 31 May Y+1; Mon–Fri. Examples:
  2026–27 = Mon 17 Aug 2026–Fri 28 May 2027; 2027–28 = Mon 16 Aug 2027–Fri 26 May 2028;
  2028–29 = Mon 21 Aug 2028–Fri 25 May 2029.
- **Default time off** (`source: default`): **Thanksgiving** = 4th Thursday of November + the
  Friday; **Winter break** = 21 Dec–1 Jan (fixed, weekends included).
- **Mid-year** (today ≥ this year's default start and **before** its end date): the year starts
  today; only time off that hasn't ended is added; time off already under way starts today
  (e.g. signup 26 Dec → year starts 26 Dec, Winter break 26 Dec–1 Jan, first school day 2 Jan).
- **On the default end date itself, summer, or before the default start:** next default year
  (the upcoming one), with both entries.
- `tracked_from` = first school day on or after today.
- Called inside the family-creation transaction (`create_default_account` path), so a family
  never exists without a year. Not called when a parent joins by invitation (no family is
  created). Archived families are skipped by the backfill.
- **Backfill:** a migration creates a default year for every active family without one, using
  the same rules from the deploy day. It must run in the migration because Render's free tier
  has no shell for a one-off task.

### `SchoolYear::Counting`
- `school_day?(date)` — inside the year, on the weekday that applied on that date (history),
  not in time off.
- `school_days_count` — total for the year.
- `so_far_count` — school days strictly **before** `account.today`. `to_go_count` — today
  onward. They sum to the total.
- `before_cove_count` — first year only: school days from `starts_on` up to (not including)
  `tracked_from`. Included in `so_far_count`.
- `added_days_if_ended_on(date)` — school days gained by moving the end to `date` (0 or nil when
  not later). Powers the Edit year preview.

## Screens / Flows

### Signup and family creation (no UI)
1. Parent signs up; browser zone saved to `users.time_zone` silently.
2. Family is created with `time_zone` copied from the parent (or Mountain) and its default year.
3. A second parent joining by invite shares the family's year.

### Planner page — `/planner` (Schedule tab), `/planner/school_year` (School year tab)
- Sidebar item renamed "Schedules" → **Planner**, linking to `/planner` (active on both tabs).
- `get "/schedules" => redirect("/planner")` (permanent). The `schedules` route and controller
  go away; the Schedule tab keeps the current placeholder content ("Coming soon" empty state).
- `PageHeaderComponent` title "Planner", no header actions (both actions are School year-tab
  specific, so they live inside the tab).
- `UiTabsComponent` (links mode, underline): **Schedule · School year**, each its own URL.

### School year tab
**Primary tasks:** 1. See how many school days are done and to go. 2. Add time off. 3. Edit the
year.

- **Summary line** (sans, wraps on phones; ranges via existing `friendly_date_range`):
  - Running: "Mon–Fri · 17 Aug 2026–28 May 2027 · 193 school days · 41 so far, 152 to go"
  - First year with days before Cove: append ", including 40 before Cove" (no link)
  - Not started yet: "Mon–Fri · 16 Aug 2027–26 May 2028 · 194 school days · Starts 16 Aug"
  - Ended: "Mon–Fri · 17 Aug 2026–28 May 2027 · 193 school days · This year has ended."
    followed by "Planning next year is coming soon. Your records for this year are kept."
  - Weekday label: contiguous runs as ranges ("Mon–Fri", "Mon–Thu"), otherwise listed
    ("Mon, Wed, Fri").
- **Actions** (secondary `ButtonComponent`s, right of the summary on desktop; full width,
  stacked below it on phones): **Add time off**, **Edit year**. Both hidden when the year has
  ended.
- **Time off rows** (follow `courses/_course_row` row pattern): name, then dates
  ("21 Dec 2026–1 Jan 2027"; "26 Nov" for one day in the current year), dividers, whole row is a
  link opening the edit modal. Past entries render as plain, non-tappable rows. List ends with
  the muted inline "+ Add time off" row (only when at least one entry exists and the year hasn't
  ended).
- **Empty:** "No time off yet. Add some when you plan days off." with an Add time off action.

### Add / edit time off modal (`UiModalComponent` via `modal-lazy-content`)
**Primary tasks:** 1. Name it and pick dates. 2. Resolve an overlap. 3. Delete it.

- Title: "Add time off" / "Edit time off".
- Fields (`FormFieldComponent`, single column): **Name**, **Start** (defaults to today), **End**
  (defaults to Start). Native date inputs. A small Stimulus controller moves End to match when
  Start is set later than End.
- **Overlap:** inline warning `AlertComponent` above the buttons: "This overlaps Winter break
  (21 Dec–1 Jan)." (lists every overlapping entry). Buttons: **Replace it** (or **Replace them**)
  and Cancel. Replace is available only when every overlapping entry starts in the future; it
  deletes those entries and saves the new one in one transaction, in the same modal. If any
  overlapping entry has already started, Replace is unavailable and an Edit link for the
  started entry is offered in the same modal. No entries are deleted, including future entries
  in a mixed overlap. Entered values are kept.
- **Entry under way:** Start disabled with help text "Already started. You can change the end
  date."; Delete hidden.
- **Edit mode:** destructive "Delete time off" button at the bottom.
- **Errors (inline):** "Choose dates inside your school year (17 Aug 2026–28 May 2027).",
  "Choose a start date from today on.", "Add a name.", "End on or after the start date."
- **Toasts:** "Spring break added." / "Saved." / "Time off removed" with **Undo**.
- **Undo:** the entry is hard-deleted; the toast's Undo posts the saved name/dates/source back to
  create it again. If that now fails validation (overlap, or the start has passed), show an
  inline message: "We couldn't restore Spring break. It overlaps Teacher day." / "… It would
  start in the past." This is the app's first server-backed toast action — `ui_toast_controller.js`
  supports action buttons client-side.

### Edit year modal
**Primary tasks:** 1. Change the end date. 2. Change school weekdays. 3. Change the start date.

- **Starts**, **Ends** (date fields). In the first year, Starts remains editable after the year
  begins, with validation allowing only an earlier date and help text: "The year has started.
  You can only move the start earlier." In later years, Starts is disabled once the year has
  begun, with help text: "The year has started."
- **School days:** `<fieldset>` with legend "School days" containing seven weekday toggle chips
  (Mon … Sun, wrapping on phones) — new `ToggleChipComponent` (see below). Help text: "Changes
  apply from today. Past days stay as they were."
- **"Adds 10 school days."** under Ends, in a small Turbo Frame that GETs a server preview
  whenever Ends changes (one counting rule, server-side). While loading, a one-line
  `SkeletonComponent` shimmers in its place. Shows nothing when the end moves earlier or not at
  all. Singular: "Adds 1 school day."
- **Errors (inline, under the field):** "Choose at least one school day.", "End the year after it
  starts.", "The year can be up to 12 months.", "The end can't be before today.",
  "Spring break ends after this date. Change it first."
- Save → toast "Saved.", header updates.

### Settings → Family
- Add **Time zone** to `accounts/_form` using `SelectComponent`: US zones first
  (`ActiveSupport::TimeZone.us_zones`), then all others. Help text: "Sets when each school day
  starts and ends for everyone in your family."
- Saving changes "today" for both parents immediately.

### New component: `ToggleChipComponent`
Built via `/create-component` from RailsBlocks' custom checkboxes
(https://railsblocks.com/docs/checkbox#custom-checkboxes): wrapping pill chips backed by native
`<input type="checkbox">`, no JavaScript. **Accessibility fix vs. RailsBlocks markup:** use
`sr-only` instead of `hidden` on the input (so it stays keyboard- and screen-reader-reachable),
with a visible focus ring on the chip, grouped in a `<fieldset>`/`<legend>`. Built as a reusable
component because Repeating time off and blocks on set days will need it. Uses brand tokens
(`--primary`) for the checked state.

## Edge cases
- Signup on a weekend/holiday mid-year: year starts today; `tracked_from` = next school day.
- Signup on the default end date: next year's default (avoids a one-day year).
- Year fully covered by time off from today: "0 to go"; nothing breaks.
- Changing the family time zone across a date line can move today by a day; counts follow;
  stored history dates don't change.
- Two parents editing at once: last save wins; overlap is re-checked on every save.
- Every lookup is scoped to the current family; another family's year or time off → 404.
  Either parent can do everything (same as Learners).
- Deleting a family deletes its years and time off.
- Downgrade changes nothing; everything here is Free.
- Bad input (unknown zone, weekday outside 0–6, missing date) → inline validation errors,
  entered values kept.

## Scope
**In:** everything above — `SchoolYear`, `Break`, `accounts.time_zone`, browser time zone capture
at signup, default year on family creation + backfill migration, Planner page with Schedule and
School year tabs, `/schedules` redirect, sidebar rename, Add/edit time off modal with overlap
Replace and Undo, Edit year modal with Adds-N preview, Settings → Family time zone,
`ToggleChipComponent`.

**Deferred** (ticket Out of scope):
- Setup step 2's summary line (Setup slice).
- Start time, Shape of the day modal, dev clock, seed families (COV-125).
- Before-saving "This moves N finish dates" line and the extend message's class names
  (Forecasts).
- Repeating time off (and `group_id`) and the year calendar (Phase 2).
- Before Cove totals and "Add what you did before Cove" (Phase 5).
- Close this year, Plan next year, Past years, Make changes (Year planning). Until then an ended
  year stays as-is and can't be edited or extended.
- How we do school tab; Add block.

## Repo docs to update (same PR)
- `AGENTS.md` glossary: remove the note that the `/schedules` placeholder is renamed when the
  Planner is built; add **Break** = time off in the UI (`Break` model); note `Account#today` is
  the family clock (1:00am turnover) — never `Date.current` for school-day logic.
- `product-brief.md`, new "School year (Built — `/planner/school_year`)" section:
  - Edits to the school year apply from today forward; past days keep what happened.
  - Default year rule (Monday on or after 15 Aug to Friday on or before 31 May, Mon–Fri,
    Thanksgiving + winter break), mid-year / summer / last-day signup rules.
  - Family time zone is the one clock; set from the browser at signup, Mountain fallback,
    changeable in Settings → Family.
  - Once a year ends, it can't be edited or extended; next year waits for Year planning, and the
    page says so.
  - Time off that has started can't be deleted, only ended earlier; Starts locks once a year
    begins (first year: may move earlier).
  - All Free; nothing changes on downgrade.

## Open Questions
None.

## More Info
- Budget: adding time off takes about 30 seconds.
- Never: a long required form before school can start, holidays assumed beyond the two prefilled
  entries, "behind" or "missed" anywhere, an edit that changes past days.
- "Before Cove" days are never gaps or missed, never get attendance, and plans never back-fill
  them. Outside the year's dates, the plan never runs.
- Jordan plans a Setup idea that builds on the browser time zone capture (not this ticket).
- Notion: School year slice page; School year feature; Schedule feature → Planner page.
