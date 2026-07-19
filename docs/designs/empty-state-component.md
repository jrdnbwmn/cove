> Ticket: COV-18
> Branch: feature/cov-18-empty-state-component

# Feature: EmptyState design-system component

## Problem

The design system has no shared primitive for "there's nothing here" moments —
"no records yet" onboarding, empty search/filter results, and blank onboarding
screens. Every upcoming feature slice (and the error/empty-state project) assumes
this component already exists. This ticket builds that foundation primitive.

## Approach

Add a new `EmptyStateComponent` (`app/components/`) following existing component
conventions (`CardComponent`, `AlertComponent`, `ButtonComponent`) and design
tokens. No new gems.

It renders a centered vertical stack: optional icon/illustration, a required
title, an optional description, and optional primary/secondary action slots.
Bare (no chrome) by default, with an opt-in bordered "well" variant. A single
`size` prop scales the whole thing to fit its context (compact inside a table,
large for full-page onboarding).

The icon is a **slot that accepts raw SVG/illustration markup** — the caller
supplies it. This keeps the component dependency-free and means it works
unchanged if/when an icon family (see Follow-ups) is added later: callers just
pass `lucide_icon("inbox")` into the slot instead of hand-written SVG.

### Component API

```erb
<%= render EmptyStateComponent.new(
      title: "No projects yet",
      description: "Create your first project to get started.",
      size: :md,            # :sm | :md | :lg  (default :md)
      bordered: false,      # true = wrap in a subtle dashed well
      heading_level: 2      # 1..6, sets the title's heading tag (default 2)
    ) do |c| %>
  <% c.with_icon do %><svg>…</svg><% end %>            <%# optional: raw SVG/illustration %>
  <% c.with_primary_action do %>                        <%# optional %>
    <%= render ButtonComponent.new(text: "New project", href: new_project_path) %>
  <% end %>
  <% c.with_secondary_action do %>                       <%# optional %>
    <%= render ButtonComponent.new(text: "Learn more", variant: :ghost, href: docs_path) %>
  <% end %>
<% end %>
```

Rendered structure (centered, `text-center`):

```
[ icon ]                 ← optional (with_icon slot), in a muted rounded-full backdrop, aria-hidden
Title                    ← required, semantic heading (level configurable)
Description              ← optional, muted text
[Primary] [Secondary]    ← optional action slots, side by side
```

**Props**

| Prop | Type | Default | Notes |
| --- | --- | --- | --- |
| `title` | `String` | — (required) | The heading text. |
| `description` | `String` | `nil` | Optional supporting text below the title. |
| `size` | `Symbol` | `:md` | `:sm` / `:md` / `:lg` — scales icon, text, and padding. |
| `bordered` | `Boolean` | `false` | `true` wraps content in a dashed bordered well. |
| `heading_level` | `Integer` | `2` | `1..6`; sets the title's `<h*>` tag for correct document outline. |
| `classes` | `String` | `nil` | Additional wrapper classes (matches other components). |

**Slots** (all optional): `with_icon`, `with_primary_action`, `with_secondary_action`.

### Sizes

One `size` prop scales three things together so the component fits its context —
compact inside a table (`:sm`), airy for full-page onboarding (`:lg`).

| size | icon | title | description | vertical padding |
| --- | --- | --- | --- | --- |
| `:sm` | ~32px | `text-base` | `text-sm` | `py-8` |
| `:md` (default) | ~48px | `text-lg` | `text-sm` | `py-12` |
| `:lg` | ~64px | `text-xl` | `text-base` | `py-16` |

### Styling / tokens

- Wrapper: `flex flex-col items-center text-center`; text constrained (`max-w-sm`)
  so long descriptions wrap cleanly.
- Icon backdrop: `rounded-full bg-neutral-100 dark:bg-neutral-800`,
  `text-neutral-400`, sized per `size`; marked `aria-hidden` (decorative).
- Title: `text-neutral-900 dark:text-neutral-100`, `font-semibold`.
- Description: muted `text-neutral-500 dark:text-neutral-400`.
- Actions: centered `flex gap-3` row, top margin scaled by size.
- `bordered: true`: `border border-dashed border-black/10 dark:border-white/10`
  with card rounding (`rounded-xl`) and padding — reuses existing card tokens.

Uses the same neutral token vocabulary as `CardComponent` / `AlertComponent`.
Keep the inert `dark:` utilities per the project's dark-mode decision.

## Acceptance Criteria

- `EmptyStateComponent` renders all documented variants in Lookbook and on the
  kitchen sink page (`dev/kitchen_sink`).
- `docs/COMPONENT_CATALOG.md` (Quick Reference + Component Details) and the
  kitchen sink page are updated.
- A component test covers the documented behavior and passes.
- `bin/rails test` is green; no behavior changes elsewhere in the app.

## Prototype

None. Visual design follows existing component conventions and tokens; no
external prototype to match.

## Data Model

None. This is a presentational ViewComponent — no models, migrations, or
persistence.

## Screens / Flows

Not a user flow — a reusable UI primitive. It surfaces in these contexts (built
by later tickets, not here):

- **No records yet** — full-page onboarding ("No projects yet — create your first").
- **Empty search/filter results** — compact, inside a table/card ("No results found").
- **Nothing here** — generic blank sections.

### Lookbook previews (required)

1. `default` — icon + title + description + primary action.
2. `no_icon` — title + description + primary action (icon slot omitted).
3. `primary_only` — icon + title + primary action, no secondary.
4. `primary_and_secondary` — icon + title + description + both actions.
5. `empty_search_results` — `:sm` size, magnifier icon, "No results found" +
   short description, secondary "Clear filters" ghost action.

Plus (bonus, useful for the catalog): a `sizes` showcase and a `bordered` example.
Sample SVGs are hand-written in the preview (mirrors `AlertComponent`), so no
icon dependency is required.

### Kitchen sink

Add an "Empty State" section rendering a representative couple of variants
(e.g. default full-page + compact empty-search-results).

## Edge Cases

- **No icon slot** → the muted icon backdrop is not rendered (no empty circle).
- **No action slots** → the action row is not rendered.
- **Secondary-only** (no primary) → allowed; renders the secondary alone.
- **Long title/description** → centered and wrapped within the max-width.
- **`title` required** → keyword arg with no default (like `AlertComponent#title`).
- **`heading_level` out of range** → clamp/validate to `1..6`, default `2`.
- **Invalid `size`** → fall back to `:md` (matches how other components guard
  their enum props, e.g. `CardComponent`).

## Scope

**In:**
- New `EmptyStateComponent` (`app/components/empty_state_component.rb` + `.html.erb`).
- Lookbook preview with the 5 required variants (+ bonus sizes/bordered).
- `docs/COMPONENT_CATALOG.md` and `dev/kitchen_sink` updates.
- A component test.

**Deferred:**
- Wiring EmptyState into any real feature/page (later feature slices).
- Error pages (COV-19/20), Alert/flash consistency (COV-21), timeout states
  (COV-22) — separate tickets this one unblocks.

## Follow-ups (separate tickets — not built here)

- **Icon family for the design system.** Recommend the `rails_icons` gem
  (ships Lucide + Heroicons as inline SVG via a Rails helper). Natural to do
  *before* the error-page rebuilds (COV-19/20), which also need a consistent
  icon set. EmptyState needs no changes when it lands — callers just pass
  `lucide_icon(...)` into the icon slot. Requires a gem, so it's its own chore
  ticket (get approval first).

## Open Questions

None.
