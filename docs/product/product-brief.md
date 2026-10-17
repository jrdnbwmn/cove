# Product Brief

How Cove behaves for users, and why. Code-level invariants and the glossary
live in `AGENTS.md` and aren't repeated here.

Each section is marked **Built** or **Decided, not built**.

## Free vs Premium (Built)

| | Free | Premium |
|---|---|---|
| Learners | Advertised as unlimited; real cap is `learner_limit` (default 15, raisable per family by a superadmin) | Advertised as unlimited; real cap is `learner_limit` (default 15, raisable per family by a superadmin) |
| Parents | Up to 2 | Up to 2 |

- Pricing is flat per family. No per-learner fee; Stripe quantity and pricing
  structure never change with learner count.
- No trial — Free serves that purpose.
- Every AI feature is Premium. For any other new feature, Premium gating is
  decided per feature: don't decide it; ask.

## Families (Built)

- Owner-only: deleting the family, transferring ownership. Admins do
  everything else, **including billing**.
- The subscription belongs to the family and survives a parent leaving.
- **One person belongs to exactly one family.** No second families.
- An existing user may accept another family's invite **only if their own
  family is empty** (no learners, renewing subscription, or other members).
  That empty family is archived, not deleted, so its billing history is kept.
  A subscription must be canceled first; a canceled subscription still in its
  paid period doesn't block joining. Learners or another parent mean the
  invite is refused with "contact support".
- The owner **must transfer ownership before deleting their login** if
  another parent is in the family. A non-owner parent deleting their login
  just leaves.

## Learners (Built — `/learners`, `/learners/:id`)

- Learner logins are a future version.
- Every plan has the same soft learner cap, `learner_limit` (default 15,
  raisable per family by a superadmin, never below the default). It's
  advertised as unlimited; families above it email us. The cap keeps co-ops
  and micro-schools off a family plan, so copy at the cap is soft and never
  names a plan.
- Only active learners count toward the cap. Creating or restoring a learner
  uses a slot; archived learners do not. At the cap, any plan sees "Email us".
  Restore remains unavailable while it would exceed the cap.
- Parents can archive learners to keep their records or delete them permanently.
- Learner record pages are available on Free and Premium. Active learners'
  pages show their current active classes; class creation stays in Classes.
  Both empty and populated summaries link to Classes filtered to that learner.
- Archived learner pages are view-only: they keep the learner's identity and
  archive notice, offer Restore when capacity allows, and hide Edit and the
  classes summary.
- Grade level is optional and uses a fixed list: Pre-K, Kindergarten, and
  1st grade through 12th grade. “No grade level” leaves it unset; parents
  cannot enter a custom grade.
- Save, Archive, and Restore return to the learner page when begun there,
  or to Learners when begun on the list. Add and Delete return to Learners.
- **On downgrade**, learners don't change: none is deleted, and every learner
  keeps the same access (active learners stay editable; archived learners
  stay view-only).

## Classes (Built — `/classes`)

- A class is anything the family needs a record of: attendance, curriculum
  progress, grades, credits, or a place on a transcript, portfolio, or report.
  Being logged isn't enough. Everything else is a schedule block.
- Classes have no Free limit.
- Grades always belong to a class. Evaluations are a separate, later record.
- Deleting a learner removes their enrollments.
- Archiving a learner keeps their enrollments but hides them from classes; they
  appear again when restored. Editing a class preserves those hidden links.
- Retained class links describe membership, not a historical activity record.
  Future work, attendance, and participation features must distinguish past
  records from future activity after archival; that history is not built yet.
- Deleting a class deletes its enrollments. Delete works in every status and
  always asks for confirmation.
- A class is **Active**, **Completed**, or **Archived**, never more than one.
  New classes are Active. Status is stored as `completed_at` / `archived_at`
  timestamps, and the database refuses a class that is both.
- Only an Active class can be completed or archived. A Completed class can be
  reopened and an Archived class restored; both return to Active. A request
  that doesn't fit the class's current status (a stale tab, a double click)
  changes nothing and shows an alert.
- Any class can be completed right away, with no activity. Completing or
  archiving doesn't lock editing: a Completed or Archived class stays editable,
  and saving never changes its status or date.
- Status changes are reversible, so they don't ask for confirmation. The word
  "Done" is reserved for schedule blocks; classes are "completed".
- `/classes` shows one status tab at a time (Active by default) with counts,
  and can be filtered by learner (active learners)
  and by subject (case-insensitive; "Math" and "math" are one subject). Tab,
  learner, and subject filters combine, and they live only in the URL. Counts
  follow the learner and subject filters and the search. Unknown filter values
  are ignored.
- Classes are listed as rows. Past 12 classes, the list adds search, which
  matches class name and subject and combines with the tab and filters.

## School year (Built — `/planner/school_year`)

- Everything here is **Free** and available to either parent; nothing gates
  on plan status.
- Every family always has one active school year, created with the family
  (and by a one-time backfill for existing families). A parent who joins by
  invitation shares the family's year. A family signing up mid-year gets a
  year starting that day, with only time off still ahead; signing up in
  summer or on the default end date gets the upcoming year.
- The default year starts the first Monday on or after 15 Aug and ends the
  last Friday on or before 31 May, Mon–Fri, with Thanksgiving (Thursday and
  Friday) and Winter holidays (21 Dec–1 Jan) as time off.
- School days are computed from the year's dates, school weekdays, and time
  off — never stored. A weekday change takes effect from today; days before
  today keep the weekdays they had. Past counts never change.
- Past days are protected: new time off can't start before today, started
  time off can only change its name and end date, and started time off can't
  be deleted. The end date can't move before today or before the last time
  off. In a family's first year the start can still move earlier after the
  year begins; in later years it's locked.
- An ended year can't be edited; the page says so and keeps its records.
  Planning the next year isn't built.
- Overlapping time off is never silently merged. Replace swaps the overlapping
  entries for the new one only when every one of them is still in the future;
  if any has started, nothing is deleted and the parent edits that entry
  instead. Deleting time off is permanent, with an Undo that re-adds it
  through the normal checks and says why if it no longer fits.
- The family has one time zone (Settings → Family, defaulting from the first
  parent's browser at signup, else Mountain). It decides what "today" is for
  both parents.

## Learner data (Decided — applies to every feature)

The bar is high. When in doubt, don't collect it and ask.

- Collect or keep a learner field only if a feature cannot work without it,
  or the parent explicitly provides it after we ask for a stated purpose.
  Record the justification for any optional field.
- Learner data never goes to marketing, analytics, or email tools (Loops gets
  parent plan status only), and never to any third party unless a feature
  requires it.
- AI features may send learner data to an AI provider only while the
  family's AI help is on (on by default for Premium; Cove explains what's sent
  the first time, and any parent can turn it off in Settings → Family), and
  only to a provider that doesn't train on it and keeps it for the shortest
  period it offers. Learner names are replaced with
  placeholders before anything is sent.
- Deleting a learner removes their data.
- Learner data never appears in logs or error reports.

## AI behavior (Decided, not built)

Cove is proactive — it suggests next steps, drafts school plans, handles
paperwork — but the parent decides. Without asking, Cove may take an action
only if it is **visible, undoable in one step, affects only the parent's own
view or drafts, and doesn't contact anyone, spend money, delete anything, or
share data.** Suggestions, drafts, and reminders qualify. Anything else —
e.g. moving schedule blocks — needs the parent's approval. Rules the parent
set in advance (for example, what happens when planned work doesn't get done)
are the parent's decisions, not Cove's. Applying one doesn't need approval
again, as long as Cove shows each change and it undoes in one step.

AI is woven through Cove. It makes most features better, and some features
exist only with it. AI is used only where code can't give the same result. The
floor: a family without AI (on Free, or during an outage) can still plan, run,
and record school.

## Billing (Built)

- **Both parents receive receipts.**
- Canceling stops the next renewal; Premium lasts until the paid period ends —
  except canceling while `past_due` or `unpaid` ends Premium immediately.
  This is intended, and the cancel page says so.
- **Yearly → monthly** takes effect at renewal, with no proration or credit.
- **No refunds**, stated on pricing, checkout, cancel confirmation, and family
  deletion. One-off refunds are done by hand in Stripe.
- Deleting a family ends its subscription immediately, no refund.
- **`past_due` keeps Premium** while Stripe retries. Free once `unpaid` or
  canceled.

## Complimentary Premium for testers (Built)

- A superadmin on/off switch on the family, plus a note. No end date, no
  Stripe records.
- A comped family can still subscribe; a paid subscription takes precedence.

## Email and notifications

- Lifecycle and marketing email goes only to marketing-opted-in parents. (Built)
- Plan status syncs to Loops as contact property **`planStatus`**: `free`,
  `premium`, or `complimentary` — only for opted-in parents, only in
  production, to every opted-in parent in the family. This is the sole
  exception to not syncing plan information to Loops. (Built)
- Reminders, including the day's schedule by email or in-app, are **opt-in**.
  Never guilt-based, never about inactivity. (Decided, not built)
- Cove never emails or messages learners.
