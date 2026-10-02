# UX Notes

This document guides UX design decisions for this app.

## Core principles

Prioritize decisions in this order:

1. Privacy, safety, accessibility, and family trust
2. Clarity and ease of use
3. User agency and emotional safety
4. Practical usefulness
5. Consistency
6. Delight

When choices compete, prefer the option that reduces cognitive load, preserves flexibility, and makes the next helpful action obvious.

The product should feel:

- Calm, warm, grounded, and unhurried
- Capable, practical, clear, and trustworthy
- Premium through restraint, polish, and consistency
- Supportive without being performative
- Flexible enough for real family life

Homeschooling is personal and variable. Changing plans, interrupted weeks, uneven progress, and difficult days are normal—not failures.

## Avoid

Do not make the app feel:

- Cutesy, cheesy, overly playful, or “magical”
- Corporate, clinical, cold, or bureaucratic
- Like a tech-bro startup, productivity contest, or growth funnel
- Pushy, urgent, guilt-inducing, or fear-based
- Preachy, haughty, overly instructional, or condescending
- Dense, visually noisy, stiff, or unnecessarily complex

Avoid dark patterns:

- Artificial urgency, scarcity, or FOMO
- Streak-loss pressure
- Shame around missed plans, incomplete work, or inactivity
- Social comparison by default
- Confusing privacy choices or default sharing
- Hidden cancellation, deletion, export, or account controls
- Manipulative notifications or engagement prompts

Do not imply that homeschool success means perfect consistency, high output, or matching another family’s approach.

## Voice and copy

Write like a thoughtful, capable peer: natural, direct, warm, candid, and respectful. The app helps families make choices; it does not lecture them about how to homeschool.

- Lead with useful information or the next action.
- Prefer short, concrete, everyday language.
- Use active voice and contractions naturally.
- Use “you” and “we” when they improve clarity. Use “we” only when the product is taking action with or for the user.
- Prefer familiar words over jargon; explain unavoidable terms.
- State errors, uncertainty, and limitations plainly.
- Use humor sparingly and never at the user’s expense.
- Avoid emojis and exclamation points.
- Do not over-celebrate routine actions.

Prefer flexible, non-evaluative language: “plan,” “rhythm,” “next step,” “adjust,” “move,” “pause,” “continue,” and “simplify.” Avoid language such as “failed,” “behind,” “missed goal,” or “quit” unless it is essential and accurately reflects the user’s choice.

| Context | Prefer | Avoid |
| --- | --- | --- |
| Empty state | “Nothing here yet. Add your first subject when you’re ready.” | “Let’s get started!” |
| Validation | “Choose a date to continue.” | “Oops! You forgot a date!” |
| Error | “We couldn’t save that. Check your connection and try again.” | “Something went wrong.” |
| Saved | “Saved.” | “Amazing! You crushed it!” |
| Missed plan | “This didn’t happen today. Move it, simplify it, or leave it here.” | “You missed your goal.” |
| Privacy | “This stays private unless you choose to share it.” | “Trust us—we take privacy seriously.” |

## States and interactions

- Empty states explain what belongs there and provide one clear next action.
- Errors say what failed when known, suggest the next step, and preserve entered work whenever possible.
- Loading states use direct status language; avoid “magic,” fake reassurance, and distracting animation.
- Confirm success clearly. Celebrate meaningful milestones lightly, not every checkbox or save.
- Treat inactivity and interruptions as normal. Offer recovery paths: continue, reschedule, simplify, pause, archive, or revise.
- For destructive or sensitive actions, name the item, explain the consequence, and use specific labels such as “Delete subject.”
- Prefer one clear primary action per screen. Keep secondary actions available but visually quieter.
- Use familiar controls, stable navigation, progressive disclosure, and predictable behavior.
- Avoid auto-advancing, surprise navigation, unnecessary confirmation dialogs, and sudden layout shifts.
- Make common tasks easy to complete in short, interrupted moments.

## Visual, accessibility, and trust

Premium means deliberate spacing, readable typography, clear hierarchy, restrained color, consistent components, and polished edge cases. It does **not** mean low contrast, dense dashboards, tiny controls, hidden actions, excessive animation, or decorative effects without purpose.

- Meet WCAG AA contrast requirements.
- Support keyboard navigation, visible focus states, semantic HTML, accessible labels, usable touch targets, and reduced-motion preferences.
- Do not rely on color alone to communicate meaning.
- Design for different schedules, family structures, abilities, learning needs, technical confidence, time, attention, energy, and definitions of success.
- Explain what sensitive information is collected and why.
- Make sharing opt-in whenever possible.
- Make privacy, export, deletion, and account controls easy to find and understand.

## AI implementation rules

When building with AI, reuse established components and terminology. Include meaningful empty, loading, error, validation, disabled, and success states. Preserve accessibility and user input during errors. Do not add streaks, gamification, social comparison, pressure tactics, notifications, celebrations, or motion unless explicitly requested. When a request conflicts with this document, identify the conflict and propose a calmer, clearer alternative.

## Overall feel

Avoid:

- Cutesy
- Tech bro startup
- Corporate
- FOMO, pressure tactics, pushy, guilt-inducing
- Haughty, condescending, snobbish, pretentious, cocky
- Stiffness
- "I need to teach you how to do this." (it's an assistant that helps you with your goals, not tells you what to do)
- Judgemental
- Cheesy
- Dark patterns

Make it feel:

- Premium
- Trustworthy
- Capable
- Useful
- Supportive
- Calm
- Warm
- Optimistic
- Clear-headed
- Inviting
- Friendly
- Confident
- Reassuring: "You've got this" energy without being patronizing
- Clear
- Encouraging: Celebrates small wins, normalizes struggles
- Grounded: Steady, unflappable, centered
- Unhurried: "There's time" energy
- Validating, normalizing experiences, less lonely
- Candid
- Safety-first. Clear, explicit privacy language around sensitive data.
- Simple
- Practical
- Small wins, approachable
- Mindfulness
- Inclusive
- Delightful
- Satisfying

## Brand voice & tone

Refer to the "Overall feel" section above.

Avoid:

- Jargon
- Slang
- Urgency language
- Fluff
- Clinical
- Exclamation points (sparingly, if ever)
- "Oops!" or overly cute error language
- Guilt-inducing phrases ("You haven't logged in lately!")
- Emojis
- Dryness: Anything that sounds like a textbook
- Overly poetic language

Make it feel:

- Natural, conversational. Everyday, casual phrasing.
- Okay to use "you" and "we" liberally.
- Straightforward, economy of words
- Stories and testimonials are framed as peers speaking to peers, not experts lecturing users
- Humor/lightness can pop up around heavy topics
- Lots of verbs and outcomes

Other tips:

- Think carefully about terminology (e.g. may "routine" or "rhythm" instead of "calendar")

| Context | Example |
| --- | --- |
| **Empty state** | "Nothing here yet. Ready to add your first subject?" |
| **Error** | "That didn't work. Let's try again." |
| **Confirmation** | "Saved. You're all set." |
| **Loading** | "Pulling things together..." |

## Visual design principles

Aim for:

- Breathing room, space
- Consistency
- High polish and quality
- Clarity

Always use variables, components, etc. before hard-coding things.
