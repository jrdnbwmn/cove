> Ticket: COV-121
> Branch: feature/cov-121-learner-page
> Plan created: docs/plans/learner-page.md

# Feature: Learner page

## Problem

Parents need one place to answer “how is Mia doing?” in under 30 seconds.
The learner page provides that record-page shell, starting with current
classes. Grade level also needs a fixed vocabulary for the later features
that depend on it.

## Approach

Add `/learners/:id` using the existing Learner, Course, and Enrollment
models, existing modal forms, and catalog components. No new models are
needed. This feature is available on Free and Premium alike.

Keep the learner page focused on reviewing one learner. Class creation
stays in Classes. Both empty and populated class sections link to Classes
filtered to the learner; neither opens Add class from the learner page.
This is an approved change from the supplied ticket.

Keep `grade_level` as text containing the full display label, or SQL NULL
for No grade level. Enforce the fixed list in both Rails and the database.
Convert existing free-text values using the agreed mapping before enforcing
the database constraint.

Reuse the existing forms while preserving whether an action began on the
list or learner page, so successful actions return to the agreed place.
Continue using server-rendered Rails pages, Turbo for modal forms, and
Stimulus for client-side interactions.

## Acceptance Criteria

- Active and archived learner cards open `/learners/:id`; card menus retain
  their existing Edit, Archive, Restore, and Delete actions where applicable.
- The learner page has “← Learners,” keeps Learners highlighted in the
  sidebar, and shows the learner's name, color, and grade when present.
- The title switcher reaches every other active learner, including from an
  archived learner's page. Hide it when no destination is available.
- An active learner's outlined Edit button opens the existing details modal
  with name, grade select, and color; Archive and Delete remain at the bottom.
- Save, Archive, and Restore begun on the learner page stay on that learner's
  page and refresh its state. Delete returns to Learners. Actions begun on
  the list keep returning to the list. Add learner still stays on the list
  with its existing toast.
- Current classes and activities lists only the learner's active classes,
  showing name and optional subject as non-tappable rows.
- Both populated and empty class sections show “See all in Classes,” opening
  Classes filtered to this learner. The empty state says “No classes yet.
  Classes Mia takes will appear here.” with the actual learner name. There
  is no Add class action on this page.
- Archived learner pages are view-only, show “Mia is archived. Mia's records
  are kept.” with Restore, and hide Edit and the entire classes section.
  Restore remains subject to the existing learner cap.
- Every later section is hidden in this slice, without placeholders or empty
  states. Only the active learner's classes section has an empty state.
- Learner and class delete confirmations name the item, count all links being
  removed, state that deletion cannot be undone, and suggest archiving or
  keeping an already archived item. Learner deletion explicitly says the
  classes remain. There is no Export link.
- Grade in both Add and Edit is a fixed select: Pre-K, Kindergarten, 1st grade
  through 12th grade, and No grade level. Cards and page headers show the
  stored label or nothing when blank.
- Existing grades on active and archived learners are converted according to
  the mapping below. Unmatched values become NULL. Rails and the database
  reject noncanonical grades after conversion.
- Every flow works at phone width, including long names, switcher, modals,
  edit actions, and class rows.
- Family-scoped access and equal permissions for both parents are preserved.

## Prototype

None. The approved layout below follows the current product and UX docs and
reuses the component catalog.

## Data Model

### Learner

Keep the existing family association, name, color, `archived_at`, and
Enrollment/Course associations. `grade_level` remains a nullable string;
there is no new grade model or enum conversion.

Canonical nonblank values are:

`Pre-K`, `Kindergarten`, `1st grade`, `2nd grade`, `3rd grade`, `4th grade`,
`5th grade`, `6th grade`, `7th grade`, `8th grade`, `9th grade`, `10th grade`,
`11th grade`, `12th grade`.

“No grade level” is represented by SQL NULL. New submissions accept canonical values
or blank; legacy aliases are for the one-time conversion, not a second
ongoing grade-entry format. Add inclusion validation in Rails and a database
check constraint allowing exactly the canonical values or NULL.

### Existing-grade mapping

Apply the mapping to both active and archived learners. Ignore casing and
normalize whitespace, including surrounding whitespace.

| Existing value or pattern | Canonical value |
| --- | --- |
| `PreK`, `Pre-K`, `Pre K`, `Prekindergarten`, `Pre-kindergarten` | `Pre-K` |
| `K`, `Kinder`, `Kindergarten` | `Kindergarten` |
| Bare number `1` through `12`, e.g. `3` | Corresponding grade, e.g. `3rd grade` |
| Bare ordinal `1st` through `12th`, e.g. `3rd` | Corresponding grade |
| Bare ordinal word `first` through `twelfth`, e.g. `third` | Corresponding grade |
| `Grade <number>`, e.g. `Grade 3` | Corresponding grade |
| `<ordinal> grade`, e.g. `3rd grade` | Corresponding grade |
| `<ordinal word> grade`, e.g. `third grade` | Corresponding grade |
| Blank, whitespace-only, or NULL | NULL |
| Anything unmatched, including `Freshman`, `Sophomore`, `Junior`, and `Senior` | NULL |

Ordinal words are first, second, third, fourth, fifth, sixth, seventh,
eighth, ninth, tenth, eleventh, and twelfth. Do not infer grades from age,
high-school nicknames, or ambiguous values.

Keep the data conversion separate from the schema/constraint migration, in
accordance with the repo's migration rules. Conversion is intentionally
lossy: a rollback cannot reconstruct the original free text. Do not retain
an extra copy of learner data to make that possible, and do not log grade
values or learner identities during conversion.

Verify all canonical grades and accepted alias patterns, casing and spacing
variations, NULL/blank values, and unmatched values. Verify both Rails and
database enforcement and conversion of active and archived learners.

### Course and Enrollment

No structural changes. The page reads the current family's learner's active
courses through Enrollment, using existing class status rules and ordering.
Completed and archived classes do not appear in Current classes and activities.

Archiving a learner retains their class links while hiding them from class
lists and pickers. Editing a class preserves those hidden links; restoring
the learner makes them visible again. Archiving removes no class links.

Permanent learner deletion removes all their links across active, completed,
and archived classes; those classes remain. Permanent class deletion removes
all its learner links, including links to archived learners; the learners
remain. Calculate confirmation counts from those existing links when opening
the confirmation. No stored counters are needed.

Class membership is not a historical activity snapshot. Future work,
attendance, and participation features must distinguish retained past
records from future activity after archival. This ticket preserves existing
links but does not build that history or its reporting.

## Screens / Flows

### Learners list — `/learners`

**Primary tasks:** 1. Open a learner. 2. Add or manage learners.

Keep the existing card layout. Change active and archived card click targets
to the record page. Keep the independent “…” menus and their existing
status-appropriate actions; a menu action must not trigger card navigation.
Display the canonical grade label, or omit the grade line when blank.

Add learner still opens its modal, now with the grade select. On success,
stay on the list and show the existing learner-naming toast. Editing or
changing status from a list card continues returning to the list.

### Active learner page — `/learners/:id`

**Primary tasks:** 1. Review this learner's current classes. 2. Switch
learners. 3. Edit details.

Top to bottom:

1. “← Learners” links to the section. Learners remains highlighted in the
   sidebar.
2. Header: existing color dot and learner name, title switcher, optional
   grade on the line below, and outlined Edit at the right. No header “…”
   menu or quick actions.
3. Current classes and activities: a bordered container with a sans serif
   heading and simple divided rows showing class name and subject when
   present. Use existing Classes ordering: subject, then class name. Rows have no links, chevrons, or click styling.
4. “See all in Classes” opens `/classes?learner=<learner id>`, using the
   existing Active default. Parents can use the existing Classes tabs and
   filters there.

When there are no active classes, replace the rows with “No classes yet.
Classes Mia takes will appear here.” using the learner's actual name.
Keep “See all in Classes” below it. Do not render an Add class button or
inline add row in either state, and do not add a learner-page class-creation
or preselection flow.

The title switcher uses the existing dropdown pattern with navigation links
to other active learners in existing learner order (`created_at`, then id).
The current learner is identified by the title; omit them from destinations.
Hide the switcher when there are no destinations. Archived learners are
never destinations.

Hide all later sections: Recent work, Coming up, This year, Grades, and
Paperwork. Do not show placeholders for features that are not built.

On phones, allow the name to wrap, keep the switcher with the title, and
wrap Edit beneath the title. Stack class name and subject as needed.
Use the existing shared page width and responsive spacing.

Show every active class as a row, without adding search or pagination to
this overview. This is an approved exception to the generic UX rule requiring
search and pagination above 12 items; document the learner-summary exception
in `docs/product/ux-notes.md` during implementation.

### Archived learner page — `/learners/:id`

**Primary tasks:** 1. View the retained learner identity and archive state.
2. Restore the learner or switch to an active learner.

Keep the back link, name, color, and optional grade. Near the top, show
“Mia is archived. Mia's records are kept.” with Restore. The same title
switcher offers active learners when any are available.

Do not render Edit, a header action menu, or Current classes and activities.
Direct Edit/update requests cannot bypass the archived learner's view-only
state. Permanent deletion remains available through the existing archived
card menu on the list.

Restore stays on this page and returns it to the active layout with the
existing restored toast. Respect the existing learner cap: Restore remains
unavailable while it would exceed the cap, with an explanation and the
existing Email us path. A refused restore leaves the learner archived and
keeps the parent on this page with the existing explanatory error.

### Add/Edit learner modal

**Primary tasks:** 1. Save learner details. 2. Deliberately archive or delete
an existing learner.

Reuse `UiModalComponent`, the existing form field and color-picker patterns,
`SelectComponent`, and `ButtonComponent`. Fields remain name, grade, color.
The grade select offers Pre-K, Kindergarten, 1st grade through 12th grade,
then an explicit No grade level option representing blank.

Edit from the learner page opens the existing modal. Save closes it, refreshes
the page's identity/grade, and stays on that learner's page with the existing
saved toast. Cancel closes without saving. Closing with unsaved changes
uses the existing discard confirmation inside the same modal.

Archive and Delete remain at the bottom, outside the details form where
needed to avoid nested forms. Archive closes the modal and stays on the
learner page in its archived state with the existing toast. The page's
class links are retained.

Validation errors keep the modal open, preserve entered values, and appear
inline beside the relevant fields. Preserve existing model-level error
handling. An invalid submitted grade must produce a validation error rather
than silently saving an arbitrary value.

### Delete confirmations — learner and class

**Primary tasks:** 1. Understand what permanent deletion removes. 2. Confirm
deletion or keep the record.

Reuse the existing confirmation modals. A confirmation entered from Edit
replaces the edit content inside the same modal; never nest dialogs.
Cancel returns to Edit and preserves unsaved details. A confirmation opened
directly from a card menu closes on Cancel.

Learner confirmation example:

- Heading: “Delete Mia?”
- When links exist: “Mia will be removed from 3 classes, which stay for
  everyone else.”
- State that deletion cannot be undone and suggest archiving to keep records.
  If already archived, suggest keeping Mia archived instead.
- Use a specific destructive label such as “Delete Mia.” No Export link.

Class confirmation names the class and counts all enrolled learners,
including archived learners. Explain that its links to those learners will
be removed, that deletion cannot be undone, and suggest archiving. For an
already archived class, suggest keeping it archived. Preserve existing
class-status transition rules; do not add a direct Completed-to-Archived
action in a confirmation.

Both confirmations handle singular and plural counts. Omit the
relationship-count sentence when there are zero links, while retaining the
permanence warning and archive alternative. Do not add counts of work,
grades, or record types that do not exist yet.

Confirming learner deletion returns to Learners with the existing toast.
Class deletion keeps the existing Classes tab/filter return behavior.
Confirmations retain the existing full-height modal treatment on phones.

### Access, missing data, and feedback

Scope the page and every action through the current family; another family's
learner returns 404. Both parents have equal read/edit/archive/restore/delete
permissions. Do not add a Premium gate.

Omit blank grade and subject lines. Show the classes empty state only for
an active learner with no active classes. Reuse existing modal loading and
error handling rather than adding separately loaded page sections. Routine
successful actions use the existing toast host and copy.

## Scope

**In:** Learner record page; active and archived card navigation; switcher;
page-aware modal action destinations; fixed grade select, legacy conversion,
Rails validation, and database constraint; current-class rows and filtered
Classes link; learner/class delete counts and explanations; phone behavior;
the relevant product-doc updates below.

**Deferred:**

- Curriculum name and navigation from a class row to its page: Lessons on
  classes (Phase 1).
- Schedule details and activities without a class: Blocks on set days
  (Phase 1).
- Class-row position, Recent work, finished curricula in This year, and
  logged-work counts in delete confirmations: Done is recorded (Phase 1).
- This year's days and hours: Records: What we did and attendance (Phase 1).
- Loops in the activities list: Phase 2.
- Coming up and Past years: Phase 2 and Phase 5.
- Grades, credits, GPA, and grade counts in delete confirmations: Phase 3.
- Paperwork: Phase 4.
- Export link in learner deletion: Export, not yet sliced.
- Avatars: later phase. Default involvement: open question on Blocks.
- Historical activity/reporting around archival belongs to the later record
  features; no such records or history snapshots are introduced here.

There is no Add class flow on the learner page. That action belongs to
Classes, rather than being deferred to a later learner-page feature.

Never add sibling or grade-norm comparisons, “behind” or overdue counts,
charts, streaks, or mastery tracking.

## Open Questions

None. All design sections and the summary-list exception were approved.

## More Info

- Source: supplied COV-121 ticket in
  `.context/attachments/N3bGjR/pasted_text_2026-10-16_12-09-05.txt`.
- Notion slice: https://app.notion.com/p/3fa0fc47bb8b81e68944c5600ec30f24
- Learners feature page: https://app.notion.com/p/3f50fc47bb8b813584d1f9dac8da3c3c
- Classes and lessons feature page:
  https://app.notion.com/p/3f50fc47bb8b81728f94ddd10fb7a41c
- Depends on no other ticket. Keep the read budget under 30 seconds; the page
  needs no new input because its content comes from other features.
- During implementation, update `docs/product/product-brief.md` to describe
  learner record pages, sections appearing when they have data, archived
  view-only pages, and the fixed optional grade list. Also capture the agreed
  action destinations, class creation staying in Classes, and the distinction
  between retained class links and historical activity records.
- During implementation, update `docs/product/ux-notes.md` with the approved
  learner-summary exception: show all current-class rows without search or
  pagination, even above 12 items.
- If scope grows, the ticket permits splitting grade selection/conversion
  into its own issue; the shell and delete counts stay together. No split is
  currently needed.
