> Ticket: COV-53
> Branch: feature/cov-53-mailing-lists-and-audiences
> Plan created: docs/plans/cov-53-mailing-lists.md

# Feature: Mailing lists and audience configuration in Loops

## Problem

Cove has no Loops mailing-list structure, so future campaigns and workflows
cannot target the marketing audience by a user-controlled communication
category. The Loops Preference Center also has no public list for subscribers
to understand or manage.

## Approach

Create one deliberately minimal public mailing list in the existing Cove Loops
team. Configure it in the Loops dashboard, verify it through the read-only CLI
and a contact-free Preference Center preview, and record the generated list ID
and findings in this document during execution.

COV-40's credential checkpoint is an operational prerequisite: it creates the
dedicated local `cove-cli` credential for CLI-driven Loops administration. The
credential remains in the local keyring, is never written to the repository or
transcript, and is reused by COV-53 only for read-only verification. Before any
dashboard or other CLI work, `loops api-key --team cove-cli -o json` must report
`teamName: Cove`. If the credential is unavailable or resolves to another team,
stop; do not fall back to the production server credential.

The list will be:

| Field | Value |
| --- | --- |
| Name | `Cove updates` |
| Description | `Receive occasional product news and homeschooling resources by email.` |
| Visibility | Public (`isPublic: true`) |

One public list matches Cove's one current marketing channel. Additional lists
would invent segmentation before a real campaign requires it. Public visibility
lets subscribers understand and control this category in Loops' Preference
Center. Internal targeting refinements should use filters or segments rather
than subscriber-facing lists.

No company icon will be uploaded. Cove does not yet have an approved brand asset
in the repository; Preference Center branding is deferred until the planned
rebrand rather than using the existing Jumpstart placeholder.

## Acceptance Criteria

- [ ] One `Cove updates` list exists in the Cove Loops team with the approved
      description.
- [ ] Before any other work,
      `loops api-key --team cove-cli -o json` reports `teamName: Cove`.
- [ ] `loops lists list --team cove-cli -o json` returns the list's ID, name,
      description, and `isPublic: true`.
- [ ] The contact-free Preference Center preview renders the public list's name,
      description, and subscription control correctly.
- [ ] The sending footer contains `Cove` and the physical business address
      `307 N 990 E, Salem, UT 84653`.
- [ ] The generated list ID and verification findings are recorded in this
      document.
- [ ] The Loops Audience count is unchanged; this ticket creates no contacts.
- [ ] No email is sent while configuring or verifying this ticket.

## Prototype

None. Loops owns the dashboard and Preference Center UI; Cove does not customize
their layout in this ticket.

## Data Model

No Rails models, migrations, or application configuration change. The only new
record is the external Loops mailing list described above. Its Loops-generated
ID will be recorded under Findings after creation.

Contact membership is intentionally empty for this ticket. COV-48 established
that only users who explicitly opt in become Loops contacts. Transactional
auth/security recipients remain outside the Audience because those sends keep
`addToAudience: false`; transactional delivery is independent of marketing
consent and `Cove updates` list membership.

COV-51 owns adding the generated list ID to `config/loops.yml` and using it in
contact-sync payloads. Keeping that change out of COV-53 preserves this ticket's
no-app-code boundary.

## Screens / Flows

1. Run `loops api-key --team cove-cli -o json` and confirm it reports
   `teamName: Cove`. If `cove-cli` is unavailable or resolves to another team,
   stop. Do not use the production server credential instead.
2. Record the current Loops Audience count before making changes.
3. Open Loops **Settings -> Lists** and confirm that an equivalent list does not
   already exist. If it does, inspect and correct it rather than creating a
   duplicate.
4. Create or update `Cove updates` with the approved description and set its
   visibility explicitly to **Public**.
5. Leave the company icon unset.
6. Open Loops' contact-free Preference Center preview and confirm that the list
   name, description, and subscription control render correctly.
7. If Loops offers no contact-free preview, stop and report the acceptance-
   criteria conflict. Do not create a temporary contact to manufacture a URL.
8. Verify the existing company/footer configuration still shows `Cove` and
   `307 N 990 E, Salem, UT 84653`. Do not alter unrelated sender, domain, or
   email-branding settings.
9. Run `loops lists list --team cove-cli -o json` and verify the stored name,
   description, generated ID, and `isPublic: true`.
10. Confirm the Audience count is unchanged and record the results under
   Findings.

## Edge Cases

- **Equivalent list appears before execution.** Reuse it and correct only the
  fields this design specifies. Never create a duplicate list.
- **`cove-cli` is missing or resolves to another team.** Stop before opening the
  dashboard or running any other CLI command. Do not create a credential in this
  ticket and do not fall back to the production server credential.
- **Preference Center has no contact-free preview.** Stop without creating a
  contact. The rendering criterion and the no-contact criterion conflict until
  the verification method is revised.
- **Audience count changes.** Stop and investigate. Do not modify or delete
  contacts as cleanup for this ticket.
- **Footer identity differs.** Correct only the specified Cove company name and
  physical address. Leave sender and domain configuration unchanged.
- **Dashboard and CLI disagree.** Treat the API-backed CLI output as the saved
  state and resolve the mismatch before recording completion.
- **Configuration is saved but the list ID changes.** Record only the final,
  verified ID; downstream tickets must never reference a superseded ID.
- **Send budget.** Configuration and previewing send no email, so COV-53 should
  consume none of the shared 4,000-send rolling 30-day allowance.

## Scope

**In:** one public Loops mailing list; approved list description; deliberate
`isPublic` setting; contact-free Preference Center verification; existing
footer/company-address verification; Audience-count verification; findings and
list-ID documentation.

**Deferred:** Cove company-icon branding; additional mailing lists; filters and
segments; application configuration; contact creation or syncing (COV-51);
campaign content (COV-56); workflow content (COV-55); changes to the consent
model or settings UI (COV-49/COV-50); email sends.

## Open Questions

1. **Does the Loops dashboard provide a contact-free Preference Center preview
   in Cove's current account?** The execution flow checks this directly. If it
   does not, work stops rather than creating a test contact.
2. **When a contact unsubscribes from a public mailing list in the Loops
   Preference Center, can that same contact later rejoin it themselves? If so,
   what webhook event is emitted?** Current Loops documentation says Cove/the
   team cannot restore that list membership through the API or dashboard, while
   separately documenting audience-level resubscription. It does not document
   whether the contact has a subscriber-controlled rejoin path. COV-53 can
   proceed without this answer because it creates no contacts and implements no
   subscription behavior. COV-49 and COV-51 must not finalize or ship reversible
   `user_loops` behavior until Loops confirms the subscriber-controlled rejoin
   capability and resulting webhook. The support answer may later change
   COV-49's protected-state behavior and COV-51's allowed sync behavior; it does
   not change COV-53's one-list configuration.

## Findings

To be completed during execution:

| Check | Result |
| --- | --- |
| Audience count before | Pending |
| List ID | Pending |
| CLI list response | Pending |
| Preference Center preview | Pending |
| Company/footer address | Pending |
| Audience count after | Pending |

## More Info

- COV-48 already chose one marketing channel, one public `Cove updates` list,
  and contact creation only after explicit opt-in. This design implements that
  decision rather than reopening it.
- COV-38 established one shared Loops team and one verified sending domain,
  `mail.covehomeschool.com`, with separate production and staging API keys but
  no audience isolation. COV-51's `contact_sync_enabled` environment guard—not
  a staging list—prevents staging users from entering the production Audience.
- COV-38 already set the Cove company name and physical address in Loops. This
  ticket verifies those values rather than recreating them.
- Transactional auth/security recipients remain outside the Loops Audience and
  do not consume the free plan's subscribed-contact allowance because those
  sends keep `addToAudience: false`. Their delivery is independent of marketing
  consent and `Cove updates` membership. Transactional and marketing sends share
  the same 4,000-send rolling 30-day allowance, but this configuration ticket
  sends no email.
- The Loops CLI currently exposes list retrieval only. List creation, editing,
  visibility, company-icon configuration, and footer verification are
  dashboard-owned steps; `loops lists list` provides the final read-only check.
- COV-40 owns creation of the dedicated local `cove-cli` operational key; its
  credential checkpoint is therefore an operational prerequisite for COV-53.
  The key remains only in the local keyring and is reused here solely for
  read-only verification; COV-53 neither creates it nor persists its value.
- COV-49 distinguishes audience-level and list-level Loops opt-outs:
  `user_loops` and `mailing_list_unsubscribe`. COV-49 and COV-51 must not
  finalize or ship reversible `user_loops` behavior until Loops confirms a
  valid subscriber-controlled rejoin flow and resulting webhook. While that
  capability is unconfirmed, `mailing_list_unsubscribe` remains protected and
  COV-51 must not claim successful `Cove updates` list re-subscription.
- COV-52 maps `contact.unsubscribed` to `user_loops` and
  `contact.mailingList.unsubscribed` to `mailing_list_unsubscribe`.
