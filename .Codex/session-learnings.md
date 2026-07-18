## Catchup 2026-07-16

### Friction

The original B1 plan mapped the `forms` slug to components that Rails Blocks
does not provide. The revised plan correctly models it as one wrapper.

### Mistakes

The first B1 attempt had to stop at dry-run because the original component
mapping was inaccurate. Preview aggregation via `inline_template` also does
not work for this ViewComponent preview API; use one preview method per state.

### Observations

For this workspace, run Rails commands through `mise exec --`. The browser
runtime may initialize with no browser backends available, so inspect
`agent.browsers.list()` once and record the limitation rather than falling back
to a separate automation path. Rails Blocks' `forms` CSS is already imported
after Jumpstart's forms CSS, so its `.form-control` rules take precedence.

## Catchup 2026-07-16 (B2)

### Friction

The active context was nearing its limit while the second plan batch reached
its review boundary, so B2 was completed and committed before pausing for a
fresh-session handoff.

### Mistakes

The first attempted `importmap pin` command used a `--download` flag that this
project's importmap CLI does not support. The plain pin command works, but its
initial downloaded tom-select entry was not self-contained; use the verified
local ESM bundle described in `.Codex/whats-next.md`.

### Observations

For Rails Blocks batches, write minimal flat-component tests first, prove RED,
then install and normalize. Preview tests can provide a second RED/GREEN cycle.
The generated component source needed RuboCop auto-formatting after namespace
removal, and its inline HTML styles must be removed to comply with this repo's
ViewComponent rules.

## Catchup 2026-07-16 (B3)

### Friction

None — B3's dry-run confirmed all four slugs (`alert`, `badge`,
`loading_indicator`, `skeleton`) generate zero JavaScript, so several of the
plan's anticipated collision/vendoring steps didn't apply and could be
skipped without back-and-forth.

### Mistakes

None.

### Observations

Not every Rails Blocks batch needs the full vendoring/collision machinery —
check each dry-run's actual output before assuming a controller or CDN dep
exists, rather than defaulting to the heaviest-case workflow. Also worth
inheriting-with-care: RB's generated components can encode small bugs (e.g.
`loading_indicator`'s `:primary` color option was hard-coded to literal
red instead of this app's brand token) or minor rule violations (fixed-value
inline `style=""` for animation delays, which have static Tailwind
arbitrary-value equivalents) — worth a deliberate token-accent/inline-style
pass on every batch rather than a blind copy of RB's output. Where a
generated component intentionally allows raw HTML via `.html_safe` (RB's
`alert` description), the safer fix is documenting the caveat in the catalog
rather than removing a documented RB feature outright.

## Catchup 2026-07-16 (B4)

### Friction

The plan's `app/components/` collision check missed a real Jumpstart
`ToastComponent` under `lib/jumpstart/app/components/`. It needed Jordan's
approval to use `UiToastComponent` before the Rails Blocks component could be
normalized safely.

### Mistakes

The first tooltip preview tried to pass its trigger as a block to Lookbook's
`render`, which did not capture content. Use
`TooltipComponent.new(...).with_content(...)` in this preview API instead.

### Observations

When a Rails Blocks controller is skipped because a Jumpstart controller has
the same filename, install it into `.context` temporarily, then move it into
the app under the required `ui_*_controller.js` name. Audit generated JS for
unescaped `innerHTML`: B4 now escapes ordinary toast/tooltip text and documents
the custom-HTML boundary. The generated B4 toast controller did not actually
import Motion, even though the approved plan required it to be locally vendored.

## Catchup 2026-07-16 (B5)

### Friction

`ModalComponent` exists in `lib/jumpstart/app/components/`, not in
`app/components/`. The initial collision search missed it, and B5 correctly
paused for Jordan's approval before using `UiModalComponent`.

### Mistakes

The generated dropdown source uses Ruby argument-forwarding syntax that this
workspace's parser rejected. Replace the helper aliases with explicit
`*args, **options, &block` forwarding before running the component tests.

### Observations

Rails Blocks' current dropdown does not generate a `dropdown_controller.js`.
It uses `dropdown-popover`, `menu`, and `searchable-dropdown`; namespace all
three as `ui-dropdown-popover`, `ui-menu`, and `ui-searchable-dropdown`, then
update both Stimulus selector strings and rendered `data-*` values/actions.
The direct `ApplicationController.render` smoke attempt fails because the app
layout expects Devise/Warden; use a temporary Rails server plus curl against
`/dev/kitchen_sink` and `/lookbook` instead.

## Catchup 2026-07-16 (B6)

### Friction

`TabsComponent` exists under `lib/jumpstart/app/components/`, so the B6
collision check had to include engine-owned component paths before installing.
Jordan approved the `UiTabsComponent` fallback.

### Mistakes

None.

### Observations

For direct `Pagy::Offset` preview/test data, provide a `Pagy::Request` or the
link helpers cannot derive a base URL. Rails Blocks' B6 navigation controllers
can stay local without adding third-party imports. Browser automation remains
unavailable here; a temporary Puma process plus curl is the dependable smoke
path for kitchen sink and Lookbook.

## Catchup 2026-07-16 (B7)

### Friction

None. The `card` dry-run generated only a Ruby ViewComponent and template, so
no Stimulus, importmap, vendoring, or CDN work was required.

### Mistakes

None.

### Observations

For a Rails Blocks component that must be flattened, write the `FooComponent`
test before the install so it fails for the missing constant, then normalize
the generated namespace. Generated nested-module indentation needs a RuboCop
auto-format pass after that normalization. Browser automation remains
unavailable; use a temporary Puma process with curl for `/dev/kitchen_sink` and
`/lookbook`, and preserve the browser-only network and interactive checks for a
browser-enabled session.

## Catchup 2026-07-16 (wrap-up)
Nothing notable.

## Catchup 2026-07-16 (COV-13 Task 1)

### Friction

The plan’s `test:system TEST=...` verification syntax is incompatible with this
checkout, and `-n` emits a deprecation warning. Use the positional test-file
form with `-i` instead.

### Mistakes

The initial system test used `click_button` with aria-labels. This Capybara
version did not resolve those controls; CSS attribute selectors are reliable.

### Observations

The COV-13 system-test skeleton intentionally stays partly red while its menu,
notification, flash, and footer implementation tasks remain pending. Verify
only the cases owned by the current task, then retain the shared suite for the
later tasks to turn green.

## Catchup 2026-07-16 (COV-13 Tasks 2-5)

### Friction

The default test configuration has personal accounts and a non-development
Rails environment, so the shared system-test account-switcher and dev-menu
cases need narrow test-only stubs to exercise their production-gated branches.

### Mistakes

The menu review initially surfaced stale `.account-menu .name` integration
assertions and an unsupported `data_turbo` option passed through
`DropdownComponent#with_item_link`. Update the markup assertions to the
accessible trigger and use `with_item_custom` for non-Turbo links.

### Observations

The four menu partials are independent enough to implement in parallel after
the navbar/test skeleton exists. The full shell system suite correctly stays
red at the flash assertion until Task 6, so run only the cases owned by the
current task during phased execution.

## Catchup 2026-07-17 (COV-15 Tasks 1-3)

### Friction

The plan’s Clone task marked completion in its task heading rather than in the
status table; correct the table because `/execute-plan` uses it to determine
the next task.

### Mistakes

Do not invoke RuboCop directly on `.erb` paths in this repository: it parses
them as Ruby. Use the project-wide RuboCop command instead.

### Observations

`PlanCardComponent` must include `PlanHelper` for Lookbook preview rendering;
the component render context does not reliably expose `formatted_plan_interval`
through `helpers`. For a `ButtonComponent` link, pass an explicit path string
such as `api_token_path(record)`, not the record itself. `ButtonComponent`'s
`href` expects a URL string and does not perform polymorphic routing.

## Catchup 2026-07-17 (COV-15 Tasks 4-10)

### Friction

Task 6's catalog `CheckboxComponent` lacks the hidden unchecked value Rails
forms normally generate. The plan correctly required a stop; Jordan approved
an explicit hidden `"0"` field before each checkbox.

### Mistakes

The first Task 8 component migration changed the lazy-i18n scope for
`pricing_link_to`, causing pricing tests to look for `pricing.show.get_started`.
Do not assume a caller block preserves a layout partial's translation scope.

### Observations

For this plan, use `FormFieldComponent#with_input` around raw Rails fields to
retain options. Stripe embedded checkout is an opaque host: use `cmp -s`
against the engine source after copying it. Full authenticated-template
rendering through `ApplicationController.render` remains unsuitable without
Devise/Warden state; the normal Rails suite is the reliable gate.
