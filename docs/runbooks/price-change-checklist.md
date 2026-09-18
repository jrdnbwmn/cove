# Runbook: Price change checklist

Plan rows are never deleted or re-priced. A price change is a new Stripe Price
plus a new Plan row, with the old row hidden. Do all steps in one sitting.

## Checklist

1. **Confirm the Stripe account.** Compare the account ID embedded in the
   publishable key (`pk_test_51<account_id>...`) with the account you have open
   in the Stripe dashboard or CLI. "Test mode" and "sandbox" can be different
   accounts; don't assume they match.
2. **Create a new Price** on the existing "Premium" product in Stripe. Don't
   create a new product.
3. **Create a new Plan row** at `/admin/plans` with:
   - the **same `name`** as the old row (e.g. "Premium"),
   - the new amount and interval,
   - the new Stripe price ID,
   - `trial_period_days` set to `0`.
4. **Hide the old row** at `/admin/plans` in the same sitting.
   - Never delete it. Subscriptions reference it, and the delete guard on
     `Plan` refuses deletion when a plan has subscribers.
   - Never edit its `amount` or `stripe_id`. Existing subscribers are still on
     that price.
5. **Decide whether to move existing subscribers** to the new price. Leaving
   them on the old price is fine; moving them is a separate, deliberate step
   in Stripe.
6. **Verify `/pricing`** shows exactly one card per interval (one monthly, one
   yearly), and that each links to a working checkout.

## Local checkout

To test checkout locally, create a Price in the Stripe sandbox, then paste its
price ID into your local plan's Stripe ID field at `/admin/plans`.

## Live mode

Live-mode steps are tracked in COV-78.
