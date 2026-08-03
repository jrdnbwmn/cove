> Plan created: docs/plans/cov-42-billing-templates.md

> Ticket: COV-42
> Branch: feature/cov-42-author-publish-lmx-templates

# Feature: Billing transactional email templates

## Problem

Seven `Pay::UserMailer` actions still depend on Pay 11.6.2's vendored ERB
views. They are webhook-triggered billing messages with no human retry path, so
COV-45 cannot move Pay delivery to Loops until all seven equivalents exist,
render correctly, and are published with durable data contracts.

The receipt also carries a generated PDF to the account owner and optional
billing contact. A normal Cove billing URL is not an acceptable substitute for
that attachment because it requires authentication and scopes the charge to the
current account; a billing contact may not have a Cove account at all.

## Approach

Create seven transactional emails in the existing Cove Loops team and reuse the
shared `Cove` theme published by COV-40. Port the Pay source copy faithfully,
while improving only the email hierarchy: one H1 per message, prominent buttons
for actions, and one restrained summary section in receipt/refund emails. Do
not add images, components, new marketing copy, or application code.

Use complete, valid LMX documents and revision-safe Loops email-message updates.
Validate every draft before previewing, inspect nine real-inbox previews across
the required data states, and publish only approved drafts. Loops remains the
source of truth for content; temporary LMX and API/CLI response files live under
`.context/cov-42/` and are not committed. This document is the durable record of
the published IDs, data-variable contracts, design decisions, and COV-45
handoff.

This is an approved copy-preserving port with an existing visual theme, so the
net-new image-generation workflow is intentionally skipped.

## Acceptance Criteria

- [ ] `billing-receipt` is previewed, published, and confirmed by a fresh
  transactional-email read.
- [ ] `billing-refund` is previewed, published, and confirmed by a fresh
  transactional-email read.
- [ ] `billing-subscription-renewing` is previewed, published, and confirmed by
  a fresh transactional-email read.
- [ ] `billing-payment-action-required` is previewed, published, and confirmed
  by a fresh transactional-email read.
- [ ] `billing-payment-failed` is previewed, published, and confirmed by a
  fresh transactional-email read.
- [ ] `billing-trial-will-end` is previewed, published, and confirmed by a fresh
  transactional-email read.
- [ ] `billing-trial-ended` is previewed, published, and confirmed by a fresh
  transactional-email read.
- [ ] Received previews use the existing Cove theme and render correctly on
  desktop/mobile and in their generated plain-text alternatives.
- [ ] Received subjects preserve the literal `[Cove] ` prefix and contain no
  unresolved variables.
- [ ] Receipt and refund previews render correctly both with and without
  `extra_billing_info`, using `dataVariablesFallbacks` with an empty-string
  fallback.
- [ ] Currency values arrive preformatted and render as expected, including a
  `$10.00` sample that proves cents are not displayed as whole dollars.
- [ ] Every received CTA is a working absolute HTTPS URL.
- [ ] The receipt uses the existing generated PDF attachment path and does not
  include `receipt_url`.
- [ ] All seven published transactional IDs and exact data contracts are
  recorded in this document for COV-45.
- [ ] No contact, audience, mailing list, campaign, workflow, or unrelated
  Loops object is created.

## Prototype

None. The Pay 11.6.2 HTML views and English subject keys lock the content, and
the existing COV-40 `Cove` theme locks the visual foundation. The approved UI
change is limited to clearer LMX hierarchy and a restrained receipt/refund
summary section.

## Data Model

No Rails models, migrations, routes, credentials, or application constants
change.

### Existing Loops dependency

| Object | Loops ID | Contract |
| --- | --- | --- |
| `Cove` theme | `cmsdnxho301lh0j17qh8ltsre` | Existing COV-40 theme referenced by one leading `<Style themeId="..." />` in every LMX document |

Do not create another theme or a reusable Loops component for this group.

### Transactional contracts

Replace the pending ID values after publishing.

| Template | Published transactional ID | Required data variables | Optional data variables |
| --- | --- | --- | --- |
| `billing-receipt` | Pending | `amount`, `charged_to`, `transaction_id`, `charged_at` | `extra_billing_info` |
| `billing-refund` | Pending | `amount_refunded`, `charged_to`, `transaction_id`, `charged_at` | `extra_billing_info` |
| `billing-subscription-renewing` | Pending | `renews_on`, `manage_subscription_url` | None |
| `billing-payment-action-required` | Pending | `confirm_payment_url` | None |
| `billing-payment-failed` | Pending | `update_billing_url` | None |
| `billing-trial-will-end` | Pending | `manage_subscription_url` | None |
| `billing-trial-ended` | Pending | `manage_subscription_url` | None |

`email` remains the separate top-level recipient field in the Loops
transactional send request. No template variable duplicates it.

### Field formats and app-side sources for COV-45

| Key | Format | App-side source/constraint |
| --- | --- | --- |
| `amount` | Preformatted string such as `$10.00` | `params[:pay_charge].amount_with_currency` |
| `amount_refunded` | Preformatted string such as `$10.00` | `params[:pay_charge].amount_refunded_with_currency` |
| `charged_to` | Display string | `params[:pay_charge].charged_to` |
| `transaction_id` | Prefixed ID such as `ch_...` | `params[:pay_charge].id` |
| `charged_at` | Localized display string | `params[:pay_charge].created_at`, localized by the app before sending |
| `extra_billing_info` | String, empty or at most 500 characters | Owner's `extra_billing_info` only when present; message fallback is `""` |
| `renews_on` | Localized long-date display string | `params[:date]`; Pay supplies Stripe's `next_payment_attempt` |
| `confirm_payment_url` | Absolute HTTPS URL | `pay.payment_url(params[:payment_intent_id])` |
| `update_billing_url` | Absolute HTTPS URL | Cove billing-management URL |
| `manage_subscription_url` | Absolute HTTPS URL | Cove subscription-management URL; used by renewal and both trial templates |

LMX does not format money or dates. Missing/incorrect formatting is an app
contract failure, not something the template repairs. For receipt/refund,
configure the email message with this complete replacement map:

```json
{
  "extra_billing_info": ""
}
```

The fallback must leave no visible placeholder or awkward titled section when
the value is absent. COV-45 must keep `extra_billing_info` within Loops' value
limit; the attached PDF retains the full billing value.

### Fixed message settings

- Application and business name: `Cove`
- Business address: `307 N 990 E`, `Salem, UT 84653`
- From: `Cove <notify@covehomeschool.com>`
- Reply-to: `support@covehomeschool.com`
- Format: styled, with Loops' generated plain-text alternative verified
- Preview text: none; the Pay source has no preview-copy equivalent

Subjects are literal strings, not data variables:

| Template | Subject |
| --- | --- |
| `billing-receipt` | `[Cove] Payment receipt` |
| `billing-refund` | `[Cove] Payment refunded` |
| `billing-subscription-renewing` | `[Cove] Your upcoming subscription renewal` |
| `billing-payment-action-required` | `[Cove] Confirm your payment` |
| `billing-payment-failed` | `[Cove] Action Required – Your payment failed` |
| `billing-trial-will-end` | `[Cove] Your trial is ending soon` |
| `billing-trial-ended` | `[Cove] Your trial has ended` |

### Receipt attachment contract

`billing-receipt` has no `receipt_url` variable. COV-45 forwards the existing
generated Pay attachment separately from `dataVariables`:

- Filename: `params[:pay_charge].receipt_filename`
- Content type: `application/pdf`
- Data: `params[:pay_charge].receipt`, base64 encoded for Loops

Loops support confirmed attachments are enabled for Cove. Loops currently
limits the complete transactional JSON request body to less than 4 MB and notes
that base64 increases file size by about 33 percent. A representative Cove
receipt generated during design verification was 20,706 bytes raw and 27,608
bytes base64; the estimated request was 28,608 bytes, or about 0.715 percent of
the limit.

## Screens / Flows

### 1. Credential and live-state preflight

1. Confirm `LOOPS_API_KEY` is not silently overriding named-key selection.
2. Verify the existing local `cove-cli` credential resolves to team `Cove`.
3. Fetch and compare the existing `Cove` theme by ID.
4. List the current transactional emails immediately before authoring.
5. If a matching name exists, fetch and reconcile its draft/published state
   rather than creating a duplicate.
6. Save only non-secret snapshots under `.context/cov-42/`.

If the credential resolves to another team, the theme is missing/materially
changed, or a matching object cannot be safely reconciled, stop before creating
anything.

### 2. Shared visual treatment

Every template uses the existing theme for its neutral canvas, white body,
typography, links, button defaults, borders, and spacing. Each document has one
H1 and a calm left-aligned transactional layout.

- Do not add images, a logo dependency, custom components, decorative cards,
  or a manual legal footer.
- Use a high-contrast button for each action-oriented email.
- Use one restrained `<Section>` for receipt/refund details, with bold inline
  labels rather than a heading for every field.
- Keep the body useful when images are blocked; these templates require no
  image to convey meaning.
- Preserve source punctuation, including the source en dash in the payment
  failure subject and the source Cove Team signoff.

### 3. `billing-receipt`

LMX content order:

1. H1: `Payment receipt`
2. `We received payment for your Cove subscription. Thanks for your business!`
3. One summary section containing:
   - `Amount:` `{data.amount}`
   - `Charged to:` `{data.charged_to}`
   - `Transaction ID:` `{data.transaction_id}`
   - `Date:` `{data.charged_at}`
   - `{data.extra_billing_info}` without a visible label, using the empty-string
     fallback when absent
4. Baked-in Cove business name and address
5. `Questions? Please reply to this email.`

The receipt is attached. Do not add a button or link to the authenticated Cove
billing charge route.

### 4. `billing-refund`

LMX content order:

1. H1: `Payment refunded`
2. `We have processed your Cove refund.`
3. `Please allow up to 7 business days for your refund to appear in your account.`
4. One summary section containing:
   - `Amount:` `{data.amount_refunded}`
   - `Refunded to:` `{data.charged_to}`
   - `Transaction ID:` `{data.transaction_id}`
   - `Date:` `{data.charged_at}`
   - `{data.extra_billing_info}` without a visible label, using the empty-string
     fallback when absent
5. Baked-in Cove business name and address
6. `Questions? Please reply to this email.`

### 5. `billing-subscription-renewing`

LMX content order:

1. H1: `Your upcoming Cove subscription renewal`
2. `This is a friendly reminder that your Cove subscription will renew automatically on {data.renews_on}.`
3. Button: `Manage your subscription`, linking to
   `{data.manage_subscription_url}`
4. `If you have any questions, please hit reply and let us know.`
5. `— The Cove Team`

The message names the actual date but promises no fixed lead time. Pay invokes
this mailer from Stripe's upcoming-invoice webhook only when
`next_payment_attempt` exists and the default `Pay.emails.subscription_renewing`
lambda accepts the price (currently annual recurring prices).

### 6. `billing-payment-action-required`

LMX content order:

1. H1: `Extra confirmation is needed to process your payment`
2. `Your Cove subscription requires confirmation to process your payment to continue access.`
3. Button: `Confirm your payment`, linking to
   `{data.confirm_payment_url}`
4. `If you have any questions, please hit reply and let us know.`
5. `— The Cove Team`

Do not add a payment-intent expiry hint. An expired link is handled by the
downstream billing flow.

### 7. `billing-payment-failed`

LMX content order:

1. H1: `Your payment was declined`
2. `We were unable to charge your payment method for your Cove subscription. Please update your billing information.`
3. Button: `Update billing information`, linking to
   `{data.update_billing_url}`
4. `Let us know if you have any questions.`
5. `— The Cove Team`

### 8. `billing-trial-will-end`

LMX content order:

1. H1: `Your Cove trial is ending soon`
2. `This is just a friendly reminder that your Cove trial will be ending soon.`
3. Button: `Manage your subscription`, linking to
   `{data.manage_subscription_url}`
4. `If you have any questions, please hit reply and let us know.`
5. `— The Cove Team`

### 9. `billing-trial-ended`

LMX content order:

1. H1: `Your Cove trial has ended`
2. `This is just a friendly reminder that your Cove trial has ended.`
3. Button: `Manage your subscription`, linking to
   `{data.manage_subscription_url}`
4. `If you have any questions, please hit reply and let us know.`
5. `— The Cove Team`

### 10. Revision-safe authoring

Work in three controlled batches:

1. Receipt/refund
2. Subscription renewal and the two trial notices
3. Payment action required and payment failed

For each template:

1. Create the transactional object only if no matching object exists.
2. Capture its transactional ID, draft email-message ID, and current content
   revision ID.
3. Update subject, sender, reply-to, styled format, fallbacks, and complete LMX
   using the last-seen revision.
4. Save the new revision returned by each successful update.
5. Run LMX compilation and Guardian validation; treat errors as blockers and
   review every warning.
6. If a revision conflict occurs, refetch and reconcile the current website
   edit. Never force an overwrite silently.

### 11. Real-inbox preview matrix

Send previews with `email-messages preview`, not a live transactional send and
never an audience-adding option.

| Template | Preview states |
| --- | --- |
| `billing-receipt` | With representative `extra_billing_info`; without it |
| `billing-refund` | With representative `extra_billing_info`; without it |
| Remaining five templates | One complete-variable preview each |

This is nine preview sends, below the team's 100-preview rolling 24-hour cap.
Batch the previews and inspect each batch before publishing. Verify:

- literal subject with the `[Cove] ` prefix
- theme, hierarchy, spacing, and mobile rendering
- generated plain-text alternative
- `$10.00`-style formatted currency
- optional billing information in both states
- transaction/date values
- complete, clickable HTTPS CTA targets
- absence of unresolved `{data.*}` text

If the preview endpoint returns 429, stop and resume when capacity returns; do
not retry repeatedly. If any rendering or contract check fails, revise and
re-preview only the affected template/state.

### 12. Publish and durable handoff

Publish only after each template's required previews pass. After publishing:

1. Fetch each transactional email by ID and confirm its published state.
2. Compare the returned `dataVariables` list with the contract in this
   document.
3. Replace every pending ID in the Data Model table.
4. Record the preview recipient/check date without retaining inbox content.
5. Confirm final inventories contain no contacts, audiences, lists, campaigns,
   workflows, or unrelated objects created by this ticket.

If publishing fails, leave the object as a draft and do not record it as
published.

## Scope

**In:** Reuse of the existing Cove theme and local CLI credential; seven
complete LMX transactional emails; literal subjects; revision-safe authoring;
Guardian/compilation checks; nine real-inbox previews; publishing; fresh state
verification; published IDs and exact contracts documented here; receipt
attachment decision and payload evidence.

**Deferred:** All Rails/application integration and configuration (COV-45);
forwarding the generated attachment through the delivery method (COV-45);
changing `Pay.emails.*` toggles; any signed or unauthenticated receipt route;
any fallback to Stripe's hosted receipt; logos, images, custom Loops components,
contacts, audiences, mailing lists, campaigns, workflows, or marketing copy.

Although this group contains seven email artifacts, they remain one cohesive
MVP because they share one mailer, one theme, one authoring workflow, and one
COV-45 integration handoff. No additional billing-email scope is included.

## Open Questions

None.

Resolved during design:

- Attach the Pay-generated receipt PDF because Cove's Loops account has
  attachments enabled and the representative payload is far below the current
  4 MB request limit. Do not add `receipt_url`.
- Preserve the existing `[Cove] ` subject prefix and bake in literal `Cove`
  rather than adding a data variable for a constant.
- Preserve the Pay source copy. Do not add an expiry hint to payment action
  required, and do not claim a fixed renewal lead time.
- Require `manage_subscription_url` for the renewal template as well as both
  trial templates; a shared Loops template cannot safely bake in one
  environment's account URL.
- Limit the inline `extra_billing_info` contract to 500 characters; the
  attachment retains the full value.
- Keep all seven Pay billing messages in this ticket while deferring all app
  wiring and receipt-route work.
- Use a structured faithful port: action buttons and one receipt/refund summary
  section, without a visual redesign.

## More Info

Copy and subject sources:

- `pay-11.6.2/app/views/pay/user_mailer/*.html.erb`
- `pay-11.6.2/config/locales/en.yml` under `pay.user_mailer`
- `pay-11.6.2/app/mailers/pay/user_mailer.rb`

Trigger and payload sources:

- Receipt/refund use `params[:pay_charge]` for the formatted amount, payment
  method, prefixed charge ID, created time, and owner billing information.
- Renewal uses Stripe's upcoming-invoice webhook and its
  `next_payment_attempt`; Pay's default lambda sends only for annual recurring
  prices.
- Payment action required uses
  `pay.payment_url(params[:payment_intent_id])`.
- Trial notices and payment failure are webhook-triggered and use the account's
  billing/subscription-management destination supplied by COV-45.
- `Pay.mail_to` can send to both the account owner and `account.billing_email`.
  The PDF attachment preserves access for a billing contact who is not a Cove
  user.

Receipt decision ownership is here, in COV-42. It supersedes COV-37's earlier
“link, do not attach” choice because COV-38 later confirmed that attachments are
enabled. If attachment sending becomes unavailable during COV-45, do not
silently use `billing_charge_path`: it requires authentication, is scoped to
`current_account`, and does not serve non-user billing contacts. A signed public
receipt URL remains separate product and security work.

Operational constraints:

- Loops email-message fallbacks are metadata outside the LMX document and are
  full replacement maps when updated.
- LMX uses `{data.variable_name}` for all seven transactional messages.
- The daily preview cap is 100 per team per rolling 24 hours.
- Content endpoints are limited to 60 requests per minute; transactional sends
  use the separate team rate limit recorded by COV-38.
- Previewing transactional messages does not create contacts. Never opt into
  audience creation for this work.
- Preview endpoints do not exercise attachments. Actual attachment forwarding
  is implemented and tested in COV-45; COV-42 validates template content,
  account enablement, and representative payload size.
