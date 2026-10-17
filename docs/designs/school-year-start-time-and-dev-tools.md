> Ticket: COV-125
> Branch: feature/cov-125-school-year-start-time-and-dev-tools
> Plan created: docs/plans/school-year-start-time-and-dev-tools.md

# Feature: School year — Start time and dev tools

## Problem
Parents (same as Year and time off: every homeschool family, including
year-round, 4-day, and shift-working) need a usual start time so Today can
estimate times later without asking every morning. Developers need to test
Welcome Back, misses, Huddle patterns, and forecasts without waiting real days.

## Approach
Recommended approach (dedicated controllers, no migration):

- **Shape of the day**: its own singular resource
  `/planner/school_year/shape_of_day` → `SchoolYears::ShapeOfDaysController`
  (`edit`, `update`), including `CurrentSchoolYear` and `forbid_ended_year`.
  It permits only `school_starts_at`, so this form can never touch the year's
  dates or weekdays, and its failure path re-renders its own modal (not Edit
  year's). Opened from a header button on both Planner tabs.
- **Clock override**: a dev page at `/dev/clock` writes a fixed date to the
  gitignored file `tmp/dev_today`. `Account#today` returns that date when
  `Rails.env.development?` and the file holds a valid date; otherwise the real
  1am family-clock logic. `Account#today` is already the single source of
  "today" for all school-year logic, so nothing else changes. A file (not
  session/env var/`travel_to`) because it is shared by server, console, jobs,
  and `db:seed`, survives restarts, and doesn't shift `created_at`, Devise
  session expiry, or Stripe timestamps.
- **Seed families**: three new logins in `db/seeds.rb`, dated from
  `Account#today`.

## Acceptance Criteria
- A parent can set, change, and clear the usual start time from Planner →
  Shape of the day.
- In development, setting the clock override changes the family's today
  everywhere (header counts, mid-year rules); clearing it restores real time.
- The clock override and seed families can't be reached in production.
- `bin/rails db:seed` creates the three seed families with years and time off
  matching their scenarios.

## Prototype
None.

## Data Model
**No migration, no new tables.**

`SchoolYear#school_starts_at` (existing nullable `time` column, added by COV-124)
- Optional; blank saves as `nil` ("not set").
- Wall-clock time in the family's zone (e.g. 8:30am); Postgres `time` stores no
  date or zone, so a time-zone change keeps 8:30am.
- No extra validation (native time input; empty = not set; an unparseable
  tampered value casts to `nil`, no error).
- Not carried between years (next-year planning isn't built).
- Ended year: already refused by the model's `past_days_are_protected`
  (`ENDED_ERROR`); controller also returns 403 via `forbid_ended_year`.

`DevClock` — plain Ruby class, `app/models/dev_clock.rb`, no database
- `DevClock.today` → the date in `tmp/dev_today` in development; `nil` in test,
  production, or when the file is missing/unreadable/invalid (never raises).
- `DevClock.set(date)` writes the file; `DevClock.clear` deletes it.

`Account#today` → `DevClock.today || (Time.current.in_time_zone(time_zone) - 1.hour).to_date`
- An override is a fixed date (doesn't tick); the 1am turnover doesn't apply
  while set. It applies to every family.
- Tests never read a stray file because `DevClock` only reads in development;
  tests of the override stub the environment check.

Seed data (`db/seeds.rb`, inside `if Rails.env.local?`, idempotent via
`find_or_create_by!`; password `password`; each in its own family):

| Login | Family | School year | Time off |
|---|---|---|---|
| `new@cove.test` | New Family | `SchoolYear.create_default_for!` — same as a signup today | Defaults still ahead |
| `midyear@cove.test` | Mid-year Family | Default dates for the current school year (started in August) | Defaults, plus one past entry (e.g. "Fall break", already over) |
| `away@cove.test` | Away Family | Same as mid-year | Same as mid-year |

- Dates are based on `Account#today`, so seeding with an override set builds
  around that date.
- Mid-year/away need dates before today, which past-day protection blocks —
  write those directly (as the COV-124 backfill did), not through validations.
- On a summer date, "mid-year" means the most recent August-start year, which
  may already be ended. Accepted for a dev seed.
- "Away" currently has the same shape as mid-year; see Deferred.

## Screens / Flows

### Planner header (both tabs)
"Planner" title with a **Shape of the day** outline (secondary-styled) button
right of the title line, in `PageHeaderComponent`'s `primary_action` slot so
it stays visible on phones (Planner has no "Add…" primary; the
`secondary_actions` slot would hide it on phones inside a one-item "…" menu).
On phones it wraps under the title per the existing header layout. Hidden
when the year has ended. Built with `application/lazy_modal` (button trigger),
like Edit year. Lives in `app/views/planners/_header.html.erb`, which both tabs
render.

**Primary tasks:** 1. Open Shape of the day.

### Shape of the day modal
- Title: **Shape of the day**.
- One field: **School usually starts at** — `form.time_field` inside
  `FormFieldComponent`, prefilled when set. Help text: "Optional. Cove uses
  this to estimate times on your day."
- No time periods, rows, or empty state (Today views).
- Buttons: Cancel and Save, bottom right; stacked on phones, Save on top
  (same as Edit year's form).
- Save (including saving an empty field to clear): closes the modal, stays on
  the tab the parent came from, toast "Saved.".
- Errors inline in the modal. Ended year → 403 (as Edit year).
- The start time isn't displayed anywhere else yet.

**Primary tasks:** 1. Set or change the start time. 2. Clear it.

### `/dev/clock` (development only)
Plain dev-tools page like `/dev/typography`.
- Shows "Real today for your family: 17 Oct 2026" and "Override: none" (or the
  date).
- Date field + **Set**; **Clear** only when an override is set.
- One-line explanation: "Every family's today uses this date until you clear
  it."
- Note: "Edits made while pretending stay when you clear it. Reseed if data
  looks odd."

**Primary tasks:** 1. Set a pretend date. 2. Clear it.

### Dev clock strip
Slim bar at the top of signed-in pages, only in development and only while an
override is set: "Dev clock: pretending it's 14 Oct 2026 · Change · Clear".
Change links to `/dev/clock`; Clear is a small button that clears the override
and returns to the current page. It adds only its own height; header layout is
otherwise unchanged.

## Edge Cases
1. Year ends while the modal is open (stale tab): Save → 403, nothing changes.
2. Two parents edit at once: last save wins.
3. Time zone change: the wall-clock time stays (8:30am stays 8:30am).
4. Display: the field uses the browser's time format; later displays (Today)
   use "8:30am" per ux-notes formats.
5. Tampered value: saves as not set, no error.
6. Production/test: `/dev/clock` routes only under `Rails.env.local?`; the
   controller 404s outside development; `DevClock.today` is `nil` outside
   development. Test all three guards.
7. Edits made while overridden stay after clearing and may look odd against
   real past-day rules (e.g. weekday history dated ahead). Dev-only; reseed or
   `db:reset`. Noted on `/dev/clock`.
8. Unreadable/junk `tmp/dev_today`: treated as no override.
9. Running `db:seed` twice changes nothing (families found by login email,
   year created only if missing).
10. Seeding on a different overridden date: existing seed families keep old
    years; `bin/rails db:reset` to rebuild.
11. Seeding on a summer date: mid-year/away get the year that ended in May,
    possibly already over. Accepted.
12. Seeding on the exact August start day: keep that year and omit the extra
    past time-off entry, since no day in the year is past yet.

## Scope
**In:**
- Shape of the day header button + modal (start time only): set, change,
  clear. Free, either parent.
- `DevClock`, `/dev/clock`, dev clock strip, `Account#today` override.
- Three seed families.
- `docs/product/ux-notes.md` → Page structure → Header edits (decided in this
  brainstorm):
  - "…the rest in a "…" menu." → "…the rest in a "…" menu. Use a "…" menu
    only when actions don't fit otherwise, never for a single item."
  - Phone line → "Phones: actions wrap to a row under the title; the primary
    keeps its label, secondaries move into "…" — unless that leaves one item,
    which stays a visible button."

**Deferred:**
- Time periods, and the Shape of the day modal's rows and empty state (Today
  views).
- Setting the start time in Setup step 4 (Setup slice).
- **"Away" as real data.** The app doesn't track parent activity (no
  `last_sign_in_at`, no "last seen"). The Welcome Back ticket must include:
  *Add a "last seen" record for the family (e.g. the date a parent last opened
  Cove), and update the `away@cove.test` seed so it's set to 12 days before
  `Account#today`.* Jordan adds this to the Welcome Back slice/ticket.

## Open Questions
None.

## More Info
- Rule: the usual start time is optional. With none set, Today (later) shows
  no estimated times rather than asking.
- Design change from the ticket: the ticket specified a Planner "…" menu
  holding Shape of the day. Decided instead: no "…" menu with one item; it's a
  visible header button (see ux-notes edits above).
- No other product docs to update (COV-124 added the glossary and
  product-brief lines).
