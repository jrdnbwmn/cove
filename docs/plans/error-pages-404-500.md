> Ticket: COV-19
> Branch: jrdnbwmn/cov-19-error-pages

# Plan: Rebuild 404 + 500 error pages with design-system components

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | App-owned `ErrorsController` + JSON jbuilders + JSON request tests | Master | ✅ |
| 2 | Bare `error` layout + shared `_error` partial | Master | |
| 3 | Two HTML error views + HTML request tests | Master | |

## Prerequisites

- Design: `docs/designs/error-pages-404-500.md`
- Prototype: None (visual language comes from `EmptyStateComponent` + `ButtonComponent`)
- Feature branch `jrdnbwmn/cov-19-error-pages` exists ✓
- `EmptyStateComponent` exists (COV-18) ✓; `ButtonComponent` exists ✓; `icon` helper (rails_icons/Lucide) available ✓
- Routing already maps `/404`→`errors#not_found`, `/500`→`errors#internal_server_error` (`config/routes/jumpstart.rb:29-30`) — **do not touch**
- `config.exceptions_app = routes` set (`config/application.rb:31`) — **do not touch**

## Tasks

### Task 1 [Master]: App-owned `ErrorsController` + JSON jbuilders + JSON tests

**Skills:** write-tests
**Reference:** engine original `lib/jumpstart/app/controllers/errors_controller.rb` (copy the `respond_to` logic verbatim); test pattern `test/controllers/notifications_controller_test.rb`

**In scope:**

- Create `app/controllers/errors_controller.rb`:
  - `class ErrorsController < ActionController::Base` (NOT `ApplicationController` — this is what makes the 500 page dependency-free by construction)
  - `layout false`; each HTML response explicitly renders `layout: "error"`, because Rails 8.1 also applies an explicit controller layout to Jbuilder responses
  - `#not_found` and `#internal_server_error` actions with the engine's `respond_to` logic (`format.json { render status: ... }` / `format.any { render status: ..., formats: :html, layout: "error" }`)
- Update `Jumpstart::AccountMiddleware` to bypass only `/404` and `/500` (with optional format), since the test-only path-tenancy middleware otherwise handles those reserved error routes as nonexistent account IDs.
- Copy JSON jbuilders verbatim from `lib/jumpstart/app/views/errors/`:
  - `app/views/errors/not_found.json.jbuilder` → `json.error "Not found"`
  - `app/views/errors/internal_server_error.json.jbuilder` → `json.error "Internal server error"`

**NOT in scope:**

- HTML views (Task 2/3), the error layout (Task 2), any routing changes, deleting the engine originals.

**Build order:**

1. **Test:** Create `test/integration/errors_test.rb` (`< ActionDispatch::IntegrationTest`). Assert JSON only for now:
   - `get "/404.json"` → `assert_response :not_found`; parsed body `{"error" => "Not found"}`
   - `get "/500.json"` → `assert_response :internal_server_error`; body `{"error" => "Internal server error"}`
2. **Implement:** Controller + the two jbuilders above.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/errors_test.rb`
4. **Review:** Run /review-changes before proceeding. Not optional.

### Task 2 [Master]: Bare `error` layout + shared `_error` partial

**Skills:** style-ui
**Reference:** `app/views/layouts/minimal.html.erb` (structure to *pare down from* — do NOT reuse it: its `impersonation_banner`/`_head`/`_flash` touch DB+auth and don't exist under `ActionController::Base`); `app/components/empty_state_component.rb` + `.html.erb` for the slot API; `lib/jumpstart/app/helpers/svg_helper.rb` for `render_svg`

**In scope:**

- `app/views/layouts/error.html.erb` — self-sufficient, zero DB/session dependency:
  - `<head>`: `charset`, viewport meta, `csrf_meta_tags`, `csp_meta_tag`, `stylesheet_link_tag "tailwind"`, Inter font link. **No** importmap JS, **no** `Current.meta_tags`, **no** payments partial.
  - `<body>`: `link_to root_path` wrapping `render_svg "logo"` (+ `sr-only` app name), then `yield`. **No** impersonation banner, flash, or theme controller.
- `app/views/errors/_error.html.erb` — shared partial, locals `title`, `description`, `icon` (Lucide name string). Renders `EmptyStateComponent.new(title:, description:, size: :lg)`:
  - `with_icon { icon(local_assigns[:icon]) }`
  - `with_primary_action { render ButtonComponent.new(text: "Back to home", href: root_path) }`

**NOT in scope:**

- The two page views (Task 3), any JS/theme wiring, dark-mode restoration, secondary action.

**Build order:**

1. **Test:** No isolated test — behavior is exercised by Task 3's HTML request tests. (Optional smoke: temporary Puma + curl per AGENTS.md; not required.)
2. **Implement:** The layout and partial above.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/errors_test.rb` (still green — JSON unaffected).
4. **Review:** Run /review-changes before proceeding. Not optional.

### Task 3 [Master]: Two HTML error views + HTML request tests

**Skills:** style-ui, write-tests
**Reference:** the `_error.html.erb` partial signature from Task 2

**In scope:**

- `app/views/errors/not_found.html.erb` → `render "error", title: "Page not found", description: "Sorry, the page you're looking for doesn't exist or may have moved.", icon: "compass"` (confirm final microcopy/icon at build — `compass` is the pick)
- `app/views/errors/internal_server_error.html.erb` → `render "error", title: "Something went wrong", description: "Sorry, we had a problem loading this page. Please try again.", icon: "server-crash"` (confirm final microcopy/icon at build)
- Add HTML request tests to `test/integration/errors_test.rb`:
  - `get "/404"` → `assert_response :not_found`; body includes the 404 title and a "Back to home" link to `root_path`
  - `get "/500"` → `assert_response :internal_server_error`; body includes the 500 title and the "Back to home" link
  - Optionally assert the body does NOT include theme/importmap markers (proves the bare layout), mirroring `test/integration/public_test.rb`

**NOT in scope:**

- Additional statuses (403/422), illustrations/full app shell, retry behavior beyond the link.

**Build order:**

1. **Test:** Add the HTML request tests above (red — views don't exist yet).
2. **Implement:** The two HTML views.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/errors_test.rb`, then full `bin/rails test`.
4. **Review:** Run /review-changes before proceeding. Not optional.

## Task Dependencies

- Task 3 depends on Task 1 (controller resolves HTML requests) **and** Task 2 (layout + partial).
- Tasks 1 and 2 are independent and could run in parallel — but both are Master (new controller + shared layout = shared infra), so they'll run sequentially.
