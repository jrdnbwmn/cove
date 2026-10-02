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

- Empty states explain what belongs there and give one clear next action.
- Errors say what failed when known, suggest the next step, and preserve
  entered work.
- Loading states only where data loads separately from the page; use plain
  status language, no "magic" or distracting animation.
- Treat inactivity and interruptions as normal. Offer recovery paths:
  continue, reschedule, simplify, pause, archive, or revise.
- Destructive or sensitive actions name the item, explain the consequence,
  and use specific labels ("Delete subject").
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

- WCAG AA plus standard accessibility basics; never color alone for meaning.
- Explain what sensitive information is collected and why (student data rule:
  `product-brief.md`). Sharing is opt-in. Privacy, export, deletion, and
  account controls are easy to find.
