# UX Notes

How Cove should look, sound, and behave. Read before writing any user-facing
text or screen state. Use the glossary terms in `AGENTS.md`.

## Priorities

When choices compete, in this order:

1. Privacy, safety, accessibility, and family trust
2. Clarity and ease of use
3. User agency and emotional safety
4. Practical usefulness
5. Consistency
6. Delight

Tiebreaker: prefer the option that reduces cognitive load, preserves
flexibility, and makes the next helpful action obvious.

Homeschooling is personal and variable. Changed plans, interrupted weeks,
uneven progress, and hard days are normal — not failures. Success doesn't
mean perfect consistency, high output, or matching another family's approach.

## Feel

- Calm, warm, grounded, unhurried — "there's time" energy.
- Capable, practical, clear, candid, trustworthy.
- Polished through restraint, care, and consistency.
- Encouraging and delightful: "you've got this" energy, celebrates small
  wins, normalizes hard days, makes parents feel less alone — never
  patronizing.
- A peer, not an expert: Cove helps parents with their goals; it doesn't
  teach them how to homeschool or tell them what to do. Stories and
  testimonials are peers speaking to peers.
- Flexible enough for real family life; inclusive of different approaches.
- Not cutesy, "magical", corporate, clinical, or tech-bro.

## Voice and copy

- Lead with useful information or the next action.
- Short, concrete, everyday words. Active voice, contractions, lots of verbs
  and outcomes. Use "you" and "we" freely.
- No jargon or slang; explain unavoidable terms. No fluff or overly poetic
  language.
- State errors, uncertainty, and limitations plainly.
- Humor rarely and never at the user's expense; a light touch can help
  around heavy topics.
- No emoji. No exclamation points.
- Celebrate meaningful progress (a finished week, unit, or milestone) warmly
  and briefly. Routine actions get plain confirmation.
- Prefer flexible words: "next step," "adjust," "move," "pause,"
  "continue," "simplify." Avoid "failed," "behind," "missed goal," or "quit"
  unless essential and accurate to the user's own choice.

| Context | Prefer | Avoid |
| --- | --- | --- |
| Empty state | "Nothing here yet. Add your first subject when you're ready." | "Let's get started!" |
| Validation | "Choose a date to continue." | "Oops! You forgot a date!" |
| Error | "We couldn't save that. Check your connection and try again." | "Something went wrong." |
| Saved | "Saved." | "Amazing! You crushed it!" |
| Missed plan | "This didn't happen today. Move it, simplify it, or leave it here." | "You missed your goal." |
| Privacy | "This stays private unless you choose to share it." | "Trust us—we take privacy seriously." |

## States and interactions

- Empty states explain what belongs there and give one next action. "No
  results for this filter" is a separate state that offers to clear it.
- Plan limits and plan-locked content (Premium-only, read-only after a
  downgrade): a calm inline banner at the top of the content with the next
  step, never a modal that pops up on its own. Show limit banners only at or
  near the limit. At the limit, the Add button stays and opens a modal
  explaining the limit, with a button to the billing page (Premium at its
  cap: "Contact us").
- Errors say what failed when known, suggest the next step, preserve entered
  work, and appear inline next to the problem, never only in a toast.
- Routine confirmations: a toast ("Saved.").
- Loading states only where data loads separately from the page: gray shapes
  matching the coming layout, with a gentle shimmer. No other loading motion.
- Treat inactivity and interruptions as normal. Offer recovery paths:
  continue, reschedule, simplify, pause, archive, or revise.
- Destructive or sensitive actions name the item, explain the consequence,
  and use specific labels ("Delete subject"). They live at the bottom of
  record and settings pages, never in the page header.
- Phone and desktop are equal: every flow works fully on both. Common tasks
  fit short, interrupted moments.

## Page structure (signed-in app)

Principles:

- You always know where you are: one level of depth at most, so no
  breadcrumbs.
- Each page has one clear job. More scope means tabs; more header actions
  than the limit means the page does too much.
- The frame stays still: same width, title position, and header on every
  page. Only content changes.
- One primary action per view.
- Overlays are for tasks; pages are for places.
- Every rule states its phone behavior.

Depth and width:

- Section pages (Learners) may link to record pages (one learner). Nothing
  deeper; extra scope becomes tabs (Settings is the model).
- Record pages: a "← Learners" link to the section (which stays highlighted in
  the sidebar), header, summary, sections or tabs, then the destructive area.
  Add a switcher on the title only where people go record to record
  (learners). Editing details opens a modal.
- All page content shares one container width. Narrower content (forms,
  prose) left-aligns with the title, never centered.

Header:

- Title top-left; optional one-line description below. No other text (plan
  limits, counts, status notes go in the content).
- Actions right of the title, aligned with the title line, and apply to the
  whole page: one primary (rightmost, usually "Add …"), at most two
  secondary, the rest in a "…" menu. Tab-specific actions go inside the tab.
- Phones: actions wrap to a row under the title; the primary keeps its
  label, secondaries move into "…". No floating action buttons.

Where things open:

- Modal: every create/edit form and decision, short or long; long forms
  scroll inside. No drawers or slide-overs. Phones: full-height sheet.
- Focused full page (no sidebar): multi-step flows (onboarding, checkout).
- Never open a modal on top of another modal, confirmations included. A
  decision that comes up inside a modal happens in that same modal.
- Closing a modal with unsaved changes asks before discarding.
- After creating, go to the new record page; with none, stay on the list
  with a toast.

Spacing: everything on a 4px grid (sizes, spacing, line heights); 2px half
steps only inside small elements (badges, icon nudges).

- Header to content: 32px (phones 24px).
- Between major sections: 48px (phones 32px).
- Section heading to content: 16px. Between cards or items: 16px. Row
  padding: 12–16px with dividers. Between form fields: 24px.

Sections and tabs:

- A section is a heading plus content, separated by space. No cards inside
  cards.
- Serif only for page titles and major section headings; everything else is
  sans.
- Tabs switch views of a page, never list items. Each has its own URL, about
  five at most, scrolling sideways on phones. A list's Active/Archived switch
  uses underline tabs with counts; other filters use a filter control.

Forms:

- Single column, labels above fields, help text inline (never tooltips).
- Always an explicit Save. Buttons bottom right, primary rightmost; on phones,
  full width and stacked, primary on top.

Lists:

- Cards when each item is its own thing (learners, subjects, school plans,
  billing plan options). Rows when people scan or compare same-shaped records
  (charges, activity, parents). Bordered boxes with identical fields are rows.
- No tables. Rows may align columns on desktop; they stack on phones.
- Past 12 items: rows, plus search and pagination together.
- Toolbar at the top of the list: search, filters, sort, Active/Archived
  (where archived items live). Adding goes here instead of the header only
  when the list isn't the page's main subject.
- Clicking an item opens it; per-item actions go in a "…" menu. Nothing
  hover-only.
- Multi-select: "Select" in the toolbar shows checkboxes; a bar shows the
  count and actions. Bulk destructive actions confirm with the count
  ("Archive 3 learners").
- Icons wherever they aid scanning. Icon-only buttons only when the meaning
  is obvious, always with an accessible label.
- Status badges use restrained color; color never carries meaning alone.

Formats, written as a person would:

- Dates: 9 Sep 2025; 9 Sep in the current year; Today, Tomorrow, or
  Yesterday when clearer.
- Ranges: 9–12 Sep 2025, 30 Sep–2 Oct 2025, 28 Dec 2025–3 Jan 2026.
- Times: 5:07pm, always with minutes (5:00pm).

Dashboard: answers "what should I do right now, today?" — today's plan and
the next step, not a summary of everything.

## Never add unless explicitly asked

Streaks, gamification, social comparison, artificial urgency or scarcity,
guilt or inactivity nudges ("You haven't logged in lately"), notifications
or engagement prompts, decorative motion. Never: confusing privacy choices,
default sharing, or hidden cancellation, deletion, export, or account
controls. When a request conflicts with this doc, name the conflict and
propose a calmer, clearer alternative.

## Visual, accessibility, and privacy

Polished means deliberate spacing, readable type, clear hierarchy, restrained
color, consistent components, and handled edge cases — not low contrast,
dense dashboards, tiny controls, hidden actions, heavy animation, or
decoration without purpose.

- Explain what sensitive information is collected and why (learner data rule:
  `product-brief.md`). Sharing is opt-in. Privacy, export, deletion, and
  account controls are easy to find.
