# Product Brief

This document outlines key rules about this product that are important to understand while building.

## Free vs Premium

Premium means paid Premium or Complimentary Premium (see Testers). Gate
features on the plan, never on a price or plan name.

| | Free | Premium |
|---|---|---|
| Students | 2 (planned; the app still allows 1) | 10 by default, raisable per family |
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
- Free limit **2** (planned; the app still enforces 1); Premium limit **10** by default, raisable per family by
  a superadmin. The cap exists to stop co-ops and micro-schools using a
  family plan.
- Past the limit: Free sees an upgrade prompt, Premium sees "Contact us".
- **On downgrade no students are deleted.** The parent picks which stay
  editable; the rest go read-only until the family upgrades. Read-only
  students still appear on calendar events they're already assigned to.

## Billing behavior

- Billing is flat per family. **Both parents receive receipts.**
- Canceling stops the next renewal; Premium lasts until the paid period
  ends.
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

- **Yearly → monthly switch mid-year** — Stripe prorates by default;
  behavior not yet decided.
- **Terms of Service and refund policy pages** — required before Stripe
  live activation.
- **Downgraded families** — what they see before picking which students
  stay editable, and whether that pick can change later. Belongs to the
  Students feature design.
