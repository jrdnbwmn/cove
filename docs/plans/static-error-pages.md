> Ticket: COV-20
> Branch: jrdnbwmn/feature/cov-20-static-error-pages

# Plan: Restyle static error pages

## Status

| Task | Description | Assign | Done |
| ---- | ----------- | ------ | ---- |
| 1 | Add regression tests for all five static pages | Master | |
| 2 | Establish the standalone page pattern in `400.html` | Master | |
| 3 | Restyle the 422 page | subagent | |
| 4 | Restyle the 404 and 500 fallback pages | subagent | |
| 5 | Restyle the unsupported-browser page | subagent | |
| 6 | Run full automated and browser verification | Master | |

## Prerequisites

- Design: [`docs/designs/static-error-pages.md`](../designs/static-error-pages.md)
- Prototype: None; use the routed COV-19 views in `app/views/errors/` as the approved composition reference
- Feature branch exists: `jrdnbwmn/feature/cov-20-static-error-pages`

## Tasks

### Task 1 [Master]: Add static-page regression tests

**Skills:** write-tests

**Reference:** Read [`test/integration/errors_test.rb`](../../test/integration/errors_test.rb) for existing error-page expectations and [`docs/designs/static-error-pages.md`](../designs/static-error-pages.md) for the five page contracts

**In scope:**

- Create `test/integration/static_error_pages_test.rb`.
- Parse each file from `public/` with Nokogiri, without making a Rails request.
- Define expectations for each filename, document title/status code, visible heading, description, icon, and whether a “Back to home” action is present.
- Assert every page has `lang="en"`, `noindex, nofollow`, a header, a main landmark, exactly one `<h1>`, a linked “Cove” wordmark, and an inline decorative SVG with `aria-hidden="true"`.
- Assert the documents contain inline CSS but no scripts, external stylesheet/font/image dependencies, SVG `<use>` references, CSS imports, or `url(...)` resources.
- Assert all links are root-relative `/`; 400, 422, 404, and 500 have both wordmark and action links, while 406 has only the wordmark link.
- Assert conservative CSS by rejecting `clamp(`, `var(`, `oklch(`, and CSS nesting syntax used by the stock pages.

**NOT in scope:**

- Rails route/controller tests, screenshot tests, CSS pixel assertions, or changes to the five HTML files.

**Build order:**

1. **Test:** Add the complete test file first.
2. **Implement:** No production implementation in this task.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && ruby -v && bin/rails test test/integration/static_error_pages_test.rb` — confirm it fails against the current stock pages for the intended contract violations.
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 2 [Master]: Establish the standalone pattern in `400.html`

**Skills:** style-ui, write-tests

**Reference:** Read [`app/views/layouts/error.html.erb`](../../app/views/layouts/error.html.erb), [`app/views/errors/_error.html.erb`](../../app/views/errors/_error.html.erb), and [`app/assets/svg/icons/lucide/outline/circle-alert.svg`](../../app/assets/svg/icons/lucide/outline/circle-alert.svg)

**Prototype:** None — translate the routed COV-19 composition without introducing Rails dependencies

**In scope:**

- Replace `public/400.html` with the canonical static-page structure that later tasks will copy literally.
- Include only a doctype, semantic HTML, metadata, one inline `<style>`, text content, and inline SVG.
- Render a linked “Cove” text wordmark in the header.
- Center a maximum-`24rem` error state containing a 64px neutral circle, the inline `circle-alert` icon, the approved heading and description, and a “Back to home” link styled as the primary button.
- Use the approved system font stack, literal neutral hex colors, 20px semibold heading, 16px supporting copy, 10px button radius, responsive padding, and an explicit visible `:focus` outline.
- Add `aria-hidden="true"` and `focusable="false"` to the decorative SVG.
- Keep the numeric 400 status in the document title, not the visible content.
- Use conservative, standalone CSS with no variables, nesting, `clamp()`, asset references, or framework-generated classes.

**NOT in scope:**

- Shared stylesheets, ViewComponents, JavaScript, asset-pipeline references, a new logo asset, or changes to any other error page.

**Build order:**

1. **Test:** Run the 400-focused regression test and confirm it is red.
2. **Implement:** Rewrite `public/400.html`, establishing the exact CSS and HTML pattern for Tasks 3–5.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/static_error_pages_test.rb -n /400/`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 3 [subagent]: Restyle the 422 page

**Skills:** style-ui, write-tests

**Reference:** Copy the standalone structure and CSS from [`public/400.html`](../../public/400.html); use [`app/assets/svg/icons/lucide/outline/clock-alert.svg`](../../app/assets/svg/icons/lucide/outline/clock-alert.svg) for the inline icon

**Prototype:** None — preserve the exact pattern established in Task 2

**In scope:**

- Rewrite `public/422.html` with the same literal CSS and semantic structure as `public/400.html`.
- Use the heading “Your request couldn't be completed.”
- Use the approved expired-page description.
- Inline the `clock-alert` SVG as decorative content.
- Include the linked Cove wordmark and “Back to home” action.
- Keep 422 in the document title and preserve `noindex, nofollow`.

**NOT in scope:**

- CSRF-specific claims, retry behavior, Rails exception handling, or changes to the canonical CSS pattern.

**Build order:**

1. **Test:** Run the 422-focused regression test and confirm it is red.
2. **Implement:** Rewrite `public/422.html`.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/static_error_pages_test.rb -n /422/`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 4 [subagent]: Restyle the 404 and 500 fallback pages

**Skills:** style-ui, write-tests

**Reference:** Copy the standalone structure and CSS from [`public/400.html`](../../public/400.html); reuse copy from [`app/views/errors/not_found.html.erb`](../../app/views/errors/not_found.html.erb) and [`app/views/errors/internal_server_error.html.erb`](../../app/views/errors/internal_server_error.html.erb)

**Prototype:** None — match the routed COV-19 visual language through the Task 2 static pattern

**In scope:**

- Rewrite `public/404.html` with the approved “Page not found” heading, existing COV-19 description, inline `compass` SVG, and home action.
- Rewrite `public/500.html` with the approved “Something went wrong” heading, existing COV-19 description, inline `server-crash` SVG, and home action.
- Copy the canonical CSS and semantic structure literally into both files.
- Preserve status codes in their document titles and `noindex, nofollow`.

**NOT in scope:**

- Changes to the routed 404/500 views, error layout, controller, routes, middleware, or exception configuration.

**Build order:**

1. **Test:** Run the 404/500-focused regression tests and confirm they are red.
2. **Implement:** Rewrite `public/404.html` and `public/500.html`, sourcing icon markup from `app/assets/svg/icons/lucide/outline/`.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/static_error_pages_test.rb -n '/(404|500)/'`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 5 [subagent]: Restyle the unsupported-browser page

**Skills:** style-ui, write-tests

**Reference:** Copy the standalone structure and CSS from [`public/400.html`](../../public/400.html); use [`app/assets/svg/icons/lucide/outline/monitor-x.svg`](../../app/assets/svg/icons/lucide/outline/monitor-x.svg)

**Prototype:** None — use the canonical pattern with the approved action omission

**In scope:**

- Rewrite `public/406-unsupported-browser.html` with the approved heading and browser-update description.
- Inline the decorative `monitor-x` SVG.
- Preserve the linked Cove wordmark but omit the “Back to home” action.
- Copy the canonical styling while ensuring the page remains legible with broadly supported flexbox, media queries, literal colors, and ordinary focus styling.
- Keep 406 in the document title and preserve `noindex, nofollow`.

**NOT in scope:**

- Browser detection, JavaScript, browser-specific download links, external upgrade guidance, or modern CSS enhancements.

**Build order:**

1. **Test:** Run the 406-focused regression test and confirm it is red.
2. **Implement:** Rewrite `public/406-unsupported-browser.html`.
3. **Verify:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/static_error_pages_test.rb -n /406/`
4. **Review:** After completion, ALWAYS run review-changes before proceeding. This is not optional.

### Task 6 [Master]: Complete automated and browser verification

**Skills:** style-ui, write-tests, review-changes

**Reference:** Verify against every acceptance criterion in [`docs/designs/static-error-pages.md`](../designs/static-error-pages.md)

**Prototype:** None

**In scope:**

- Run the complete static-page regression file, then the full Rails test suite.
- Serve `public/` with a temporary local static HTTP server and verify all five HTTP URLs.
- Open all five pages directly through `file://`.
- Inspect desktop and approximately 375px-wide layouts for centered composition, readable wrapping, spacing, icon rendering, and absence of horizontal overflow.
- Keyboard-check both the Cove wordmark and all four primary actions for visible focus.
- Confirm the 406 page remains readable and has no action button.
- Run `git diff --check`, inspect `git diff`, and confirm only the five static pages plus the regression test changed.

**NOT in scope:**

- Visual redesign, routed error-page changes, unrelated cleanup, or committing before review-changes completes.

**Build order:**

1. **Test:** `export PATH="$HOME/.local/share/mise/shims:$PATH" && bin/rails test test/integration/static_error_pages_test.rb && bin/rails test`
2. **Implement:** Make no new production changes unless verification exposes an acceptance-criteria failure; return to the owning task and update its test first if a correction is necessary.
3. **Verify:** Start `ruby -run -e httpd public -p 4567`, inspect `file://` and `http://127.0.0.1:4567/` versions at desktop and narrow widths, then run `git diff --check && git diff && git status --short`.
4. **Review:** Run review-changes over `origin/main...HEAD` before reporting execution complete. This is not optional.

## Task Dependencies

- Task 2 depends on Task 1 so the canonical implementation is test-driven.
- Tasks 3–5 depend on Task 2 because they must copy its finalized standalone CSS and structure.
- Tasks 3–5 are independent and can run in parallel as separate subagent assignments.
- Task 6 depends on Tasks 3–5 and is the final integration and visual-verification gate.
