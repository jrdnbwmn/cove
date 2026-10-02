> Plan created: docs/plans/legal-and-about-pages.md
> Ticket: COV-92
> Branch: feature/cov-92-fill-out-extraneous-pages

# Feature: Legal and About pages (Terms, Privacy, Refund Policy, About)

## Problem
Signup, Stripe Checkout, and the checkout copy all bind users to Terms that are
blank; the Privacy Policy is partial (and wrong about Loops); there is no Refund
Policy page; and `/about` is an empty stub linked from every footer. Stripe live
activation and Google OAuth brand verification both require these pages to exist
and be easy to find.

## Approach
"Words + wiring":
- Draft full plain-language copy for Terms, Privacy, Refund Policy, and About.
  Not lawyer-reviewed — best-effort drafts.
- Legal body copy lives in ERB partials, not `en.yml` (long legal prose with
  headings/links is unmaintainable in YAML; app is English-only/US-only; matches
  Jumpstart convention). Short labels (titles, footer links) stay in `en.yml`.
- Enable the two Jumpstart `Agreement` entries (Terms, Privacy) with
  `prompt_when_updated: false` so "Last updated" dates render and future material
  changes can force re-acceptance by flipping one flag.
- New `/refunds` page; link it (and `/terms`) from the footer, sidebar account
  menu, pricing, checkout, cancel, and family-deletion copy.

## Acceptance Criteria
- `/terms`, `/privacy`, `/refunds`, `/about` all render full copy, publicly
  (signed out), with no layout errors.
- Terms and Privacy show "Last updated <ship date>"; Refunds shows its own
  hardcoded last-updated date; About shows none.
- A signed-in existing user is NOT redirected to the agreement accept screen.
- If an `Agreement` entry is missing, the page renders without the date line
  (no crash).
- Footer and sidebar account menu include a "Refunds" link.
- Pricing, checkout (both spots), cancel page, and family-deletion notice link to
  `/refunds`; checkout's "in accordance with our terms" links to `/terms`.
  Checkout links open in a new tab.
- Copy is consistent with `docs/product/product-brief.md` billing/family rules.
- Legal page headings render in the serif at weight 400 (no faux bold) —
  verified by screenshot.
- Tests cover each of the above.

## Prototype
None.

## Data Model
No new models, tables, or migrations. Uses existing
`users.accepted_terms_at` / `users.accepted_privacy_at` (set at signup by
`User::Agreements`).

Config change in `config/initializers/agreements.rb` — uncomment both entries:
- `id: :terms_of_service`, `title: "Terms of Service"`, `column: :accepted_terms_at`
- `id: :privacy_policy`, `title: "Privacy Policy"`, `column: :accepted_privacy_at`
- `updated:` the ship date (set at execution time)
- `prompt_when_updated: false` — Jumpstart's `require_accepted_latest_agreements!`
  only checks agreements with this true, so nobody is prompted.
- Add an `AIDEV-NOTE`: for a future material change, bump `updated` and set
  `prompt_when_updated: true` to make every user re-accept once.

Refund Policy is NOT an `Agreement` (never accepted standalone; binding via Terms).

Locale tweak: `public.terms.title` "Terms Of Service" → "Terms of Service". Add
`public.refunds.title` "Refund Policy" and footer label `refunds: "Refunds"`.

## Screens / Flows

### Shared legal layout
- New partial `app/views/public/_legal_page.html.erb`: readable centered column
  (`max-w-prose`), H1 title, optional "Last updated" line in
  `text-muted-foreground` (omitted when no date), body wrapped in `prose`.
- `prose` headings must be overridden to normal weight (Fabric Serif has only
  400; prose defaults headings to bold → faux bold). Section headings are H2
  (serif, app default); sub-points as bullet lists, not deeper headings.
- App-level views `app/views/public/terms.html.erb`, `privacy.html.erb`,
  `refunds.html.erb` render the shared partial. Terms/Privacy body text stays in
  `app/views/users/agreements/_terms_of_service.html.erb` and
  `_privacy_policy.html.erb` (also reused by Jumpstart's re-accept screen).
  Refund body can live inline in `refunds.html.erb` or a `public/_refund_policy`
  partial.
- `PublicController#refunds` action (app-level controller replaces the engine's
  — keep the AIDEV-NOTE accurate about the action list) and `get :refunds` in the
  `scope controller: :public` block of `config/routes/jumpstart.rb`.

### About page (`app/views/public/about.html.erb`)
Same readable column, H1, no date line, ~4 short company-voiced sections, ending
"Questions? Email support@covehomeschool.com". Text only.

### Links
| Where | Change |
|---|---|
| `application/_footer` | Add **Refunds** after Terms |
| `application/_sidebar_account_menu` | Add **Refunds** after Terms |
| `pricing/show` + `checkouts/show` (2 spots) | `no_refunds` → `_html` key with appended "See our refund policy." link |
| `checkouts/show` consent line | "in accordance with our **terms**" → link to `/terms` |
| Cancel page + family-deletion notice (`AccountDeletionHelper#cancellation_end_notice`) | `active_until_no_refund(_undated)` → `_html` keys with a "Refund policy" link |

Checkout links open in a new tab (`target: "_blank"`, as signup already does);
all others same tab. Every caller of a renamed key must be updated.

## Document Content

Tone: plain language, calm, short sections, no all-caps legalese (use bold
where emphasis is legally expected). Operating party is just **"Cove"**
(not yet a legal entity; no personal name), 307 N 990 E, Salem, UT 84653,
support@covehomeschool.com — pull from `Jumpstart.config` where practical.

### Terms of Service
1. About these terms — Cove, address, support email; signing up = agreeing.
2. Who can use Cove — US only, 18+, parent/legal guardian of students added.
   Family use only; not co-ops, micro-schools, or schools.
3. Your family account — one or two parents, both admins, one owner; responsible
   for credentials; Google sign-in.
4. Student information — you confirm authority to add your children's info;
   children don't have logins today.
5. Plans & billing — Free and Premium; flat per family; auto-renews monthly or
   yearly; Stripe processes payments; price changes with notice, effective at next
   renewal; taxes where applicable.
6. Student limits — Premium is unlimited for a single family subject to
   reasonable use; unusually large families asked to contact us. Do NOT state
   the numeric cap.
7. Cancellation, downgrades & refunds — summary + link to Refund Policy; on
   downgrade nothing is deleted, extra students become read-only.
8. AI features — optional; everything works without them; suggestions only,
   never acts without parent approval; can be wrong, parent reviews; family and
   children's data never used to train AI models.
9. Not legal or educational advice — general information only; parents are
   responsible for complying with their state's homeschool laws.
10. Your content — you own it; limited license to us to operate Cove.
11. Acceptable use — no illegal use, abuse, scraping, reselling.
12. Changes to Cove and these terms — material changes announced by email or
    in-app.
13. Ending your account — delete anytime; we may suspend for violations.
14. Disclaimers — provided "as is".
15. Limitation of liability — capped at amount paid in prior 12 months, or $50
    if never paid.
16. Governing law & disputes — Utah law, Utah County courts, small claims
    allowed, no arbitration clause.
17. Contact.

### Privacy Policy (rewrite; keep good parts of current draft)
1. Scope — US users.
2. What we collect — account info; Google sign-in data (name, email, profile
   photo); family members & invitations; student info parents enter; billing
   (Stripe holds card numbers; we keep only brand/last 4); support messages;
   technical data (IP, browser, logs).
3. **Children's information** (prominent) — children don't have accounts;
   parents enter and control everything; never sold, never used for ads, never
   used for AI training; parents can view/edit/delete anytime; before student
   logins launch we'll update this policy, and only parent-created,
   parent-controlled child logins will be allowed.
4. How we use information.
5. AI features — optional; providers receive only what a feature needs; only
   providers whose contracts forbid training on your data; providers named here
   when AI launches.
6. Google user data — exactly what we receive and how it's used; statement that
   Cove's use complies with the **Google API Services User Data Policy**.
7. Who we share with — Stripe (payments); **Loops (all account and billing
   emails, plus marketing if opted in)** — fixes current draft's error;
   Honeybadger (errors); Render (hosting); legal requests; business transfer.
   **Never sold or shared for targeted advertising.**
8. Cookies — essential only (sign-in, security); no analytics or ad trackers.
9. Retention & deletion.
10. Security.
11. Your choices & rights — access, correct, delete, marketing opt-out, honored
    for all US users regardless of state.
12. Changes to this policy.
13. Contact.

### Refund Policy
- How to cancel — Billing settings; any parent can.
- What happens — Premium continues until end of paid period, then Free; nothing
  deleted.
- No refunds or credits for unused time or partial periods; yearly → monthly
  takes effect at renewal, no proration.
- Ends immediately with no refund — canceling while a payment is past due;
  deleting the family.
- Exceptions — duplicate charges / billing errors refunded if reported within
  **30 days**; otherwise at our discretion; where law requires a refund, we
  comply.
- Contact.

### About (company voice)
- What Cove is — a calm "chief of staff" for homeschool families that makes
  running a homeschool feel lighter.
- What it helps with — plan, know what to do today, keep records (mirrors the
  homepage's three value points; don't promise unbuilt features).
- What we believe — calm/clear design; parent decides (AI optional); works with
  any homeschooling approach.
- Who it's for — US homeschool families, K–12.
- Contact.

## Edge Cases
- Missing `Agreement` entry → date line omitted, no crash (tested).
- Signed-in user not redirected to the agreement accept screen (tested).
- Renaming locale keys to `_html` — update every caller (pricing, checkout ×2,
  cancel helper) or text duplicates/disappears; tests assert the refund link on
  each page.
- Existing tests asserting the old exact "No refunds…" wording — find and
  update, don't delete.
- Faux-bold serif headings under `prose` — override weight; screenshot check.
- Copy must match product-brief billing rules (no refunds; Premium until period
  end; past_due cancel ends immediately; family deletion ends immediately; no
  deletion on downgrade; student cap as "reasonable use"; both parents manage
  billing). Checked in `/review-changes`.
- Time-bound statements — `AIDEV-NOTE` at top of each legal partial listing
  triggers to revisit: student logins, AI launch (name providers), forming an
  LLC (update operating party), adding analytics, adding any new data processor.

## Scope
**In:** Terms, Privacy (rewrite), Refund Policy (new page + route + action),
About copy, shared legal layout partial, Agreement config enabled
(no prompt), footer + sidebar Refunds links, refund/terms links in pricing,
checkout, cancel, and family-deletion copy, tests.

**Deferred:**
- Lawyer review of all drafts.
- Policy updates when student logins ship (COPPA mechanics), when AI launches
  (name providers), when the LLC forms, or if analytics is added.
- Separate cookie policy (not needed — essential cookies only).
- State-by-state privacy-rights sections.
- Post-merge manual steps (Jordan):
  - Stripe Dashboard → Settings → Public details: Terms URL (required for
    `consent_collection` in live mode), Privacy URL, Refund policy URL.
  - Google Cloud Console → OAuth consent screen: homepage/privacy/terms links,
    authorized domain covehomeschool.com, submit for brand verification.

## Open Questions
None.

## More Info
- Google sign-in uses only non-sensitive `email`/`profile` scopes (omniauth
  google-oauth2 default; see `lib/jumpstart/lib/jumpstart/omniauth.rb`), so only
  brand verification is needed — requires a public homepage and a same-domain
  privacy policy that discloses Google data use and references the Google API
  Services User Data Policy.
- Production email delivery is `:loops` (`config/environments/production.rb`),
  so Loops processes all transactional email, not just marketing.
- Stripe Checkout sets `consent_collection: {terms_of_service: :required}`
  (outside staging) in `lib/jumpstart/app/controllers/checkouts_controller.rb`.
- `docs/product/product-brief.md` lists "Terms of Service and refund policy
  pages" as an open question blocking Stripe live activation — update that
  line when this ships.
