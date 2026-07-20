> Plan created: docs/plans/static-error-pages.md
> Ticket: COV-20
> Branch: jrdnbwmn/feature/cov-20-static-error-pages

# Feature: Restyle static error pages

## Problem

The boot-independent error pages in `public/` still use the stock Rails design
and developer-facing copy. They should look intentional and consistent with
Cove's error-page design while remaining usable when Rails and the asset
pipeline are unavailable.

## Approach

Restyle the static HTML files in place. Each document will contain its own
literal CSS and inline SVG assets, with no runtime dependency on Rails,
ViewComponents, JavaScript, the asset pipeline, external stylesheets, images,
or fonts.

The pages will translate the COV-19 error-page composition into standalone
HTML: a small Cove text wordmark, a centered circular icon, a heading,
supporting copy, and a primary action where appropriate. The five files will
repeat the same compact CSS and structure so every page remains independently
self-contained.

Use conservative CSS that can still render in the unsupported-browser case:
ordinary flexbox, media queries, literal hex colors, and `:focus`. Avoid CSS
variables, `oklch`, nesting, `clamp()`, and other newer features. Use the
system UI font stack rather than a web font.

The repository's current `logo.svg` is still the default Jumpstart wordmark,
so the static pages will render "Cove" as a text wordmark. Updating COV-19's
routed error layout or introducing a new shared logo asset is outside this
ticket.

## Acceptance Criteria

- `public/400.html`, `public/422.html`, and
  `public/406-unsupported-browser.html` match Cove's error-page visual language.
- The fallback `public/404.html` and `public/500.html` use the same treatment.
- Each page renders correctly when opened directly as a file and when served
  over HTTP.
- Each page is self-contained: no external CSS, JavaScript, image, or font
  dependency.
- The 406 page uses broadly supported CSS and remains legible in an older or
  unsupported browser.
- Every page has semantic landmarks, one `<h1>`, accessible contrast, visible
  keyboard focus, and decorative SVGs hidden from assistive technology.
- Static-page regression tests cover the five files, their expected content
  and actions, semantic structure, and the absence of external dependencies.
- No routes, controllers, middleware, or exception configuration change.

## Prototype

None. The routed COV-19 error pages establish the composition and visual
language; the approved COV-20 design translates that treatment into standalone
HTML.

## Data Model

None. These are immutable static files with no application, session, or
database access.

## Screens / Flows

All five pages use this structure:

1. A small "Cove" text wordmark in the header links to `/`.
2. The main content presents a centered, approximately `24rem`-wide error
   state.
3. A `64px` neutral circular treatment contains a decorative inline Lucide
   icon.
4. A `20px` semibold `<h1>` and `16px` muted description explain the error in
   plain language.
5. Pages with a recovery path show a black, white-text "Back to home" button
   with a `10px` radius and visible keyboard focus.

Shared visual values:

- White page background.
- Neutral-900 heading and primary action.
- Neutral-500 supporting text.
- Neutral-100 icon background with a neutral icon.
- System UI font stack only.
- Responsive padding for narrow viewports.
- Numeric status codes appear in the document `<title>`, not in the visible
  page content.

Page-specific content:

- **400 — Bad request:** `circle-alert` icon. Description: "We couldn't
  process this request. Please check the address and try again." Includes
  "Back to home."
- **422 — Your request couldn't be completed:** `clock-alert` icon.
  Description: "This page may have expired. Return home and try again."
  Includes "Back to home." The wording deliberately does not claim CSRF is
  the only possible cause.
- **406 — Your browser isn't supported:** `monitor-x` icon. Description:
  "Please update your browser to the latest version to continue." No action
  button; the header wordmark remains a link to `/`.
- **404 — Page not found:** `compass` icon. Reuse the COV-19 description:
  "Sorry, the page you're looking for doesn't exist or may have moved."
  Includes "Back to home."
- **500 — Something went wrong:** `server-crash` icon. Reuse the COV-19
  description: "Sorry, we had a problem loading this page. Please try again."
  Includes "Back to home."

Opening a page through `file://` must render it correctly. The root-relative
`/` links are only expected to navigate correctly when the files are served
over HTTP.

## Scope

**In:**

- Restyle `public/400.html`.
- Restyle `public/422.html`.
- Lightly restyle `public/406-unsupported-browser.html` using conservative
  CSS.
- Restyle the static fallback files `public/404.html` and `public/500.html`.
- Embed the repeated CSS, Cove text wordmark, and page-specific Lucide SVG in
  every file.
- Preserve `noindex, nofollow` metadata.
- Add automated static-page regression coverage.
- Verify every page directly in a browser at desktop and narrow viewport
  sizes.

**Deferred:**

- Routing any additional status through `ErrorsController`.
- Changing the routed COV-19 error pages or their layout.
- Creating or replacing a shared Cove logo asset.
- JavaScript behavior, browser detection, or automatic recovery.
- External browser-upgrade guidance or browser-specific links.

## Open Questions

None.

## More Info

- COV-20's decided Option A is the governing constraint: the pages remain
  static so they survive an application boot failure.
- COV-19 normally handles routed 404 and 500 responses. Their files under
  `public/` are only the static safety net, but should not look broken if they
  are ever served.
- The existing stock status-number SVGs and application-owner/logging copy
  will be removed.
