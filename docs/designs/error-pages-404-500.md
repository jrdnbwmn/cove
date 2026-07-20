> Ticket: COV-19
> Branch: jrdnbwmn/cov-19-error-pages

# Feature: Rebuild 404 + 500 error pages with design-system components

## Problem
The routed 404 and 500 error pages still use legacy Jumpstart styling
(`btn btn-primary btn-xl`, `text-15xl`) and live in the Jumpstart engine, so
they look nothing like the rest of the app. We want intentional,
design-system versions the app owns — and the 500 page must render even when
the database, session, and authenticated shell are unavailable.

## Approach
`config.exceptions_app = routes` sends failures to `ErrorsController#not_found`
and `#internal_server_error` (wired at `/404` and `/500` in
`config/routes/jumpstart.rb` — unchanged). We:

1. Copy the controller from the engine into `app/controllers/errors_controller.rb`
   so the app owns it, and change its superclass from `ApplicationController`
   to **`ActionController::Base`**. This makes it dependency-free by
   construction — none of `ApplicationController`'s concerns
   (`Accounts::SubscriptionStatus`, `Users::NavbarNotifications`,
   `Users::AgreementUpdates`, `SetCurrentRequestDetails`, …) run their
   DB/session-touching before_actions. Both actions keep the engine's
   `respond_to` HTML/JSON logic verbatim.

2. Add a dedicated, self-sufficient **`app/views/layouts/error.html.erb`**.
   Both pages render through it. We deliberately do NOT reuse
   `layouts/minimal.html.erb`: despite the ticket's wording, `minimal` is not
   dependency-free — it renders `impersonation_banner` (calls
   `current_user`/`true_user` and builds madmin links → DB + auth) and pulls
   in `_head` (`Current.meta_tags`, importmap JS, payments partial). Under
   `ActionController::Base` those helpers don't even exist, so `minimal` would
   crash. `error.html.erb` honors the ticket's *intent* (minimal chrome, zero
   DB/session dependency).

3. Rebuild the two HTML views on top of a shared partial that renders
   `EmptyStateComponent` — the COV-18 foundation — with a "Back to home"
   `ButtonComponent`.

4. Keep the `.json.jbuilder` responses byte-for-byte (API clients hit these).

### `error.html.erb` layout contents
- `<head>`: charset, viewport meta, `csrf_meta_tags`, `csp_meta_tag`,
  `stylesheet_link_tag "tailwind"`, Inter font link. **No** importmap JS, no
  `Current.meta_tags`, no payments dependencies partial.
- `<body>`: logo via `render_svg "logo"` (reads a file from disk — safe,
  no DB) linking to `root_path`, then `yield`. No impersonation banner, no
  flash, no theme controller.

All helpers used (`render_svg`, `stylesheet_link_tag`, `csrf_meta_tags`,
`root_path`, the rails_icons `icon` helper, ViewComponents) are ActionView /
url-helper level and available regardless of the controller's superclass.

## Acceptance Criteria
- Both pages match the design system; the 500 page is dependency-free (renders
  with DB and session unavailable).
- HTML and JSON responses are both correct; `bin/rails test` is green.
- No change to which errors map to which page (routing untouched).

## Prototype
None. Layout and copy are new; visual language comes from
`EmptyStateComponent` + `ButtonComponent` design tokens.

## Data Model
None.

## Screens / Flows
Both pages use the same shape via a shared
`app/views/errors/_error.html.erb` partial:

```
[ logo ]                     ← from the error layout

        ( icon )             ← EmptyStateComponent icon slot
        <status> — <title>   ← e.g. "Page not found"
        <description>
        [ Back to home ]     ← ButtonComponent in primary_action, href: root_path
```

Partial signature: `_error.html.erb` takes locals `title`, `description`,
`icon` (Lucide name). It renders `EmptyStateComponent.new(title:,
description:, size: :lg)`, filling the icon slot with `icon(<name>)` and the
`primary_action` slot with a "Back to home" `ButtonComponent` (`href:
root_path`).

- **`not_found.html.erb`** → renders the partial. Icon `compass`.
  Copy: "Page not found" / "Sorry, the page you're looking for doesn't exist
  or may have moved." (final copy confirmed at build time).
- **`internal_server_error.html.erb`** → renders the partial. Icon
  `server-crash`. Copy: "Something went wrong" / "Sorry, we had a problem
  loading this page. Please try again." (final copy at build time).

JSON (unchanged):
- `not_found.json.jbuilder` → `json.error "Not found"`
- `internal_server_error.json.jbuilder` → `json.error "Internal server error"`

## Scope
**In:**
- `app/controllers/errors_controller.rb` (`< ActionController::Base`,
  `layout "error"`).
- `app/views/layouts/error.html.erb` (new bare layout).
- `app/views/errors/_error.html.erb` shared partial.
- `app/views/errors/not_found.html.erb` + `internal_server_error.html.erb`.
- Copied JSON jbuilders (`not_found.json.jbuilder`,
  `internal_server_error.json.jbuilder`).
- Request specs: HTML renders new markup ("Back to home" link,
  EmptyStateComponent output) with correct status codes; JSON returns the
  unchanged `{error: ...}` shape with correct status.

**Deferred:**
- Any additional error statuses (403/422/etc.) — only 404/500 are in scope.
- Richer 404 treatment (full app shell / illustrations) — both pages stay on
  the bare error layout.
- Retry/"try again" behavior beyond a plain link.

## Open Questions
- Final microcopy for both pages (titles/descriptions) — settle during build.
- Icon confirmation: `compass` (404) and `server-crash` (500) are the current
  picks; swap at build time if a better Lucide match exists.

## More Info
- The engine originals we're replacing: controller at
  `lib/jumpstart/app/controllers/errors_controller.rb`; views at
  `lib/jumpstart/app/views/errors/`. Copy the JSON jbuilders from there
  unchanged.
- `config/routes/jumpstart.rb` already maps `/404` and `/500` — do not touch.
- `EmptyStateComponent` API (COV-18): `title:` (required), `description:`,
  `size:` (:sm/:md/:lg), plus `renders_one :icon`, `:primary_action`,
  `:secondary_action` slots.
- Testing gotchas (see AGENTS.md): prepend mise shims before `bin/rails`;
  don't run RuboCop directly on `.erb`.
