> Ticket: COV-40
> Branch: feature/cov-40-author-and-publish-lmx-templates
> Plan created: docs/plans/cov-40-auth-templates.md

# Feature: Auth transactional email templates

## Problem

Cove cannot deliver Devise password resets or password-change security notices
through Loops until both transactional emails exist and are published. Publishing
is a deploy-order dependency for COV-43: Loops rejects sends that reference an
unpublished transactional email.

## Approach

Create one shared `Cove` theme and two transactional emails in the Cove Loops
team. Author the email bodies as complete LMX documents with the `loops-lmx`
workflow, manage the Loops objects with `loops-cli`, preview each email in a real
inbox, and publish only after all rendering checks pass.

This is a minimal port of the existing Devise ERB and English i18n copy, not a
copy rewrite or app-code change. The shared theme owns the neutral canvas, white
body, padding, typography, links, buttons, borders, and dividers so later
transactional and marketing templates can reuse the same visual foundation.
The emails contain no required imagery and remain complete when images are
blocked.

Loops is the source of truth for the theme and email content. Temporary LMX and
theme JSON files live under `.context/` while the CLI uploads them; they are not
committed. This document is the durable integration record for theme and
transactional IDs, data-variable contracts, and operational verification.

## Acceptance Criteria

- [x] A dedicated `cove-cli` API key resolves to the Cove team and remains only
  in the local keyring.
- [x] The shared `Cove` theme is created in Loops and its `themeId` is recorded
  in this document.
- [x] `reset-password` is previewed in a real inbox and published;
  `loops transactional get <id>` confirms the published state.
- [x] `password-changed` is previewed in a real inbox and published;
  `loops transactional get <id>` confirms the published state.
- [x] The reset preview button is a real clickable absolute URL, not literal
  `{data.reset_password_url}` text.
- [x] Both emails render acceptably with images blocked and in their plain-text
  alternatives.
- [x] Both published `transactionalId` values and the exact `dataVariables`
  contracts are recorded in this document for COV-43.
- [x] No mailing list, audience, contact, or other unrelated Loops object is
  created.

## Prototype

None. The existing Devise mailer views and English i18n keys lock the copy. The
approved visual direction is a text-first, monochrome Loops theme matching
Cove's current application tokens.

## Data Model

No Rails models, migrations, credentials, or application constants change.

The external Loops objects and durable contracts are:

| Object | Loops ID | Durable contract |
| --- | --- | --- |
| `Cove` theme | `cmsdnxho301lh0j17qh8ltsre` | Shared theme referenced by `themeId` in LMX |
| `reset-password` | `cmsdnzduk02k40jx72rv3uwe2` | Published `transactionalId`; required `recipient_email`, `reset_password_url` |
| `password-changed` | `cmsdo8ixv001e0j1zu027i3s7` | Published `transactionalId`; required `recipient_email` |

`email` remains the separate top-level recipient field in the Loops
transactional send request. `recipient_email` is intentionally repeated in
`dataVariables` because the source greeting displays the user's email address.

### App-side values for COV-43

| Template | Key | App-side source |
| --- | --- | --- |
| `reset-password` | `recipient_email` | `user.email` |
| `reset-password` | `reset_password_url` | `edit_password_url(user, reset_password_token: token)`, using the raw token Devise passes to `send_devise_notification` |
| `password-changed` | `recipient_email` | `user.email` |

The reset copy does not mention token lifetime, so `expires_in_hours` is not a
template variable. Application name, business name/address, sender, and support
address are fixed Loops/template settings rather than send-time variables:

- Application/business name: `Cove`
- Sender: `Cove <notify@covehomeschool.com>`
- Reply-to/support: `support@covehomeschool.com`
- Business address: the Cove team address already configured in Loops; Loops
  owns the generated business/legal footer

The dedicated `cove-cli` key is an operational credential, not application
configuration. It is retained locally for COV-41 and COV-42 and is never written
to the repository or transcript.

### Execution verification (2026-08-03)

- Preview recipient: `jordan.d.bowman@gmail.com` (inbox content not retained).
- `reset-password` Guardian passed with no errors or warnings. Its approved
  preview confirmed styled rendering, images-blocked rendering, the generated
  plain-text alternative, and its button's complete staging reset URL.
- `password-changed` Guardian passed with no errors or warnings. Its approved
  preview confirmed styled rendering, images-blocked rendering, and the
  generated plain-text alternative.
- Fresh `transactional get` reads confirmed both IDs above are published and
  returned exactly these `dataVariables` contracts:
  - `reset-password`: `recipient_email`, `reset_password_url`
  - `password-changed`: `recipient_email`
- Final inventories confirmed exactly one `Cove` theme and exactly the two
  intended transactional emails. This workflow created no contacts, audiences,
  lists, campaigns, workflows, or other unrelated Loops objects.

## Screens / Flows

### 1. Credential and live-state preflight

1. In the Loops website, the user creates a named API key `cove-cli`.
2. In the user's terminal, store it through the interactive
   `loops auth login cove-cli` prompt so the value does not enter shell history
   or the agent transcript.
3. Verify `loops api-key --team cove-cli -o json` reports the Cove team.
4. Re-list themes and transactional emails immediately before creation. If a
   matching object now exists, inspect it rather than creating a duplicate.

Live state observed during brainstorming on 2026-08-03: the Cove team had no
themes and no transactional emails. Execution must re-check because this state
can change.

### 2. Shared `Cove` theme

Create the theme with `loops themes create -n Cove --styles-file <path>` and
capture its `themeId`. Use the CLI's supported theme-style fields to implement
this approved visual contract:

| Element | Approved treatment |
| --- | --- |
| Canvas | Light neutral gray with deliberate outer padding |
| Body | White surface with 24-32px responsive-safe inner padding |
| Base text | Near-black, 15-16px, comfortable line height, system-safe sans serif |
| Headings | Near-black; restrained email scale (H1 about 26px) |
| Links | Near-black and visibly distinguishable as links |
| Primary button | Near-black background, white text, modest rounded corners, comfortable inner padding |
| Border/divider | Muted neutral gray, used sparingly |

Do not add a logo, image dependency, custom Loops component, decorative card
system, or marketing-specific styling. Each LMX document references the
created theme with a single top-level `<Style themeId="..." />`.

### 3. `reset-password`

Create the transactional email, capture its `transactionalId`,
`emailMessageId`, and `contentRevisionId`, then update the email message with
the last-seen revision rather than forcing an overwrite.

Message settings:

- Name: `reset-password`
- Subject: `Reset password instructions`
- Preview text: none; the source has no preview-copy equivalent
- From: `Cove <notify@covehomeschool.com>`
- Reply-to: `support@covehomeschool.com`
- Format: styled, with Loops' generated plain-text alternative verified before
  publishing

LMX content order and exact source copy:

1. H1: `Reset password instructions`
2. Greeting: `Hello {data.recipient_email}!`
3. `Someone has requested a link to change your password. You can do this
   through the link below.`
4. CTA button: `Change my password`, with
   `href="{data.reset_password_url}"`
5. `If you didn't request this, please ignore this email.`
6. `Your password won't change until you access the link above and create a
   new one.`

Run Guardian validation, then send one preview containing the complete variable
set to a real inbox. Use the recipient's real email for `recipient_email` and a
harmless absolute URL such as:

`https://staging.covehomeschool.com/users/password/edit?reset_password_token=cov40-preview`

The recipient verifies visual rendering, the clickable reset target, behavior
with images blocked, and the plain-text alternative. Publish only after those
checks pass, then verify the published state with
`loops transactional get <transactionalId>`.

### 4. `password-changed`

Follow the same revision-safe create, update, Guardian, preview, publish, and
get sequence.

Message settings:

- Name: `password-changed`
- Subject: `Password Changed`
- Preview text: none; the source has no preview-copy equivalent
- From: `Cove <notify@covehomeschool.com>`
- Reply-to: `support@covehomeschool.com`
- Format: styled, with Loops' generated plain-text alternative verified before
  publishing

LMX content order and exact source copy:

1. H1: `Password changed`
2. Greeting: `Hello {data.recipient_email}!`
3. `We're contacting you to notify you that your password has been changed.`

Do not add a "this wasn't me" support link or any other security copy. That
would be a copy change beyond the approved source port.

### 5. Preview and publishing safeguards

- Use `loops email-messages preview`, never `transactional send` or
  `--add-to-audience`; previews must not create contacts.
- Batch each template's complete variables into one preview. The Cove team has
  a shared limit of 100 preview sends per rolling 24 hours. If Loops returns
  429, stop and resume after the window rather than retrying repeatedly.
- Treat LMX compilation errors and Guardian failures as publish blockers.
  Review warnings individually.
- If a revision conflict occurs, fetch the latest email message and reconcile
  the website edit; do not replace it with `--force` silently.
- If inbox, images-blocked, link, or plain-text verification fails, revise and
  preview again before publishing.
- If publishing fails, leave the object as a draft and do not record it as
  published.

### 6. Handoff record

After both emails publish, replace the pending values in the Data Model table
with the confirmed `themeId` and `transactionalId` values. Record the preview
recipient/check date without recording sensitive inbox content. COV-43 consumes
only the published IDs and exact data-variable names; storing those IDs in Rails
credentials or constants remains COV-43's responsibility.

Auth transactional delivery is independent of `marketing_subscribed?` and must
never add the recipient to the Loops audience. Marketing consent from COV-49
must not gate password-reset or password-change security email.

## Scope

**In:** Dedicated local `cove-cli` credential; one shared Loops theme; two LMX
transactional emails; revision-safe updates; Guardian checks; real-inbox,
images-blocked, link, and plain-text verification; publishing; confirmed IDs and
data-variable contracts documented here.

**Deferred:** All Rails/app integration (COV-43); storing IDs in credentials or
constants (COV-43); the other nine transactional templates (COV-41/COV-42);
marketing templates (COV-55/COV-56); any new password-change security copy;
logos, reusable Loops components, audiences, contacts, mailing lists, campaigns,
or workflows.

## Open Questions

None.

Resolved during design:

- Create and retain a dedicated `cove-cli` key instead of authoring with the
  production server credential.
- Use the full shared-theme foundation rather than duplicating style attributes
  across templates.
- Keep `password-changed` as a straight source-copy port with no "this wasn't
  me" support link.
- Omit expiration copy and `expires_in_hours` because the source reset email
  does not state the token lifetime.

## More Info

Copy sources:

- `lib/jumpstart/app/views/devise/mailer/reset_password_instructions.html.erb`
- `lib/jumpstart/app/views/devise/mailer/password_change.html.erb`
- `config/locales/devise.en.yml`

COV-38 established the Cove team, verified sending domain, named environment
keys, and team-wide operational limits. Transactional and marketing sends share
the free-plan allowance, but this ticket uses previews rather than live
transactional sends. COV-40 blocks COV-41, COV-42, and COV-43.
