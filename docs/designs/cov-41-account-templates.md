> Ticket: COV-41
> Branch: feature/cov-41-author-publish-lmx-templates-account-group
> Plan created: docs/plans/cov-41-account-templates.md

# Feature: Account transactional email templates

## Problem

`AccountMailer#invite` and `AccountMailer#cancellation_reason` still depend on
ERB views and have no published Loops equivalents. COV-44 cannot move these
mailers to the Loops delivery path until both transactional templates exist,
have verified contracts, and are published.

The invitation is currently unreachable through the normal UI because Cove
uses personal accounts only, but its model callback and admin route remain
active. The template must therefore be ready for those paths and for any future
move to team accounts without changing account configuration in this ticket.

## Approach

Create two Loops transactional emails using complete LMX documents and the
existing `cove-cli` credential established by COV-40:

- `account-invite` is a compact Styled email that references the existing
  `Cove` theme and turns the source invitation link into a themed CTA button.
- `cancellation-survey` is a Plain email that preserves the three source
  paragraphs and reads like a personal request for a reply.

This is a minimal English source-copy migration, not a rewrite or app-code
change. Author temporary LMX and non-secret CLI response files under
`.context/cov-41/`; only this design document is committed. Manage Loops drafts
with revision-safe CLI reads and updates, validate them with Guardian, preview
each in a real inbox, and publish only after the relevant rendering and header
checks pass.

The existing COV-40 theme is reused exactly for `account-invite`. Loops does not
support themes in Plain mode, so `cancellation-survey` intentionally has no
theme reference. Its consistency with the account group comes from the same
source copy, `Cove` sender identity, support address, and restrained text-first
presentation. See <https://loops.so/docs/creating-emails/styles>.

No image-generation reference is needed because this is a copy-only migration
with an approved existing visual direction, not a net-new design or redesign.

## Acceptance Criteria

- [x] `account-invite` is published and a fresh
  `loops transactional get <id>` confirms its published state.
- [x] `cancellation-survey` is published and a fresh
  `loops transactional get <id>` confirms its published state.
- [x] A preview of each template is received and checked in a real inbox.
- [x] The received `account-invite` subject interpolates both `inviter_name`
  and `account_name` correctly.
- [x] The received invitation button resolves to the supplied absolute preview
  URL rather than displaying or linking to literal `{data.invitation_url}`.
- [x] The received `account-invite` is Styled with the existing `Cove` theme.
- [x] The received `cancellation-survey` has the intended Plain presentation.
- [x] The cancellation preview's headers contain
  `Reply-To: support@covehomeschool.com`.
- [x] Both previews send from Cove's verified sending identity — see the
  "Discovered platform behavior" note below for the exact resolved address.
- [x] Both published transactional IDs and their exact data-variable contracts
  are recorded in this document for COV-44.
- [x] Final inventory confirms that no mailing list, audience, contact,
  campaign, workflow, component, or unrelated transactional email remains
  from this execution. One throwaway draft created during platform-behavior
  isolation testing was removed manually from the Loops dashboard; other
  unrelated transactional objects in the live team are from concurrent work
  in another workspace. See "Discovered platform behavior and inventory notes"
  below.

### Discovered platform behavior and inventory notes

- **`<Strong>` around a bare data variable is silently stripped.** The design
  called for `<Strong>{data.account_name}</Strong>` in `account-invite`. Three
  isolated live tests confirmed Loops strips `<Strong>` (and shifts its
  boundary) when it wraps only a bare `{data.*}` variable with no adjacent
  literal text, even though nothing in the LMX spec documents this
  restriction. Per user decision, `account-invite` ships with
  `{data.account_name}` rendered as plain (unbolded) text instead. Worth a
  support ticket to Loops if this comes up again; none was filed for this
  ticket.
- **A default theme is auto-stamped onto Plain-format messages.** Even though
  `cancellation-survey` is Plain and its authored LMX has no `<Style />` tag,
  the stored message has `<Style themeId="cmsdnxho301lh0j17qh8ltsre" />`
  auto-injected by Loops (reproduced independently on a disposable test
  object). Per the design's own note, themes are not applied to Plain
  rendering, so this is treated as inert bookkeeping metadata, confirmed
  harmless by the real-inbox preview showing the intended unstyled
  presentation.
- **Sending domain resolves to a subdomain.** `fromEmail: support` resolves to
  `support@mail.covehomeschool.com` (the verified Loops sending subdomain),
  not the bare `support@covehomeschool.com` this document assumed elsewhere.
  Confirmed correct by the user from the received preview headers.
- **One unrelated draft transactional (`cov41-throwaway-test`,
  `cmsdrnmdv040r0jwf50hqfz9j`) was created during platform-behavior isolation
  testing above.** It had no published message or real content. Because the
  CLI has no `transactional delete` command, it was removed manually from the
  Loops dashboard on 2026-08-03; a fresh CLI inventory confirmed its absence.
- **Five further unrelated transactional objects were observed in the final
  inventory** (`billing-trial-ended`, `billing-trial-will-end`,
  `billing-subscription-renewing`, both published, and `billing-refund` /
  `billing-receipt`, both published) that no command in this execution's
  record created. These almost certainly originate from concurrent work in a
  different workspace against the same shared live Cove team, not from this
  ticket.

## Prototype

None. The existing ERB views and English i18n keys lock the copy and content
order. COV-40's published `Cove` theme locks the Styled visual direction.

Copy sources:

- `lib/jumpstart/app/views/account_mailer/invite.html.erb`
- `lib/jumpstart/app/views/account_mailer/cancellation_reason.html.erb`
- `config/locales/en.yml` under `account_mailer`

## Data Model

No Rails models, migrations, credentials, routes, or application configuration
change.

The external Loops objects and durable contracts are:

| Object | Loops ID | Durable contract |
| --- | --- | --- |
| `Cove` theme | `cmsdnxho301lh0j17qh8ltsre` | Existing COV-40 theme; referenced by the Styled invite (unchanged; re-fetched and confirmed byte-identical to the Task 1 baseline) |
| `account-invite` | `cmsdr01rw02s00j3ozshehy4f` (message `cmsdr01rt02rz0j3oqaef9tck`) | Published; confirmed `dataVariables`: `inviter_name`, `account_name`, `invitation_url` |
| `cancellation-survey` | `cmsdrmznp040g0jzsnkt9hpsa` (message `cmsdrmznn040f0jzsph4aaw4z`) | Published; confirmed `dataVariables`: empty |

The recipient remains the separate top-level `email` field in each Loops
transactional request. COV-44 will provide these values:

| Template | Key | App-side source |
| --- | --- | --- |
| `account-invite` | Top-level `email` | `@account_invitation.email` |
| `account-invite` | `inviter_name` | `@account_invitation.invited_by&.name`, falling back to `"Someone"` before sending |
| `account-invite` | `account_name` | `@account_invitation.account.name` |
| `account-invite` | `invitation_url` | `account_invitation_url(@account_invitation)` |
| `cancellation-survey` | Top-level `email` | `params[:user].email` |

All three invite variables are required. LMX has no inline fallback syntax, so
the existing inviter fallback remains app-side. `cancellation-survey` has no
dynamic data because every body value is fixed Cove copy.

Fixed message settings:

| Setting | `account-invite` | `cancellation-survey` |
| --- | --- | --- |
| From name | `Cove` | `Cove` |
| From email username | `support` | `support` |
| Reply-to | Unset; replies default to the From address | `support@covehomeschool.com` |
| Email format | `styled` | `plain` |
| Theme | `cmsdnxho301lh0j17qh8ltsre` | None; themes are unavailable in Plain mode |
| Preview text | None | None |

`fromEmail` accepts only the username. Loops appends Cove's single verified
sending domain, producing `support@covehomeschool.com`.

## Screens / Flows

### 1. Credential and live-state preflight

1. Confirm `LOOPS_API_KEY` is unset so it cannot override named-key selection;
   never print its value if it is set.
2. Verify `loops api-key --team cove-cli -o json` still resolves to team
   `Cove`.
3. Re-list themes and transactional emails immediately before creating
   anything. Save non-secret JSON snapshots under `.context/cov-41/`.
4. If either intended name already exists as a draft or published object,
   inspect and reconcile it instead of creating a duplicate.

Live state observed during brainstorming on 2026-08-03:

- `LOOPS_API_KEY` was unset and the keyring-backed `cove-cli` credential
  resolved successfully to team `Cove`.
- Exactly one `Cove` theme existed with ID
  `cmsdnxho301lh0j17qh8ltsre` and the approved COV-40 style contract.
- The only transactional emails were the two published COV-40 templates,
  `reset-password` and `password-changed`.

Execution must re-check this state because live Loops objects can change.

### 2. `account-invite`

Create or safely adopt the transactional object, capture its
`transactionalId`, `emailMessageId`, and `contentRevisionId`, and update the
draft message with the last-seen revision.

Message settings:

- Name: `account-invite`
- Subject: `{data.inviter_name} invited you to {data.account_name}`
- Preview text: none
- From: `Cove <support@covehomeschool.com>`
- Reply-to: unset; replies naturally return to the From address
- Format: Styled
- Theme: existing `Cove` theme, ID `cmsdnxho301lh0j17qh8ltsre`

LMX content order and exact source copy:

1. A single leading `<Style themeId="cmsdnxho301lh0j17qh8ltsre" />`.
2. A paragraph:
   `{data.inviter_name} has invited you to collaborate on ` followed by
   `<Strong>{data.account_name}</Strong>`.
3. A left-aligned themed button labeled `View invitation`, with
   `href="{data.invitation_url}"`.

Do not add a heading, image, decorative card, custom component, manual footer,
fallback expression, or extra invitation copy.

Run Guardian and review every warning. Send one message preview containing all
three variables to a real inbox. Use representative names and a harmless
absolute staging URL, not a real invitation secret. The received preview must
confirm:

- both variables interpolate in the subject;
- the inviter and emphasized account name render correctly in the body;
- the sender resolves to `Cove <support@covehomeschool.com>`;
- the button is visibly styled and its actual target is the complete supplied
  URL, not a literal data tag.

Publish only after those checks pass, then use a fresh transactional read to
confirm the published state and exact variable contract.

### 3. `cancellation-survey`

Follow the same revision-safe create or adopt, update, Guardian, preview,
publish, and fresh-read sequence.

Message settings:

- Name: `cancellation-survey`
- Subject: `Quick question`
- Preview text: none
- From: `Cove <support@covehomeschool.com>`
- Reply-to: `support@covehomeschool.com`
- Format: Plain
- Theme: none

LMX content order and exact source copy:

1. Paragraph: `Thanks so much for giving Cove a try.`
2. Paragraph: `Quick question, what made you cancel?`
3. Paragraph:
   `I'd really appreciate your feedback to help us make Cove better.`

Do not add a heading, button, link, survey form, styled callout, variable,
manual footer, or extra copy. Send one preview with no data variables to the
same real inbox. The received preview must confirm the intended Plain
presentation, the `support@` From address, and the explicit Reply-To header.

Publish only after those checks pass, then use a fresh transactional read to
confirm the published state and an empty data-variable contract.

### 4. Preview and publishing safeguards

- Use `loops email-messages preview`, never `transactional send`; do not pass
  any option that adds the recipient to the audience.
- Batch each template's complete test data into one preview. The Cove team has
  a shared limit of 100 previews per rolling 24 hours. If Loops returns 429,
  stop and resume after the window rather than retrying repeatedly.
- Treat LMX compilation errors and Guardian errors as publication blockers.
  Review warnings individually.
- If a revision conflict occurs, fetch the latest message and reconcile it;
  never overwrite concurrent work with `--force`.
- If an inbox, interpolation, button-target, format, From, or Reply-To check
  fails, revise and preview again before publishing.
- If publishing fails, leave the object as a draft and do not record it as
  published.

### 5. Handoff record

After both templates publish, replace the pending values in the Data Model
table with the confirmed transactional IDs. Record the preview recipient and
check date without retaining inbox content. Record fresh published-state reads,
the exact variable contracts, and final object inventory.

COV-44 consumes only the published IDs and contracts. Wiring app delivery,
storing IDs in `config/loops.yml`, and replacing mailer tests remain COV-44's
responsibility.

**Execution record (2026-08-03):**

- Preview recipient for both templates: the user's own real inbox (not
  retained here beyond confirming delivery and rendering).
- `account-invite`: subject interpolation, body copy, sender, Styled Cove
  presentation, left-aligned themed button, and full-URL button target were
  each confirmed by the user before publishing.
- `cancellation-survey`: Plain presentation, exact three-paragraph copy,
  sender, and `Reply-To: support@covehomeschool.com` header were each
  confirmed by the user (with a screenshot) before publishing.
- Guardian returned zero errors and zero warnings for both messages on every
  check, including the final pre-preview run.
- Final inventory: the `Cove` theme is unchanged from the Task 1 baseline;
  no mailing list, audience segment, campaign, workflow, or component was
  created. See "Discovered platform behavior and inventory notes" above for
  the disclosed throwaway test object and the unrelated concurrent-workspace
  billing objects observed in the same live team.

## Scope

**In:** Two complete LMX transactional templates; revision-safe Loops draft
management; reuse of the existing COV-40 theme for the Styled invite; Plain
format for the cancellation survey; Guardian checks; real-inbox subject, link,
format, sender, and Reply-To verification; publishing; confirmed IDs and
contracts documented for COV-44.

**Deferred:** All Rails/app integration and ID configuration (COV-44);
re-enabling team accounts or changing `config/jumpstart.rb`; authentication,
billing, and marketing templates; copy rewrites; new themes; logos, images,
components, contacts, audiences, mailing lists, campaigns, and workflows.

## Open Questions

None.

Resolved during design:

- Use Plain format for `cancellation-survey` so it reads like a personal email.
- Use a themed CTA button rather than a simple text link for
  `account-invite`.
- Preserve the existing English ERB/i18n copy without additions or rewrites.
- Apply the COV-40 theme only to `account-invite`; Loops themes are not
  available for Plain emails.
- Leave the invite Reply-To unset because its From address is already the
  support address; set the cancellation Reply-To explicitly because replies
  are the purpose of that email.

## More Info

COV-38 established the Cove team, verified `covehomeschool.com` sending domain,
and team-wide operational limits. COV-40 created the shared `Cove` theme and
the retained `cove-cli` key. COV-41 depends on both and blocks COV-44.

Transactional previews and sends do not require creating marketing contacts.
This workflow must not add preview recipients to the audience or change their
marketing state.
