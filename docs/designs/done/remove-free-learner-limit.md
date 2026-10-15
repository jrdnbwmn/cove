> Ticket: COV-120
> Branch: feature/cov-120-remove-free-learner-limit
> Plan created: docs/plans/remove-free-learner-limit.md

# Feature: Remove the Free learner limit

## Problem

Free stops at 2 learners, so a family with 3+ children either pays before Cove
has proven itself or leaves a child out of the plan. Larger families are hit
hardest by per-child pricing elsewhere. Gating should follow stakes, not family
size: every family should be able to put all its children in Cove on Free.

## Approach

Remove the Free limit and the whole read-only-learner concept from the app
(not just switch it off). Every plan gets the same soft cap, the family's
`learner_limit`, whose default rises from 10 to 15. Raise the cap only through
a superadmin, never below the default.

Messaging is **"Unlimited learners\*"** with a soft footnote. The cap is
not a hard product limit. It's a quiet way to keep co-ops and micro-schools
off a family plan, so all copy at the cap is "send us a quick note", never
"you've hit a limit". No copy at the cap names a plan.

Removed entirely: `Account::FREE_LEARNER_LIMIT`, `Account#learners_allowed`,
`#over_free_learner_limit?`, `#learner_pick_needed?`, `#keep_learners_on_free`
(+ `invalid_learner_pick`, + its memo in `reload`), `Learner#editable?`, the
`learners.kept_on_free` column, `Learners::KeptController` + `/learners/kept`
route + `learners/kept/edit` view, `learners/_free_limit_banner`, the learner
`show` action/route/view (it only existed for read-only learners),
`LearnerPickerComponent`'s `read_only_ids:` option, and every "read-only" /
Free-limit locale key.

## Acceptance Criteria

- A Free family can add a third learner (and up to 15 active learners) with no
  banner, upgrade prompt, or plan modal.
- At its `learner_limit` active learners, on Free or Premium, Add (header button
  and add tile) opens the soft limit modal with Close / Email us, and the modal
  names no plan.
- A family whose `learner_limit` a superadmin raised (e.g. 20) can add up to
  that number on Free, and pricing/modal/footnote show their number.
- A Free family with archived learners can restore one when under the cap;
  restore is blocked (soft line shown) only when it would exceed the cap.
- Downgrading a Premium family with 5 learners to Free leaves all 5 editable,
  with no banner, picker, or "Read-only" badge anywhere (learners list, class
  cards, class form).
- A Free family that was over the old limit before release sees every learner
  editable after release.
- Existing families with `learner_limit` below 15 are raised to 15; a
  superadmin can't save a value below 15.
- Pricing page shows "Unlimited learners\*" on both cards plus the soft
  footnote; no "Up to N learners" and no "More than N learners?" line.
- Billing page's Free description has no learner count.
- Terms of Service §6 and the §7 downgrade paragraph match the copy below,
  with no mention of read-only learners or a Free limit.
- `/learners/kept/edit` and `/learners/:id` return not found.

## Prototype

None.

## Data Model

No new models or tables.

**Migration 1 — raise learner limit default**
- `change_column_default :accounts, :learner_limit, from: 10, to: 15`.
- Backfill: every account with `learner_limit < 15` → 15. Down migration only
  restores the default to 10; it does not lower raised rows (intended: the cap is
  only ever raised).

**Migration 2 — remove kept flag**
- `remove_column :learners, :kept_on_free, :boolean, default: false, null: false`
  (reversible). Accepted risk: a few seconds during Render deploy where the old
  server may fail a learner save referencing the dropped column; a retry works.

Two migrations, one logical change each. Verify reversibility with
`bin/rails db:rollback:primary`; afterwards `git checkout --` the
cable/cache/queue schema dumps (see AGENTS.md).

**`Account`**
- Validation: `learner_limit` integer, `>= Account.default_learner_limit` (15).
- `can_add_learner?` → `learners.active.count < learner_limit` (fresh count
  query, same for every plan).
- Rewrite the AIDEV-NOTE: one soft cap for every plan; purpose is keeping
  co-ops and micro-schools off a family plan; families above it email us; no
  per-learner fee, Stripe quantity never changes.

**`Learner`**
- Drop `editable?` and `kept_on_free: false` from `archive!`.
- `within_learner_limit` keeps the family-row lock; adds one error key
  `:learner_limit` (count: `account.learner_limit`) in place of
  `learner_limit_free` / `learner_limit_premium`.

**`Enrollment`**
- `learner_is_active_and_editable` → `learner_is_active`: archived check only;
  drop the `:read_only` error.

**Fixtures**
- `accounts.yml`: complimentary family `learner_limit: 10` → `15`.
- `learners.yml`: drop `kept_on_free` lines and fixtures that only existed for
  read-only cases (check every test that references them).

**Superadmin (Madmin)**: no change; it already edits `learner_limit`, and a
value under 15 shows the standard validation error.

## Screens / Flows

**Learners list (`/learners`)**
**Primary tasks:** 1. See every learner at a glance 2. Add a learner 3. Edit, archive, or restore a learner
- No banner, no "Choose learners", no "Read-only" badge. Every active learner
  card opens Edit; ⋮ always offers Edit / Archive / Delete.
- Under the cap: Add (header + tile) opens the add form on any plan.
- At the cap: Add opens `_limit_modal` (existing layout). Single branch, no
  plan check, title count is `account.learner_limit`. Buttons: Close / Email us
  (mailto support, existing "More learners on Cove" subject).
- Archived tab, at the cap: one soft restore-blocked line; Restore unavailable.
- `_delete_content` Cancel always links to Edit.

**Classes (`/classes`, class form)**
- Class card: drop the "Read-only" badge on learner names.
- Class form: drop the `read_only_ids` computation.
- `LearnerPickerComponent`: remove `read_only_ids:`, `read_only?`,
  `disabled?`, and the "Read-only on Free" badge; update its tests, Lookbook
  preview, and the kitchen-sink example. Drop `learner_picker.read_only_on_free`.

**Pricing (`/pricing`)**
**Primary tasks:** 1. Compare Free and Premium 2. Start Free or get Premium
- Free card — description: "Everything you need to run school for the whole
  family. Free forever." Features: "Unlimited learners\*", "Unlimited
  classes", "Both parents".
- Premium card — description: "Everything in Free, plus new tools as they
  ship." Features: "Everything in Free", "Unlimited learners\*", "Both
  parents", "New Premium features as they're added".
- The asterisk is visual only (`aria-hidden`); the footnote is visible plain text.
- Footnote replaces the "More than N learners?" line: "\*Cove is built for
  families. Teaching more than %{learner_limit}? [Just let us know]." (mailto
  support).
- Rename `PlanPricingHelper#premium_learner_limit` → `pricing_learner_limit`:
  signed-in family's own `learner_limit` on any plan; otherwise
  `Account.default_learner_limit`.
- The signed-out cache key already includes `Account.default_learner_limit`, so
  the 10 → 15 change busts it.

**Billing (`/billing`)**
- Free card description: "Everything you need to run school for the whole
  family. Free forever." (no count; drop the pluralized key).

**Terms of Service**
- §6 Learner limits: "Every plan includes unlimited learners for a single
  family. When a family reaches 15 active learners, we ask you to contact us
  so we can raise the limit. Archived learners don't count."
- §7 downgrade paragraph: "If you move from Premium to Free, nothing is deleted
  and every learner stays editable."

**Key copy** (all use the family's `learner_limit`, shown here as 15)

| Where | Copy |
|---|---|
| Limit modal title | "Adding more than 15 learners?" |
| Limit modal body | "Cove is built for families, so we check in at 15. Send us a quick note and we'll raise it for you." |
| Limit modal buttons | Close / Email us |
| Restore-blocked line | "To restore a learner, archive one first or [send us a note] and we'll make room." |
| Save error (concurrent add) | "To add more than 15 learners, send us a quick note and we'll raise your limit." |
| Pricing footnote | "\*Cove is built for families. Teaching more than 15? [Just let us know]." |

**Leave as-is:** the dev typography `pricing_sample` string (demo text).

## Edge cases

1. Two parents add simultaneously at 14/15: family-row lock stays; the second
   save gets the soft error. Never exceeds the cap.
2. Family already above its cap (past superadmin change): all learners
   editable; Add opens the modal; Restore blocked until under the cap.
3. Superadmin enters < 15: standard validation error; not saved.
4. Premium → Free downgrade or re-subscribe: nothing changes for learners.
5. Families over the old Free limit on release: all editable immediately; old
   pick vanishes with the column. No migration message.
6. Stale `/learners/kept/edit`, `/learners/:id`, or a picker form submit: not
   found; nothing changes.
7. Archived learner can still never be added to a class.
8. Deploy-window failure on learner save (dropped column): accepted, retry works.
9. Family raised to 20: pricing footnote, modal, restore line, error all say 20.

## Tests

- One test per acceptance criterion: Free family adds a 3rd learner and up to
  the cap; modal on Free and Premium names no plan; raised limit on Free;
  restore under the cap / blocked at the cap; downgrade leaves learners
  editable; old over-limit family all editable; pricing / billing / ToS copy;
  stale routes 404; superadmin can't save < 15.
- Migration tests: backfill raises < 15 to 15 and leaves ≥ 15 alone;
  `kept_on_free` is gone.
- Delete: `learners_kept_test.rb`, and the banner / badge / read-only-show /
  picker `read_only_ids` tests across `learners_index_test`, `learners_test`,
  `learner_test`, `account_test`, `enrollment_test`, `course_test`,
  `courses_*_test`, `learner_picker_component_test`, system tests.

## Docs to update (same PR)

`docs/product/product-brief.md`
- Free vs Premium table, Learners row (both columns): "Advertised as unlimited;
  real cap is `learner_limit` (default 15, raisable per family by a superadmin)".
- Learners: replace the limit bullets with:
  - "Every plan has the same soft learner cap, `learner_limit` (default 15,
    raisable per family by a superadmin, never below the default). It's
    advertised as unlimited; families above it email us. The cap keeps co-ops
    and micro-schools off a family plan, so copy at the cap is soft and never
    names a plan."
  - "Only active learners count toward the cap. Creating or restoring a
    learner uses a slot; archived learners do not. At the cap, any plan sees
    "Email us". Restore remains unavailable while it would exceed the cap."
- Learners → On downgrade: replace the block with "On downgrade, learners
  don't change: none is deleted, and every learner stays editable."
- Classes: delete the "Read-only learners stay visible…" bullet, and drop
  "including read-only ones" from the `/classes` filter bullet.

`docs/product/ux-notes.md` → States and interactions, plan limits bullet:
- "Plan limits and plan-locked content (Premium-only, read-only after a
  downgrade)" → "Plan limits and plan-locked content (Premium-only)".
- "(Premium at its cap: "Contact us")" → "(at the learner cap, on any plan:
  a soft "Email us" — the cap is a check-in, not a wall)".

`AGENTS.md`: no change expected.

## Scope

**In:** everything above. Suggested plan checkpoints: (1) model + migrations +
fixtures, (2) learner and class screens + `LearnerPickerComponent`, (3)
pricing, billing, ToS copy, (4) product docs. After merge, `/close-out` updates
the component catalog (`LearnerPickerComponent` signature changed).

**Deferred (ticket Out of scope):**
- Any other gating change.
- Setup's Learners step (comes with the Setup feature). This ticket only
  ensures no Free limit or banner exists for it to inherit.
- Other plan-copy fixes not about learners. Exception: Jordan approved the full
  Free/Premium card copy above in this brainstorm.

## Open Questions

None.

## More Info

- Source: Notion slice "Remove the Free learner limit"; feature Learners → Free
  and Premium, How it works → Learner limits and Downgrade; Strategy: Free and
  Premium → Free limits.
- Decisions made in brainstorm that differ from the ticket (Notion should be
  synced to match): default cap 15 (ticket said 10); "Unlimited learners\*" +
  soft footnote instead of "Up to 10 learners"; soft "Email us" copy instead
  of "Contact us"; Free/Premium card content rewritten; `learner_limit` floor
  is the default (15).
- Premium has no Premium-only features built yet; the card copy is
  deliberately vague until the first one ships.
- If this slice grows, split the copy changes (pricing, billing, ToS) into
  their own issue.
