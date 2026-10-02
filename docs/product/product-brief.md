# Product Brief

This document outlines key rules about this product that are important to understand while building.

## Free vs Premium

Premium means paid Premium or Complimentary Premium (see Testers). Gate
features on the plan, never on a price or plan name.

| | Free | Premium |
|---|---|---|
| Students | 2 | Unlimited (advertised); 10-student cap, raisable per family |
| Parents | Two | Two |

## Families

- One family account holds **one or two parents** plus their students.
- **Both parents are admins**; one is the owner.
- Owner-only: deleting the family, transferring ownership. Admins do
  everything else, **including billing**.
- The subscription belongs to the family and survives a parent leaving.
- **One person belongs to exactly one family.** No account switching, no
  second families.
- An existing user may accept another family's invite **only if their own
  family is empty** (no students, active subscription, or other members).
  That empty family is then archived, not deleted, so its billing history
  is kept. An active subscription must be canceled first; students or
  another parent mean the invite is refused with "contact support".
- The owner **must transfer ownership before deleting their login** if
  another parent is in the family. A non-owner parent deleting their login
  just leaves.

## Students

- Students are **data records owned by the family**, not logins or members.
  Students will eventually have their own logins (in a future version).
- Free limit is **2**. Premium is advertised as **unlimited**, but its real
  cap is `student_limit` (default 10, raisable per family by a superadmin).
  Families above the cap contact support; the cap keeps co-ops and
  micro-schools from using a family plan.
- There is **no per-student fee**, no Stripe quantity or pricing-structure
  change, and pricing stays flat per family.
- Past the limit: Free sees an upgrade prompt, Premium sees "Contact us".
- **On downgrade** (built in the Students ticket):
  - No student is ever deleted.
  - A calm banner on `/students` says something like "Premium ended. Choose
    which 2 students stay editable." Until the parent chooses, all students
    are read-only. Nothing else is blocked.
  - The parent can change the pick at any time; swapping makes the previously
    editable student read-only.
  - Re-subscribing makes every student editable again.
  - Read-only students still appear on calendar events they're already
    assigned to.

## Billing behavior

- Billing is flat per family. **Both parents receive receipts.**
- Canceling stops the next renewal; Premium lasts until the paid period
  ends — except canceling while `past_due` or `unpaid` ends Premium
  immediately because `CancelsController` calls `cancel_now!`. This is
  intended, and the cancel page says so.
- **Yearly → monthly** takes effect at renewal, with no proration or credit
  (built in the "Yearly → monthly takes effect at renewal" ticket).
- **No refunds**, stated on pricing, checkout, cancel confirmation, and
  family deletion. One-off refunds are done by hand in Stripe.
- Deleting a family ends its subscription immediately, no refund.
- **`past_due` keeps Premium** while Stripe retries. Free once `unpaid` or
  canceled.

## Testers

- **Complimentary Premium** is a superadmin on/off switch on the family,
  plus a note. No end date, no Stripe records.
- A comped family can still subscribe; a paid subscription takes
  precedence.

## Loops

- Plan status syncs to Loops as contact property **`planStatus`**: `free`,
  `premium`, or `complimentary`.
- **Only for marketing-opted-in users, and only in production.** Every
  opted-in parent in a family gets it.
- This is the sole exception to the rule of not syncing plan information to
  Loops.

## Open questions

- **Terms, Privacy, and Refund Policy pages** — drafted and implemented at `/terms`,
  `/privacy`, `/refunds` (COV-92); not lawyer-reviewed. Still to do by hand
  before Stripe live activation: in the Stripe Dashboard (Settings → Public
  details) set the Terms, Privacy, and Refund policy URLs; in the Google Cloud
  Console OAuth consent screen set the homepage/privacy/terms links and
  authorized domain, then submit for brand verification. Revisit the copy when
  student logins ship, AI launches, the LLC forms, or analytics is added.
