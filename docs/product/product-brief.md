# Product Brief

How Cove behaves for users, and why. Code-level invariants and the glossary
live in `AGENTS.md` and aren't repeated here.

Each section is marked **Built** or **Decided, not built**.

## Free vs Premium (Built)

| | Free | Premium |
|---|---|---|
| Learners | 2 | Advertised as unlimited; real cap is `learner_limit` (default 10, raisable per family by a superadmin) |
| Parents | Up to 2 | Up to 2 |

- Pricing is flat per family. No per-learner fee; Stripe quantity and pricing
  structure never change with learner count.
- No trial — Free serves that purpose.
- Which future features are Premium is decided per feature. Don't decide
  Premium gating for a new feature; ask.

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

## Learners (Built — `/learners`)

- Learner logins are a future version.
- Families above Premium's `learner_limit` contact support. The cap keeps
  co-ops and micro-schools off a family plan.
- Only active learners count toward a family's limit. Creating or restoring a
  learner uses a slot; archived learners do not. Free includes two learners
  and sees an upgrade prompt at the limit; Premium uses its configured cap and
  sees "Contact us" at that limit.
- Parents can archive learners to keep their records or delete them permanently.
  Restore remains unavailable while it would exceed the applicable limit.
- **On downgrade:**
  - No learner is ever deleted.
  - A calm banner on `/learners` says something like "Premium ended. Choose
    which 2 learners stay editable." Until the parent chooses, all learners
    are read-only. Nothing else is blocked.
  - The parent can change the pick at any time; swapping makes the previously
    editable learner read-only.
  - Re-subscribing makes every learner editable again.
  - Read-only learners still appear on schedule blocks they're already
    assigned to, but future features must not allow new subjects, schedule
    blocks, or other records to be assigned to them.

## Learner data (Decided — applies to every feature)

The bar is high. When in doubt, don't collect it and ask.

- Collect or keep a learner field only if a feature cannot work without it,
  or the parent explicitly provides it after we ask for a stated purpose.
  Record the justification for any optional field.
- Learner data never goes to marketing, analytics, or email tools (Loops gets
  parent plan status only), and never to any third party unless a feature
  requires it.
- AI features may send learner data to an AI provider only for a feature the
  parent turned on, and only to a provider that doesn't train on or keep it.
- Deleting a learner removes their data.
- Learner data never appears in logs or error reports.

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

- Lifecycle and marketing email goes only to marketing-opted-in parents. (Built)
- Plan status syncs to Loops as contact property **`planStatus`**: `free`,
  `premium`, or `complimentary` — only for opted-in parents, only in
  production, to every opted-in parent in the family. This is the sole
  exception to not syncing plan information to Loops. (Built)
- Reminders, including the day's schedule by email or in-app, are **opt-in**.
  Never guilt-based, never about inactivity. (Decided, not built)
- Cove never emails or messages learners.

## Open questions

- Learner logins: under-13 learners bring COPPA obligations. No position yet.
