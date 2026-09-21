> Plan created: docs/plans/cov-83-v1-marketing-page.md
> Ticket: COV-83
> Branch: feature/cov-83-create-v1-marketing-page

# Feature: v1 marketing homepage

## Problem

A signed-out visitor to Cove lands on Jumpstart's stock "Welcome to Jumpstart"
page. The app has no front door of its own — the first thing a prospective
homeschooling parent sees is boilerplate from the starter template, advertising
a different product.

This ticket replaces that page with a deliberately simple single-screen
marketing homepage. Full marketing pages come later; this is the minimum that
makes the root URL Cove's.

## Approach

One screen at `root_path`, composed of three stacked sections inside the
signed-out shell — a marketing variant of the existing navbar (see Decision 4),
and the standard footer:

1. **Hero** — headline, subhead, one primary CTA to registration.
2. **Three value points** — short, placeholder copy describing the
   "chief of staff for your homeschool" positioning.
3. **Pricing** — the existing Free and Premium plan cards, reused verbatim.

No new ViewComponents. `PlanCardComponent`, `ButtonComponent`, and the existing
`pricing` Stimulus controller cover everything.

### Three structural decisions

**1. `PublicController` gets an app-level override.**
The pricing cards need `@monthly_plans` / `@yearly_plans`. `PublicController`
currently lives only in the Jumpstart engine
(`lib/jumpstart/app/controllers/public_controller.rb`). Rails autoloads the
`app/` copy in preference to the engine's, and the override **replaces** rather
than extends — so the new `app/controllers/public_controller.rb` must carry all
five existing actions (`index`, `about`, `terms`, `privacy`, `reset_app`) with
their current bodies, plus plan loading in `index`.

This is the established pattern in this repo, not a new one:
`accounts_controller.rb`, `account_users_controller.rb`,
`account_invitations_controller.rb`, and `errors_controller.rb` all override
engine controllers the same way. Copy the engine file verbatim and add to
`index`.

**2. The plans block is extracted to a shared partial.**
`app/views/pricing/show.html.erb` currently inlines the monthly/yearly toggle,
the `data-controller="pricing"` wrapper, and the card grid. That block moves to
`app/views/pricing/_plans.html.erb` and is rendered from both `pricing/show` and
`public/index`. Duplicating it would guarantee the two pages drift.

The partial takes the plan collections as locals rather than reading ivars, so
the calling controller's variable names are not load-bearing.

**3. All copy is localized.**
Every string lands in `config/locales/en.yml` under `public.index.*`. The copy
in this document is a placeholder for a product that does not exist yet
(see Open Questions); putting it in the locale file means replacing it later is
a YAML edit with no template changes.

**4. The navbar gets a marketing variant, driven by one helper.**
On marketing pages the navbar drops its bottom border and renders "Cove" as a
text wordmark instead of `render_svg "logo"`.

`app/views/application/_navbar.html.erb` stays the single navbar. It branches on
a `marketing_page?` helper defined on `ApplicationController` and exposed with
`helper_method`, backed by an explicit list of controllers rather than by
inference. A second navbar partial was considered and rejected: it would
duplicate the mobile toggle, the dropdown wiring, and the account-links section,
all of which are identical between the two variants.

Two branch points, nothing else:

- The `border-b border-border` classes on the root `<nav>` are omitted when
  `marketing_page?`.
- The brand link renders a new `app/views/application/_wordmark.html.erb`
  partial when `marketing_page?`, and `render_svg "logo"` otherwise.

`_wordmark.html.erb` renders `Jumpstart.config.application_name` — already
`"Cove"` — as text, with `.font-display` so it picks up the project's serif
(Source Serif 4 at 600), matching `h1`/`h2`. It replaces the `<svg>`, so the
existing `sr-only` span is dropped from that branch: the text is already the
accessible name, and keeping both would make screen readers announce "Cove
Cove".

**Marketing pages are the homepage and `/pricing`.** `/pricing` is linked
directly from the marketing navbar, so a border appearing and the wordmark
reverting to Jumpstart's logo on click would be a visible seam between two pages
a visitor moves between constantly. `/about`, `/terms`, `/privacy` and
`/announcements` are informational and legal rather than promotional and keep
the standard navbar.

### Decision 5 — the wordmark also replaces Jumpstart's logo on Devise and error pages

`lib/jumpstart/app/assets/images/logo.svg` is 143×24 and its paths **spell out
"Jumpstart"** — it is the full Jumpstart wordmark, not an abstract glyph. Two
`app/` layouts render it outside the navbar, and both are in scope:

| Layout | Who sees it |
| -- | -- |
| `app/views/layouts/minimal.html.erb` | Every Devise page — sign in, register, reset password, accept invitation |
| `app/views/layouts/error.html.erb` | The dynamically rendered `/404` and `/500` routes |

Both currently use the identical three-line idiom — `link_to root_path` wrapping
`render_svg "logo"` plus an `sr-only` span — so both become
`render "application/wordmark"`, the same partial the marketing navbar uses.

**Devise pages also lose their bottom border**, matching the marketing navbar.
The rule lives in `app/assets/tailwind/components/top_nav.css` as
`.minimal-top-nav { border-bottom: 1px solid var(--base-border-tertiary); }` —
one declaration to drop. The error layout's `<header>` is unstyled and has no
border already, so nothing changes there.

**No existing test breaks.** A grep for `logo` across `test/` matches only
`logout` calls — nothing in the suite asserts on the logo markup, in the app
shell system test or anywhere else.

### The static error pages are deliberately left alone

`public/400.html`, `404.html`, `406-unsupported-browser.html`, `422.html` and
`500.html` are separate, self-contained artifacts with inline `<style>` and no
asset references — they are served by the web server when Rails cannot respond,
so they cannot link a compiled stylesheet or a digested font file.

**They already say "Cove."** Each one's header is literally
`<a href="/">Cove</a>`, styled with a system sans stack at weight 700. So the
dynamic error layout has been the odd one out all along, and this change brings
it in line with its own static counterparts rather than away from them.

They keep the system font rather than adopting `.font-display`: the serif is
self-hosted from `app/assets/fonts/` through Propshaft, and pulling a webfont
over the network on a page that renders when the app is down is the wrong
trade. The consequence, recorded plainly: the dynamic error page's wordmark is
serif and the static ones are sans. They are alternate renderings of the same
route and are essentially never seen side by side.

Editing them would also mean hand-editing inline CSS in five files and updating
`test/integration/static_error_pages_test.rb`, for no visible gain.

### What gets deleted

`app/views/public/index.html.erb`'s entire current body, including the
development-only "Configure Jumpstart" and "Read the Docs" buttons. Those are
**already redundant** — `app/views/application/_dev_menu.html.erb` renders in
development in the navbar and links to Jumpstart Configuration, Documentation,
*and* Mailbin. Nothing needs relocating; the buttons are simply removed.

## Acceptance Criteria

1. A signed-out visit to `/` shows Cove's own hero, value points, and pricing —
   no Jumpstart branding or copy anywhere on the page.
2. The primary CTA goes to `new_user_registration_path`.
3. The Free and Premium cards on `/` are visually and behaviorally identical to
   those on `/pricing`, including the monthly/yearly toggle.
4. `/pricing` still renders correctly after the partial extraction.
5. A signed-in user hitting `/` still lands on the dashboard (existing
   `authenticated :user` root route is untouched).
6. The navbar on `/` and `/pricing` has no bottom border and shows "Cove" as
   text, not an SVG.
7. The navbar on `/about`, `/terms`, `/privacy` and any signed-in page is
   unchanged — bottom border present, `logo.svg` rendered.
8. The marketing navbar's brand link still reaches `root_path` and still has an
   accessible name of "Cove", without announcing it twice.
9. Devise pages (sign in, register, reset password) show "Cove" as text with no
   bottom border on the top nav.
10. The dynamic `/404` and `/500` pages show "Cove" as text instead of
    Jumpstart's logo.
11. The static `public/*.html` error pages are unchanged.
12. With no visible `Plan` rows, `/` renders the hero and value points and
    simply omits the pricing section — it does not redirect and does not error.
13. `about`, `terms`, `privacy`, and `reset_app` behave exactly as before the
    controller override.
14. All page copy resolves from `config/locales/en.yml`; no hardcoded strings in
    the template.
15. `render_svg "logo"` no longer appears anywhere under `app/views/` except
    `app/views/jumpstart/docs/_top_nav.html.erb`, which is development-only and
    correctly Jumpstart-branded.

## Prototype

None. The visual design follows the existing brand tokens — teal `--primary`,
cream `--background`, coral via `--bg-accent` / `--border-accent`, serif `h1`/`h2`
per the project's typography rule — and reuses existing components, so there is
no new visual language to lock in.

## Data Model

No changes. No new models, no migrations, no new columns.

Read-only use of existing data:

- `Plan.visible.sorted`, partitioned into monthly and yearly — the same query
  `PricingController#show` already runs.
- `Account::FREE_STUDENT_LIMIT` and `premium_student_limit` (from
  `app/helpers/plan_pricing_helper.rb`), already used by the pricing cards.

## Screens / Flows

### Signed-out visitor lands on `/`

1. Marketing navbar renders: "Cove" as a serif text wordmark, Pricing link, Log
   In and Sign Up buttons, and **no bottom border** — the hero's background runs
   straight up into it.
2. **Hero** — `h1` headline, subhead paragraph, one primary `ButtonComponent`
   linking to registration. One CTA only; the navbar already carries Log In and
   Sign Up, and a second hero button would compete with the primary action.
3. **Three value points** — a simple three-up on desktop, stacked on mobile.
   Each is a short heading plus a sentence. No icons (no visuals exist yet).
4. **Pricing** — the shared plans partial: the monthly/yearly toggle and the
   Free and Premium cards.
   - Free card CTA reads "Get started free" → registration.
   - Premium card CTA reads "Get Premium" → checkout.
   - Both already branch correctly on `user_signed_in?`.
5. Existing footer: Announcements, About, Privacy, Terms.

### Signed-in user visits `/`

Unchanged. `config/routes.rb`'s `authenticated :user { root to: "dashboard#show" }`
matches first, so a signed-in user never sees this page.

### Draft copy (placeholder)

Headline:

> Your homeschool's chief of staff

Subhead:

> Cove keeps the plans, the records, and the day-to-day running, so your time
> goes to teaching instead of tracking.

CTA: **Start free**

Value points:

| Heading | Body |
| -- | -- |
| Plan the year | Lay out subjects and schedules for every student in one place. |
| Keep the records | Attendance, grades, and progress captured as you go, ready when you need them. |
| Run the day | See what's next for each student without rebuilding the plan every morning. |

**This copy describes capabilities the app does not have.** There is no Student
model, no planning, and no records feature in the codebase today. It is
deliberate placeholder content, approved as such — see Open Questions.

The CTA is the exception and is accurate: the Free plan genuinely exists, costs
nothing, and supports one student indefinitely.

## Scope

**In:**

- Rewrite `app/views/public/index.html.erb`.
- Add `app/controllers/public_controller.rb` overriding the engine controller,
  with all five actions and plan loading in `index`.
- Extract `app/views/pricing/_plans.html.erb` and render it from both
  `pricing/show.html.erb` and `public/index.html.erb`.
- Add `public.index.*` keys to `config/locales/en.yml`.
- Add `marketing_page?` to `ApplicationController` as a `helper_method`, backed
  by an explicit controller list.
- Add `app/views/application/_wordmark.html.erb`.
- Branch `app/views/application/_navbar.html.erb` on `marketing_page?` for the
  bottom border and the brand mark.
- Swap `render_svg "logo"` for the wordmark partial in
  `app/views/layouts/minimal.html.erb` and `app/views/layouts/error.html.erb`,
  dropping the now-redundant `sr-only` span in both.
- Remove the `border-bottom` declaration from `.minimal-top-nav` in
  `app/assets/tailwind/components/top_nav.css`.
- Tests: extend `test/integration/public_test.rb` for the homepage's content,
  its CTA target, the no-plans case, and the four other `PublicController`
  actions surviving the override; confirm `/pricing` still renders after the
  extraction. Cover the navbar variant both ways — borderless text wordmark on
  `/` and `/pricing`, unchanged bordered logo on `/about` and on a signed-in
  page. Extend `test/integration/errors_test.rb` for the dynamic error pages'
  wordmark, and assert a Devise page renders it too.

**Deferred:**

- Real product copy, once Cove's features exist.
- Any visuals — screenshots, illustrations, icons, logo lockup.
- **The footer's `mark.svg`** — Jumpstart's abstract glyph, still rendered in
  the footer of every page including the new homepage. It is a glyph rather than
  lettering, so it does not spell out a competitor's name the way `logo.svg`
  did, but it is still Jumpstart's brand mark and should go when Cove has a real
  one.
- **The standard (non-marketing) navbar's logo** — signed-in pages keep
  `render_svg "logo"`, so the Jumpstart wordmark survives inside the
  application shell.
- Additional marketing pages (features, FAQ, testimonials, blog).
- Email capture or a waitlist. The product is sign-up-and-use-it, so
  registration is the conversion point; there is no second funnel to build.
- SEO work beyond the existing `Current.meta_tags` title, and any Open Graph or
  social card images.
- Filling in the empty `docs/product/*.md` briefs.

## Open Questions

1. **The hero and value-point copy is a guess and is known to overclaim.** It
   was written from a one-line description ("Cove works almost like a chief of
   staff or assistant to help you manage and run your homeschool") and
   deliberately accepted as placeholder. It should be replaced before any real
   traffic reaches the page. Localizing it is what keeps that cheap.

2. **The signed-in app shell still shows Jumpstart's wordmark.** The standard
   navbar keeps `render_svg "logo"`, so a signed-in user still sees "Jumpstart"
   at the top of every page. The signed-out experience is fully Cove-branded
   after this ticket; the signed-in one is not. Worth a follow-up, and cheap
   now that `_wordmark` exists.
3. **Whether the text wordmark is the final answer or a placeholder for a real
   Cove logo.** If a logo lands later, `_wordmark.html.erb` is the single place
   it goes.

## More Info

- `docs/product/strategy-brief.md`, `product-brief.md`, and `ux-notes.md` are
  all **empty files**. There is no positioning document to ground copy in — the
  only product-flavored strings in the repo are "Create a family for your
  homeschooling household" (`config/locales/en.yml`) and "product news and
  homeschooling resources" (the marketing consent label). This is why the copy
  above is placeholder rather than derived.
- **Existing plan and family rules the pricing section inherits**, all from
  COV-73 through COV-77: Free is one student and one parent; Premium raises the
  student cap and allows both parents; family billing is flat per family;
  complimentary Premium is an account switch, not a subscription. The cards
  already encode all of this — nothing here re-derives it.
- **`PricingController#show` redirects to `root_path`** when no visible plans
  exist. The homepage must not copy that behavior, hence acceptance criterion 6.
- **`Jumpstart::Welcome`** (`prepend_before_action :jumpstart_welcome`, included
  into `ApplicationController` in development) redirects when
  `config/jumpstart.rb` is missing. It is unrelated to the welcome *page* being
  replaced here and needs no change.
- **`render_svg`** (`lib/jumpstart/app/helpers/svg_helper.rb`) inlines the SVG
  and injects a `<title>` from the asset name — which is why the current navbar
  logo also carries the literal accessible title "Logo". The text wordmark has
  no such problem.
- **Brand tokens and typography** are fixed project decisions: reference
  `--primary` / `--background` / `--bg-accent` rather than hex values, and only
  `h1`/`h2` and `.font-display` take the serif. Buttons and inputs carry no drop
  shadows.
