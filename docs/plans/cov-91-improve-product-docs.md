> Ticket: COV-91
> Branch: chore/cov-91-improve-product-docs

# Plan: Improve product docs (COV-91)

## Status

| Task | Phase | Checkpoint | Description | Assign | Done |
| ---- | ----- | ---------- | ----------- | ------ | ---- |
| 1    | 1     | 1          | Rewrite `docs/product/product-brief.md`; move launch to-dos to a runbook | Master |      |
| 2    | 1     | 1          | Rewrite `docs/product/strategy-brief.md` | Clone  |      |
| 3    | 1     | 1          | Rewrite `docs/product/ux-notes.md` | Clone  |      |
| 4    | 1     | 2          | Update `AGENTS.md`: glossary + product-doc pointers | Master |      |

## Prerequisites

- Design: None — all decisions were approved in conversation and are written
  verbatim below. **Do not add, reword, or invent product decisions.** If
  something seems missing, ask.
- Prototype: None
- Branch `chore/cov-91-improve-product-docs` exists.
- Docs-only change (no behavior change), so no tests. Each task verifies with
  grep/word counts.

## Tasks

### Task 1 [Master]: Rewrite product-brief.md; move launch to-dos

**Reference:** current `docs/product/product-brief.md` (every rule must
survive unless this task says to move or drop it)

**In scope:**

- Replace `docs/product/product-brief.md` with the content below.
- Create `docs/runbooks/launch-checklist.md` with the Stripe/Google OAuth
  to-dos from the old "Open questions" section (content below).

**NOT in scope:**

- Code-level invariants that stay in `AGENTS.md` (Account = Family, quantity
  unchanged on parent changes, no family switching, gate on `premium?`,
  price-change process). Don't copy them here.

**Content for `docs/product/product-brief.md`:**

```markdown
# Product Brief

How Cove behaves for users, and why. Code-level invariants and the glossary
live in `AGENTS.md` and aren't repeated here.

Each section is marked **Built** or **Decided, not built**.

## Free vs Premium (Built)

| | Free | Premium |
|---|---|---|
| Students | 2 | Advertised as unlimited; real cap is `student_limit` (default 10, raisable per family by a superadmin) |
| Parents | Up to 2 | Up to 2 |

- Premium means paid Premium or Complimentary Premium.
- Pricing is flat per family. No per-student fee; Stripe quantity and pricing
  structure never change with student count.
- No trial — Free serves that purpose.

## Families (Built)

- A family holds **one or two parents** plus its students. **Both parents
  are admins**; one is the owner.
- Owner-only: deleting the family, transferring ownership. Admins do
  everything else, **including billing**.
- The subscription belongs to the family and survives a parent leaving.
- **One person belongs to exactly one family.** No second families.
- An existing user may accept another family's invite **only if their own
  family is empty** (no students, renewing subscription, or other members).
  That empty family is archived, not deleted, so its billing history is kept.
  A subscription must be canceled first; a canceled subscription still in its
  paid period doesn't block joining. Students or another parent mean the
  invite is refused with "contact support".
- The owner **must transfer ownership before deleting their login** if
  another parent is in the family. A non-owner parent deleting their login
  just leaves.

## Students (Decided, not built — `/students` is a placeholder)

- Students are **records owned by the family**, not logins or members.
  Student logins are a future version.
- Free limit is **2**. Premium's real cap is `student_limit`; families above
  it contact support. The cap keeps co-ops and micro-schools off a family plan.
- Past the limit: Free sees an upgrade prompt, Premium sees "Contact us".
- **On downgrade:**
  - No student is ever deleted.
  - A calm banner on `/students` says something like "Premium ended. Choose
    which 2 students stay editable." Until the parent chooses, all students
    are read-only. Nothing else is blocked.
  - The parent can change the pick at any time; swapping makes the previously
    editable student read-only.
  - Re-subscribing makes every student editable again.
  - Read-only students still appear on schedule blocks they're already
    assigned to.

## Student data (Decided — applies to every feature)

The bar is high. When in doubt, don't collect it and ask.

- Collect or keep a student field only if a feature cannot work without it,
  or the parent explicitly provides it after we ask for a stated purpose.
  Record the justification for any optional field.
- Student data never goes to marketing, analytics, or email tools (Loops gets
  parent plan status only), and never to any third party unless a feature
  requires it.
- AI features may send student data to an AI provider only for a feature the
  parent turned on, and only to a provider that doesn't train on or keep it.
- Deleting a student removes their data.
- Student data never appears in logs or error reports.

## AI behavior (Decided, not built)

AI is proactive — it suggests next steps, drafts school plans, handles
paperwork — but the parent decides. Without asking, AI may take an action
only if it is **visible, undoable in one step, affects only the parent's own
view or drafts, and doesn't contact anyone, spend money, delete anything, or
share data.** Suggestions, drafts, and reminders qualify. Anything else —
e.g. moving schedule blocks — needs the parent's approval. Every AI feature
has a non-AI path, so a parent who never uses AI still gets a complete product.

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

- Transactional email (receipts, invites, account events) is always allowed. (Built)
- Lifecycle and marketing email goes only to marketing-opted-in parents. (Built)
- Plan status syncs to Loops as contact property **`planStatus`**: `free`,
  `premium`, or `complimentary` — only for opted-in parents, only in
  production, to every opted-in parent in the family. This is the sole
  exception to not syncing plan information to Loops. (Built)
- Reminders, including the day's schedule by email or in-app, are **opt-in**.
  Never guilt-based, never about inactivity. (Decided, not built)
- Cove never emails or messages students.

## Open questions

- Which future features are Premium — decided per feature as they're built.
- Student logins: under-13 students bring COPPA obligations. No position yet.
- Terms, Privacy, and Refund pages (`/terms`, `/privacy`, `/refunds`) are not
  lawyer-reviewed. Revisit the copy when student logins ship, AI launches,
  the LLC forms, or analytics is added. Launch to-dos:
  `docs/runbooks/launch-checklist.md`.
```

**Content for `docs/runbooks/launch-checklist.md`:**

```markdown
# Launch Checklist

Manual steps before Stripe live activation.

- [ ] Stripe Dashboard → Settings → Public details: set the Terms, Privacy,
      and Refund policy URLs (`/terms`, `/privacy`, `/refunds`).
- [ ] Google Cloud Console → OAuth consent screen: set the homepage, privacy,
      and terms links and the authorized domain, then submit for brand
      verification.
```

**Verify:**

1. `grep -n "calendar\|cancel_now\|CancelsController" docs/product/product-brief.md` → no matches.
2. Diff against `git show HEAD:docs/product/product-brief.md`; confirm every
   old rule is present in the new file, `AGENTS.md`, or the runbook. List any
   that aren't and ask.

### Task 2 [Clone]: Rewrite strategy-brief.md

**In scope:** Replace `docs/product/strategy-brief.md` with the content below.

**NOT in scope:** Voice/feel language (ux-notes), AI action rules
(product-brief), any "Next", "Not doing", or "Unique advantages" section —
deliberately omitted.

```markdown
# Strategy Brief

Who Cove is for, the problem it solves, and how it's positioned. Use it to
check whether a feature fits the user and the positioning. Behavior rules:
`product-brief.md`. Voice and UX: `ux-notes.md`.

## Main idea

Cove is a chief of staff for homeschool families. It reduces the planning,
administrative work, and anxiety of homeschooling. Like a real chief of
staff, it prepares options, recommends a path, handles logistics, and follows
up — but leaves decisions to the parent (limits: `product-brief.md` → AI
behavior).

After using Cove, running a homeschool should feel much lighter and more
effective: more time, less anxiety, nothing important missed, and more focus
on what only the parent can do.

**Value proposition:** For US homeschooling parents who must plan, run, and
document their family's homeschool, Cove is a homeschool chief of staff that
prepares school plans, daily schedules, and records so the parent can focus on
deciding and teaching. Unlike spreadsheets, paper planners, and
general-purpose apps, Cove adapts to the family's approach and takes on the
admin work, in a calm, polished app.

- **Primary value:** Running a homeschool takes less time and less worry —
  the parent knows what to do today, and nothing important slips.
- **Secondary benefits:** school plans that recover when life interrupts;
  records and state requirements kept as a by-product of daily use; help
  choosing curriculum; one place instead of scattered tools.

## Target user

US homeschooling families, K–12, at any level of homeschooling experience.

- **Design for the parent who buys** — the household's curriculum researcher,
  lesson planner, and day-to-day teacher. They want an easier way to choose
  curriculum, build and adjust school plans, track progress, and meet state
  requirements, without juggling disconnected tools or spending hours on admin.
- **Families only — not co-ops, micro-schools, or other schools.** The Premium
  student cap enforces this.

## Pain points (long-term vision, not current scope)

- **Choosing curriculum is overwhelming.** Cove would help parents research,
  compare, and choose materials — or build their own curriculum.
- **Building a cohesive school plan takes too much work.** Cove would combine
  curricula, homemade lessons, and extracurriculars into one school plan,
  using AI to streamline planning.
- **Plans fall apart when real life intervenes.** Cove would help parents
  adjust schedules and reschedule unfinished work.
- **Running each school day is hard to coordinate.** Cove would provide daily
  schedules, printable schedules, and completion checklists.
- **Tracking learning creates an administrative burden.** Cove would organize
  homework, attendance, grades, and progress in one place.
- **State requirements and college documentation are confusing.** Cove would
  help parents understand requirements, track compliance, and prepare records
  and transcripts.

## Positioning

Most families run their homeschool on spreadsheets, paper planners, and
general-purpose apps. Cove differs by:

- **Design quality is the product.** Every screen should feel polished, calm,
  clear, and obvious to a stressed parent.
- **AI prepares, the parent decides.** AI drafts school plans, suggests next
  steps, and handles paperwork within strict limits; every AI feature has a
  non-AI path.
- **Works across homeschooling approaches** — traditional, Charlotte Mason,
  classical, unschooling, eclectic, etc. Cove adapts to the family's approach
  instead of assuming one model.
- **Built from real homeschool problems.** Features start from a specific
  problem parents have ("what do I do today?", "am I meeting my state's
  requirements?"), not from what other tools include.

## Success

**Hypothesis:** If we take planning, rescheduling, and record-keeping off the
parent's plate, parents will run their homeschool day from Cove instead of
spreadsheets and paper, leading to steady weekly use and Premium conversion
and retention.

**Success — what users can do:**

- See what to do today in under a minute.
- Adjust the school plan when a day or week goes off-track, instead of
  abandoning it.
- Have the records state requirements call for without separate tracking.
- Stop keeping a parallel spreadsheet or paper planner.

**Failure signals:** parents keep their old system alongside Cove; usage stops
after the first disrupted week; parents report feeling behind or judged; AI
suggestions are routinely ignored or undone.

**Business metric:** Free → Premium conversion. Target (hypothesis, revisit
after ~100 families): 5% of new Free families upgrade to paid Premium within
90 days of signup; stretch 8%. Excludes Complimentary families.

## Business model

Two tiers on the family: **Free** (no subscription) and **Premium**. Flat
price per family, not per student; current prices on `/pricing`. Limits and
billing rules: `product-brief.md`.

- **Free** covers limited use for small families.
- **Premium** adds automation, AI, and other useful features.
```

**Verify:** `grep -n "\[\|What is our\|How will we\|notion" docs/product/strategy-brief.md` → no matches (no template placeholders or Notion link remain).

### Task 3 [Clone]: Rewrite ux-notes.md

**In scope:** Replace `docs/product/ux-notes.md` with the content below.

**NOT in scope:** Component/token rules (owned by the global `style-ui`
skill); the deleted second example table.

```markdown
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
  teach them how to homeschool or tell them what to do.
- Flexible enough for real family life; inclusive of different approaches.

Not: cutesy, cheesy, or "magical"; corporate, clinical, bureaucratic, or
textbook-dry; tech-bro, productivity contest, or growth funnel; pushy,
urgent, or guilt-inducing; preachy, haughty, or condescending; dense, noisy,
or stiff.

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
- Use product terms consistently: Schedule (never "calendar"), school plan,
  schedule block, family, parent, student.
- Stories and testimonials are peers speaking to peers.

| Context | Prefer | Avoid |
| --- | --- | --- |
| Empty state | "Nothing here yet. Add your first subject when you're ready." | "Let's get started!" |
| Validation | "Choose a date to continue." | "Oops! You forgot a date!" |
| Error | "We couldn't save that. Check your connection and try again." | "Something went wrong." |
| Saved | "Saved." | "Amazing! You crushed it!" |
| Missed plan | "This didn't happen today. Move it, simplify it, or leave it here." | "You missed your goal." |
| Privacy | "This stays private unless you choose to share it." | "Trust us—we take privacy seriously." |

## States and interactions

- Empty states explain what belongs there and give one clear next action.
- Errors say what failed when known, suggest the next step, and preserve
  entered work.
- Loading states only where data loads separately from the page; use plain
  status language, no "magic" or distracting animation.
- Treat inactivity and interruptions as normal. Offer recovery paths:
  continue, reschedule, simplify, pause, archive, or revise.
- Destructive or sensitive actions name the item, explain the consequence,
  and use specific labels ("Delete subject").
- One clear primary action per screen; secondary actions quieter.
- Familiar controls, stable navigation, progressive disclosure, predictable
  behavior. No auto-advancing, surprise navigation, unnecessary confirmation
  dialogs, or layout shifts.
- Phone and desktop are equally important: every flow works fully on both,
  no desktop-only features. Common tasks should be completable in short,
  interrupted moments.

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

- WCAG AA contrast. Keyboard navigation, visible focus, semantic HTML,
  accessible labels, usable touch targets, reduced-motion support. Never
  color alone for meaning.
- Design for different schedules, family structures, abilities, learning
  needs, technical confidence, time, attention, energy, and definitions of
  success.
- Explain what sensitive information is collected and why (student data rule:
  `product-brief.md`). Sharing is opt-in. Privacy, export, deletion, and
  account controls are easy to find.
```

**Verify:**

1. `grep -n -i "calendar\|premium\|Pulling things\|That didn't work\|You're all set\|liberally" docs/product/ux-notes.md` → only the "never calendar" rule matches.
2. `wc -w docs/product/*.md` → ux-notes ≤ ~750 words (was 1,173).
3. **Run review-changes-mini for Checkpoint 1 (Tasks 1–3).** If these tasks
   were executed as a parallel batch, the master runs it once after the whole
   batch returns, rather than this task running it itself.

### Task 4 [Master]: Update AGENTS.md

**In scope:** In `AGENTS.md` → "Current Project Decisions":

- Replace the bullet "Product rules (families, students, billing behavior,
  testers, Loops plan status) live in…" with:

  ```markdown
  - Product docs in `docs/product/`: `product-brief.md` — behavior rules;
    read before changing families, students, billing, plan status,
    notifications, AI behavior, or anything that stores student data.
    `ux-notes.md` — read before writing user-facing text or screen states.
    `strategy-brief.md` — who Cove is for and its positioning.
  ```

- Replace the bullet "Jumpstart's `Account` is the user-facing Family;
  `AccountUser` admins are its parents." with:

  ```markdown
  - Glossary (use these terms in UI copy and docs):
    - **Family** = `Account`. **Parent** = an `AccountUser` (all are admins);
      **Owner** = the one parent who can delete the family or transfer ownership.
    - **Student** = a record owned by the family, not a login.
    - **Premium** = the paid plan (or Complimentary Premium) — never a design
      adjective; say "polished". **Complimentary** = superadmin-granted Premium.
    - **Plan** in code = billing plan (`Plan` model). In UI copy, the
      learning plan is a **school plan**.
    - **Schedule** = the time-based view (never "calendar"); its items are
      **schedule blocks**.
  ```

**NOT in scope:** Any other `AGENTS.md` bullet; global skill files (the user
edits those).

**Verify:**

1. `git diff --stat` → only the 3 product docs, the new runbook, and `AGENTS.md`.
2. `grep -rn "product-brief\|ux-notes\|strategy-brief" AGENTS.md docs/product` → pointers resolve to existing files.
3. **Run review-changes-mini for Checkpoint 2 (Task 4).**

## Task Dependencies

- Tasks 1–3 are independent and can run in parallel.
- Task 4 runs after Tasks 1–3 (its pointers describe their final content).
