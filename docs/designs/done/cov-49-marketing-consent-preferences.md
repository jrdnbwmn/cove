> Plan created: docs/plans/cov-49-marketing-consent-preferences.md

> Ticket: COV-49
> Branch: feature/cov-49-marketing-consent-model-preference-ui

# Feature: Marketing consent model and preference UI

## Problem

Cove cannot audit whether a user agreed to receive marketing email because it
has no consent state, provenance, or preference UI. Consent must live in Cove
before consented users can be synced to Loops, and a Loops-originated opt-out
must not be undone by routine app synchronization.

## Approach

Store per-user marketing consent as four typed columns on `users`, following
COV-48's split-authority decision. Derive subscription state from the consent
timestamps instead of adding a second boolean source of truth, and encapsulate
the state transitions in a focused `User::MarketingConsent` concern.

Capture optional consent through an unchecked checkbox during ordinary
registration and through a separate Marketing preferences form in account
settings. The settings form submits to a dedicated, authenticated
`MarketingPreferencesController#update` endpoint rather than sharing the
general Devise profile-update action. This keeps consent changes explicit and
ensures the server, rather than browser parameters, supplies provenance.

No Loops request, contact job, webhook, or reconciliation behavior is part of
this feature.

## Acceptance Criteria

- A newly created user is not subscribed to marketing unless they explicitly
  select the registration checkbox.
- Ordinary registration can record opt-in with its time and `registration`
  source.
- Invitation registration never captures marketing consent, including when a
  crafted request supplies the marketing parameter.
- A signed-in user can opt in from the separate Marketing preferences section;
  the transition records a fresh time and `settings` source.
- A signed-in user can opt out from Marketing preferences; the transition
  records its time and `user_app` reason.
- Both consent controls default off and render an explicit hidden `"0"` field
  immediately before the catalog checkbox/switch, proving that an unchecked
  control submits an opt-out value.
- A deliberate user action may reverse a `user_app` opt-out. Loops-originated
  opt-outs remain protected until Loops support confirms how a contact can
  restore membership in the public `Cove updates` list.
- A mailing-list opt-out is recorded separately as
  `mailing_list_unsubscribe`. It cannot be reversed through Cove unless Loops
  support confirms a valid subscriber-controlled rejoin flow.
- `user_loops`, `mailing_list_unsubscribe`, `hard_bounce`, and `spam_report`
  states cannot be reversed by the settings toggle. Changing the email clears
  a hard-bounce state to the default unsubscribed state; both Loops-originated
  states and spam-report states remain protected.
- Marketing consent never gates password resets, password-change notices, or
  any other transactional authentication or security email.
- Existing users are unsubscribed after migration because all four new columns
  backfill to null. Migration behavior is covered by a test.
- User fixtures include intent-named subscribed and unsubscribed states while
  continuing to follow the repository's fixtures-only convention.
- Tests cover the model transitions, registration capture, dedicated settings
  endpoint, authorization, protected states, and unchecked-field behavior.
- `bin/rails test` passes and `bin/rubocop` is clean.
- The final `git diff` is reviewed. Any unrelated Rails 8.1 schema-dump
  reordering or version drift in the four known schema files is reverted.

## Prototype

None. The existing registration and account-settings layouts remain
authoritative. This feature adds controls within those layouts without
rearranging or redesigning them.

## Data Model

No new persisted model or table is needed. Add four nullable columns to
`users`, matching COV-48:

| Column | Type | Purpose |
| --- | --- | --- |
| `marketing_opt_in_at` | `datetime` | When the latest consent was granted |
| `marketing_opt_in_source` | `string` | Consent surface: `registration`, `settings`, or `loops` |
| `marketing_opt_out_at` | `datetime` | When marketing eligibility ended |
| `marketing_opt_out_reason` | `string` | `user_app`, `user_loops`, `mailing_list_unsubscribe`, `hard_bounce`, or `spam_report` |

There is no stored `marketing_subscribed` boolean. A
`marketing_subscribed?` predicate returns true only when
`marketing_opt_in_at` is present and `marketing_opt_out_at` is absent. A
matching scope exposes subscribed users for COV-51.

`User::MarketingConsent` owns the allowed source/reason values, validation,
the registration-only virtual checkbox attribute, and explicit methods for
granting and withdrawing consent. State transitions follow these rules:

- Granting consent from an unsubscribed state records the current time and the
  trusted server-supplied source.
- Withdrawing active consent records the current time and trusted reason.
- Repeating the current choice is a no-op and does not rewrite provenance.
- `user_app` is reversible through a deliberate in-app opt-in.
- `user_loops` represents an audience-level Loops unsubscribe. It temporarily
  blocks in-app opt-in even though Loops supports audience-level API
  resubscription, because Cove must not claim success unless it can also
  restore the required public-list membership.
- `mailing_list_unsubscribe` represents `contact.mailingList.unsubscribed` and
  blocks opt-in unless Loops support confirms a valid subscriber-controlled
  rejoin flow. Cove must not attempt to reverse it through the API.
- `hard_bounce` blocks opt-in until the email changes. An email change resets
  the four fields to the default unsubscribed state; it does not automatically
  subscribe the new address.
- `spam_report` cannot be cleared by an app action or email change.
- Invalid source and reason values fail validation.

The migration performs no opt-in data update. Existing rows receive null for
all four columns and therefore derive as unsubscribed.

## Screens / Flows

### Ordinary registration

1. The sign-up form renders an unchecked `CheckboxComponent` between the
   terms checkbox and Sign up button.
2. Its label is: "Send me occasional Cove updates and homeschooling
   resources."
3. An explicit hidden `user[marketing_opt_in]` value of `"0"` appears
   immediately before the checkbox.
4. If registration validation fails, the form preserves the submitted checked
   state.
5. A successful checked submission records the opt-in time and
   `registration` source. An unchecked submission leaves all consent columns
   null.
6. Invitation registration does not render or accept this consent field.

### Account settings

1. A separate "Marketing preferences" section appears between the existing
   Profile form and Cancel my account section.
2. Its dedicated form submits only the desired marketing state to a singular
   authenticated marketing-preference update route.
3. A `SwitchComponent` is labeled "Cove updates" with the description:
   "Receive occasional product news and homeschooling resources by email."
4. An explicit hidden `"0"` value appears immediately before the switch.
5. A `ButtonComponent` labeled "Save marketing preferences" submits the form;
   switching the control alone does not save.
6. The endpoint always updates `current_user`. It accepts no user id, source,
   reason, or timestamp from the browser.
7. Successful transitions redirect back to account settings with confirmation
   feedback. Missing, invalid, or forbidden transitions leave consent
   unchanged and return explanatory feedback.
8. The displayed state comes only from Cove's columns. Rendering this page
   never reads from Loops.

### Protected opt-out states

- For `user_loops` or `mailing_list_unsubscribe`, the switch and save button
  are disabled and the page says: "You unsubscribed through email preferences.
  You can't currently restore this subscription from Cove."
- For `hard_bounce`, the switch and save button are disabled and the page says:
  "We couldn't deliver email to this address. Update your email before
  subscribing again."
- For `spam_report`, the switch and save button are disabled and the page says:
  "Marketing updates are unavailable because a previous message was reported
  as spam."

### Transition and request edge cases

- Saving on while already subscribed preserves the original opt-in timestamp.
- Saving off while already unsubscribed preserves the existing state.
- A never-subscribed user saving off stays in the all-null default state; Cove
  does not invent an opt-out event when there was nothing to withdraw.
- Re-opting in after `user_app` records a new opt-in time and `settings` source
  and clears the reversible opt-out.
- Attempting to opt in after `user_loops` or `mailing_list_unsubscribe` leaves
  consent unchanged. Until the support question is resolved, Cove does not
  claim that COV-51 successfully restored audience subscription or membership
  in `Cove updates`.
- Missing or invalid preference parameters never default to opt-out.
- Authentication is required, and the route exposes no way to select another
  user.

## Scope

**In:** one users migration; per-user consent state and transition logic;
ordinary-registration capture; a separate account-settings preference form and
dedicated update endpoint; explicit unchecked values; protected-state UI;
existing-user null backfill; fixtures; model, migration, request, and rendered
form tests.

**Deferred:** all Loops API calls and contact synchronization (COV-51); webhook
ingestion and reconciliation (COV-52); mailing-list structure and configuration
(COV-53); campaign or workflow content; double opt-in; invitation-flow consent;
enabling in-app reversal of Loops-originated opt-outs before the support answer;
and changes to transactional email behavior. Marketing consent never gates
transactional authentication or security email.

## Open Questions

1. When a contact unsubscribes from a public mailing list in the Loops
   Preference Center, can that same contact later rejoin it themselves? If so,
   what webhook event is emitted?

## More Info

- COV-48 establishes per-user consent, split authority, one marketing channel,
  and two unchecked capture points. The app is authoritative for deliberate
  opt-in; opt-out may originate in Cove or Loops. COV-53 refines that decision
  by distinguishing audience-level and mailing-list Loops opt-outs because
  Loops gives them different reversibility rules.
- `user_app` remains reversible through a deliberate user action. Both
  Loops-originated reasons remain protected for the interim: although Loops
  documents audience-level API resubscription, Cove cannot promise a restored
  marketing subscription unless the required public-list membership can also
  be restored. Profile updates and routine synchronization must never infer
  opt-in.
- COV-52 maps `contact.unsubscribed` to `user_loops` and
  `contact.mailingList.unsubscribed` to `mailing_list_unsubscribe`.
- COV-51 must not send `subscribed: true` or `Cove updates` membership `true`,
  or claim either transition succeeded locally, while a user is protected by
  `user_loops` or `mailing_list_unsubscribe`.
- The model includes `loops`, `user_loops`, `mailing_list_unsubscribe`,
  `hard_bounce`, and `spam_report` values now so COV-52 can write the approved
  states without changing the schema or consent rules.
- Current Loops documentation says audience-level unsubscribes can be reversed
  through the API, while a contact who unsubscribes from a mailing list through
  the Preference Center cannot be re-subscribed by the team. It does not state
  whether that contact can later rejoin a public list themselves:
  `https://loops.so/docs/contacts/properties` and
  `https://loops.so/docs/contacts/mailing-lists`.
- Marketing consent applies only to campaigns and marketing workflows. It
  never suppresses password resets, password-change notices, or other
  transactional authentication and security email.
- `CheckboxComponent` and `SwitchComponent` do not generate Rails' companion
  unchecked field. Each form must add its own hidden `"0"` input before the
  visible control.
- Use only existing catalog components from `docs/COMPONENT_CATALOG.md`; no new
  component or external UI dependency is needed.
- Tests use Minitest and repository fixtures. No FactoryBot, Faker, or new gem
  is introduced.
