# Component Catalog

## Quick Reference

| Component | Purpose | Key args | Preview |
| --- | --- | --- | --- |
| `Buttons::Component` | Renders an action button or link with visual variants, sizes, and states. | `text`, `variant`, `size`, `style`, `href` | `Buttons::ComponentPreview` |

## Component Details

### Buttons::Component

**Purpose:** Renders a reusable action button or link with primary, secondary,
outline, ghost, and destructive variants.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `text` | `String` | `nil` | Button label; optional for icon-only buttons. |
| `variant` | `Symbol` | `:primary` | Visual variant: `:primary`, `:secondary`, `:outline`, `:ghost`, or `:destructive`. |
| `size` | `Symbol` | `:md` | Size: `:xs`, `:sm`, `:md`, or `:lg`. |
| `style` | `Symbol` | `:basic` | Visual treatment: `:basic` or `:fancy`. |
| `pill` | `Boolean` | `false` | Uses a fully rounded pill shape. |
| `disabled` | `Boolean` | `false` | Disables the rendered button or link. |
| `loading` | `Boolean` | `false` | Shows a spinner and disables the control. |
| `icon` | `String` | `nil` | SVG markup for an optional icon. |
| `icon_position` | `Symbol` | `:left` | Places the icon at `:left` or `:right`. |
| `icon_only` | `Boolean` | `false` | Renders an icon-only control. |
| `full_width` | `Boolean` | `false` | Makes the control span its container width. |
| `href` | `String` | `nil` | Renders an anchor instead of a button. |
| `type` | `String` | `"button"` | Native button type when rendering a button. |
| `classes` | `String` | `nil` | Additional CSS classes. |
| `data` | `Hash` | `{}` | HTML data attributes. |

**Variants:** `primary`, `secondary`, `outline`, `ghost`, and `destructive`.
The basic primary variant uses the shared `bg-primary` and
`text-primary-foreground` design tokens.

**States:** Supports disabled and loading states. Loading shows a spinner and
disables the control.

**Preview:** `Buttons::ComponentPreview`

**Usage:**

```erb
<%= render Buttons::Component.new(text: "Save changes") %>
```

### Component Details template

Copy this template for each component. Keep the sections that apply and remove
the rest.

````markdown
### ComponentName

**Purpose:** Brief description of the component and when to use it.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `argument` | `Type` | `default` | What this argument controls. |

**Variants:** Available variants, if applicable.

**States:** Loading, empty, and error behavior, if applicable.

**Preview:** `ComponentNamePreview`

**Usage:**

```erb
<%= render ComponentName.new(argument: value) %>
```
````
