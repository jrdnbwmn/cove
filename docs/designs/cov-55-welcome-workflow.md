> Ticket: COV-55
> Branch: feature/cov-55-welcome-sequence
> Plan created: docs/plans/cov-55-welcome-workflow.md

# Feature: First lifecycle workflow — welcome sequence

## Problem

Contacts sync, events emit, and a mailing list exists, but no automated
lifecycle email has ever been sent. The event-triggered path — app emits
`user_signed_up` → Loops workflow fires → email lands in an inbox — is entirely
unproven.

It also cannot be proven end to end today. **Production has never been
provisioned**: `render.yaml`'s production block is still commented out and there
is no `cove-production-db`. The emission gate is `production? &&
contact_sync_enabled?` (`LoopsContactGate`), so no environment that exists can
emit an event from app code.

This ticket proves everything provable without production. Live confirmation
moves to the launch ticket (JOR-1).

## Approach

Author one Loop in the Cove Loops team, triggered by COV-54's `user_signed_up`
event, containing a single welcome email on COV-40's shared `Cove` theme. Fire
the event by hand with `loops events send` against one deliberately created test
contact, and verify delivery, rendering, theme continuity, timing, footer, and
unsubscribe in a real inbox. Then delete the test contact and deactivate the
workflow.

This is a **Loop** (lifecycle automation), not a campaign — it is triggered by a
real product state change, which is the pattern the
`loops-email-sending-best-practices` references endorse over arbitrary
schedules. Those references also note that a welcome loop plus essential
transactional email is the recommended warm-up path for a new sending domain,
before broad campaigns — which is a further argument for COV-55 preceding
COV-56.

### The copy is provisional, in one specific sense

`docs/product/product-brief.md` and `docs/product/strategy-brief.md` are both
empty, so there is no product story to tell. The email says nothing about what
Cove does. It is **not** throwaway: it confirms the subscription and sets
expectations, which is true on the day it sends and stays true after product
copy is added. The launch ticket adds a CTA and the product story.

### No name personalization — a safety property, not just a limitation

`LoopsContactSynchronizer#subscribed_attributes`
(`app/services/loops_contact_synchronizer.rb:71`) sends exactly `email`,
`userId`, `subscribed`, and `mailingLists`. No `firstName` reaches Loops.
Adding it is roughly a one-line change to COV-51's synchronizer and is out of
scope here (this ticket ships no app code).

Beyond scope, there is a positive reason to leave it out: Loops warns that a
**missing personalization value can prevent a loop email from sending**. A
`{contact.firstName}` reference against a contact that has no first name is a
live send-blocker, not a cosmetic fallback problem. Greeting nobody by name is
the safer construction.

It is also the more consistent one. COV-40's transactional emails greet by email
address. A welcome email saying "Hi Jordan" next to a password reset saying
"Hello jordan.d.bowman@gmail.com" is a worse inconsistency than no name at all.

### One sender domain, not a marketing/transactional split

Considered and rejected. The deliverability reference is explicit: prefer one
well-established sending domain, avoid fragmenting traffic across several, and
where communication types must be separated, separate them with **lists and
preference management** rather than domains. Cove already does exactly that —
one verified domain, `mail.covehomeschool.com` (COV-38), and one public
`Cove updates` list (COV-53).

The welcome email therefore uses the same From and reply-to as COV-40's
transactional emails.

## Workflow structure

```
Trigger: event `user_signed_up`
  └─ SendEmailAction: "Welcome to Cove"
```

Mailing list association: **Cove updates** (`cmsdo8ncl02wc0j0j4rxwhy4l`).

### Why the mailing-list association matters

`loops workflows create` accepts `--mailing-list-id`, and the choice determines
what the unsubscribe link does — which reaches directly into COV-52:

| Association | Unsubscribe scope | Loops event | COV-52 records |
| --- | --- | --- | --- |
| **Cove updates** (chosen) | list-level | `contact.mailingList.unsubscribed` | `mailing_list_unsubscribe` |
| none | audience-level | `contact.unsubscribed` | `user_loops` |

Both are handled by COV-52 and both are protected reasons that disable COV-49's
in-app toggle, so the app behaves correctly either way. The list association
wins because the subscriber sees a **named category they understand and can
control** in the preference center — which is the entire reason COV-53 made the
list public rather than private.

### No timer node

Best practice is to send a welcome immediately, and a `TimerAction` between
trigger and send would be exactly the "arbitrary schedule" the references warn
against. The shipped structure is trigger → send.

**`TimerAction` therefore remains unproven.** Its real behaviour — minimum
granularity, whether it schedules in the contact's timezone, whether a short
delay rounds up — is unknown and should be established by the first ticket that
genuinely needs a multi-step sequence. Recorded here so that ticket knows it is
starting from zero.

Consequently the ticket's "timing between steps behaves as designed" criterion
is reinterpreted: with one email and no timer, the evidence is the **elapsed
time from firing the event to the email arriving**, recorded during execution.

## Email content

| Field | Value |
| --- | --- |
| Subject | `Welcome to Cove` |
| Preview text | `A quick note on what to expect in your inbox.` |
| From | COV-40's transactional sender, on `mail.covehomeschool.com` — exact local part confirmed in Loops at execution |
| Reply-to | `support@covehomeschool.com` |
| Theme | `Cove`, `cmsdnxho301lh0j17qh8ltsre` |
| Format | styled, with the generated plain-text alternative verified before activation |

Body:

> # Welcome to Cove
>
> Thanks for creating your account — we're glad you're here.
>
> You also opted in to Cove updates, so you'll hear from us occasionally with
> product news and homeschooling resources.
>
> That's it for now. We'll be in touch when there's something worth your time.
>
> — The Cove team

Followed by Loops' generated footer, carrying the preference-center unsubscribe
link and the physical address `307 N 990 E, Salem, UT 84653`.

Subject is 15 characters, inside the reference guidance of under 50 and roughly
ten words. Preview text is set deliberately rather than left empty — COV-40 left
it empty for transactional email, but an empty preview lets the inbox show the
start of the body instead, which wastes the second line of the listing.

### Three deliberate properties of this draft

**No CTA button.** There is nothing to send anyone to: production does not
exist, and there is no product story to act on. Every link is a thing to verify
now and change at launch. This departs from the "obvious CTA" heuristic
knowingly rather than by oversight; the launch ticket adds it.

**No images and no body links**, so the images-blocked criterion and the
plain-text alternative are satisfied structurally rather than by luck.

**The second paragraph is only true because of COV-54's consent gate.** It
asserts the reader opted in, which holds because the trigger fires exclusively
for registration-sourced consenting signups
(`LoopsContactSyncJob` enqueues `LoopsEventJob` only when
`marketing_opt_in_source == "registration"`). If the trigger is ever broadened
to list subscription, that sentence becomes **false** for a settings-toggle
opt-in six months later. Anyone changing the trigger must change this copy.

## Acceptance Criteria

- [ ] Workflow exists in Loops, its structure recorded here, including which
      parts are reproducible via `loops workflows` / `loops workflows nodes` and
      which are dashboard-only
- [ ] Firing `user_signed_up` via `loops events send` against a consenting test
      contact triggers the workflow
- [ ] The welcome email arrives in a real inbox and renders correctly, including
      with images blocked and in the plain-text alternative
- [ ] Elapsed time from event to delivery is recorded
- [ ] Theme matches COV-40 (`cmsdnxho301lh0j17qh8ltsre`)
- [ ] Physical address present in the footer
- [ ] The unsubscribe link works and Loops records the opt-out, confirmed via
      `loops contacts find`
- [ ] The test contact is deleted; Audience count recorded before and after and
      returns to its starting value
- [ ] The workflow is deactivated pending launch, so provisional copy cannot
      reach real signups
- [ ] No campaign, additional list, additional theme, or other unrelated Loops
      object is created

## Prototype

None. Loops owns the workflow builder and preference-center UI.

## Data Model

**No Rails models, migrations, configuration, or app code of any kind.** This
ticket changes nothing in the repository except this document.

External Loops objects:

| Object | ID | Notes |
| --- | --- | --- |
| `Cove` theme | `cmsdnxho301lh0j17qh8ltsre` | Existing, COV-40. Reused unchanged |
| `Cove updates` list | `cmsdo8ncl02wc0j0j4rxwhy4l` | Existing, COV-53. Associated with the workflow |
| Welcome workflow | recorded during execution | New |
| Welcome email message | recorded during execution | New |
| Test contact | `cov55-verification` | Temporary. Deleted at the end |

## Screens / Flows

### Order of operations

The order is load-bearing. `POST /v1/events/send` **creates a contact if none
exists** (COV-54). Firing the event before the contact exists produces a
half-formed contact with no list membership and no `subscribed` value we set —
precisely what COV-54's chain-don't-race design exists to prevent.

1. **Preflight.** `loops api-key --team cove-cli -o json` reports
   `teamName: Cove`; stop if it does not, and do not fall back to the production
   server credential. Record the Audience count. Confirm `loops workflows list`
   is empty. Confirm the configured From address on `mail.covehomeschool.com`.
2. **Create the test contact deliberately** — `loops contacts create`, real
   inbox, `subscribed: true`, on `Cove updates`. Never implicitly via an event.
3. **Fire `user_signed_up` once** to teach Loops the event name. No workflow
   exists yet, so nothing sends. Confirm it now appears in
   `loops event-patterns list`.
4. **Author** the workflow, the LMX email, and the sending settings. Run
   Guardian and treat compilation errors and Guardian failures as blockers.
5. **Preview** for rendering, theme, and plain-text checks —
   `loops email-messages preview` creates no contact and consumes no send from
   the 4,000-per-30-days allowance.
6. **Activate, then fire the event again** to trigger for real. Record the
   elapsed time from event to inbox.
7. **Unsubscribe last.** Click the footer link, then confirm with
   `loops contacts find`.
8. **Clean up.** Delete the test contact, confirm the Audience count returns to
   its starting value, and deactivate the workflow.

### Test contact identity

`userId` is **`cov55-verification`** — deliberately non-numeric. Real `userId`s
are `User#id` rendered as a numeric string (COV-48 Decision 5), so a non-numeric
value can never collide with a future real user. Costs nothing, removes a class
of surprise.

Manual fires **omit** `--idempotency-key`. The app's key is
`SHA256("user_signed_up:<user_id>")`, and reusing a key inside Loops' roughly
24-hour window returns 409, which `LoopsClient#send_event` treats as success —
so a duplicate key would silently fire nothing and look like a broken trigger.

## Edge Cases

| Case | Behaviour |
| --- | --- |
| The unsubscribe check is effectively one-shot for that address | COV-53's open question 2 recorded that Loops may not allow restoring a list membership via API or dashboard. Deleting and recreating the contact *should* clear it — unsubscribe is contact-level and suppression is a separate email-keyed store (COV-48 Decision 5) — but that is inference, not verification. **Every rendering check passes before anything is clicked.** |
| Trigger picker will not offer `user_signed_up` | `loops event-patterns list` is currently empty; Loops has never received this event. Step 3 exists to fix that. If the picker still refuses after a successful fire, **stop and report** — do not substitute a list-subscription trigger, which would make the email's second paragraph false |
| Workflow re-entry rules | Unknown whether a contact may enter a Loop more than once. Determined during authoring and recorded under Findings; it governs whether verification can be re-run against the same contact |
| Preview does not render the real footer | Previews verify layout, theme, and plain text. The footer's unsubscribe link and physical address are only genuinely verified by the real triggered send in step 6 |
| Send budget | Negligible. One or two sends against 4,000 per rolling 30 days, shared with transactional (COV-38) |
| Free-plan contact ceiling | One temporary contact against 1,000. Audience starts at 0 |
| Deactivation | Deactivate, never delete. The launch ticket reactivates this workflow |
| Scope creep in the Loops dashboard | Create no campaign, no additional list, no second theme, no unrelated object. COV-53 held this line and so does this ticket |

## Scope

**In:** one Loop authored and verified; its email content in LMX on COV-40's
theme; a manually fired event proving the trigger; rendering, theme, footer,
timing, and unsubscribe verification in a real inbox; a record of which parts of
a workflow are CLI-reproducible; test-contact cleanup; deactivation pending
launch.

**Deferred / out:**

- **App code of any kind.** COV-54 already emits the event.
- **Live production verification** — JOR-1. The app-emitted event, the
  non-consenting-signup negative case, and COV-52's reconciliation of the
  unsubscribe into app state all require a production app and database.
- **OAuth consent capture** — its own ticket. OAuth signups capture no marketing
  consent, so they create no contact and can never receive this email.
- **Final copy and a CTA** — JOR-1.
- **Additional emails in the sequence.** One email that ships and is measured
  beats a five-email sequence still being written.
- **`firstName` on the Loops contact** — COV-51's surface.
- **`TimerAction` behaviour** — unproven, see Workflow structure.
- **Broadcast campaigns** — COV-56.

## Open Questions

1. **Can a contact enter a Loop more than once?** Determined during authoring.
   It decides whether the verification can be repeated against the same test
   contact or needs a fresh identity each run.
2. **Is workflow activation dashboard-only?** The CLI has no activate verb and
   no trigger flag — `workflows create` takes only name, description, and
   mailing-list id, and `workflows update` only name and description. Strongly
   suggests trigger and activation are dashboard-owned, but it is confirmed
   during execution and written up under Findings, because it determines whether
   this document can be a re-creation recipe or only a description.

## Findings

To be completed during execution.

| Check | Result |
| --- | --- |
| `loops api-key --team cove-cli` | |
| Audience count before | |
| Workflow ID | |
| Email message ID | |
| `user_signed_up` in `event-patterns list` | |
| CLI-reproducible vs dashboard-only | |
| Workflow re-entry rule | |
| Elapsed time, event to inbox | |
| Styled / images-blocked / plain-text rendering | |
| Theme continuity with COV-40 | |
| Physical address in footer | |
| Unsubscribe link + `contacts find` result | |
| Test contact deleted | |
| Audience count after | |
| Workflow deactivated | |

## More Info

- **Ticket open question 2 (retroactive firing) is already answered by merged
  code.** `LoopsContactBackfillJob` calls `synchronizer.sync` directly rather
  than going through `LoopsContactSyncJob`
  (`app/jobs/loops_contact_backfill_job.rb:27`), so a backfill structurally
  cannot enqueue `LoopsEventJob`. The welcome sequence cannot fire for an
  existing account.
- **Ticket open question 3 (Google OAuth) is answered, and the answer is a
  product gap.** The marketing checkbox lives only in the Devise registration
  form (`app/views/devise/registrations/new.html.erb:78`). The Google button is
  a separate `button_to` form in `app/views/devise/shared/_links.html.erb:10`,
  rendered on both the sign-up and sign-in pages, so the checkbox never rides
  along. OAuth signups capture no consent, create no contact, and can never
  receive lifecycle mail — and a later settings toggle deliberately emits no
  event. No Loops-side trigger can fix this; it needs app code, in its own
  ticket.
- **Loops adds the preference-center unsubscribe path to marketing email
  automatically** (COV-48 Compliance), so no unsubscribe markup is authored by
  hand.
- **Transactional sends keep `addToAudience: false`** (COV-37, COV-39). Nothing
  here changes that, and no event is emitted from any transactional path.
- **Loops' 409 idempotency window is roughly 24 hours** (COV-50) — the reason
  manual fires omit the key.
- **Rate limit is 10 requests/second per team**, shared across transactional and
  marketing (COV-37, COV-38). Irrelevant at this volume.
- **COV-52's webhook points at production only** — one endpoint per Loops
  account (COV-48 Decision 2). This is why unsubscribe reconciliation into app
  state cannot be verified here, only the Loops-side opt-out. COV-48 already
  established that Loops honours its own unsubscribe regardless of what Cove
  believes, so the compliance-critical half **is** proven by this ticket; only
  Cove's mirror of that state is deferred.
