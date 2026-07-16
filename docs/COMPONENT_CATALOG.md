# Component Catalog

## Quick Reference

| Component | Purpose | Key args | Preview |
| --- | --- | --- | --- |
| `ButtonComponent` | Renders an action button or link with visual variants, sizes, and states. | `text`, `variant`, `size`, `style`, `href` | `ButtonComponentPreview` |
| `FormFieldComponent` | Wraps a labeled raw form control with helper, error, required, and layout states. | `label`, `name`, `size`, `variant`, `error` | `FormFieldComponentPreview` |

## Component Details

### ButtonComponent

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

**Preview:** `ButtonComponentPreview`

**Usage:**

```erb
<%= render ButtonComponent.new(text: "Save changes") %>
```

### FormFieldComponent

**Purpose:** Wraps a raw input, textarea, or select using the shared
`form-control` class with a label, helper text, or error message.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `label` | `String` | `nil` | Visible label text. |
| `name` | `String` | `nil` | Used to generate the control ID when `id` is omitted. |
| `id` | `String` | generated | ID associated with the label. |
| `required` | `Boolean` | `false` | Shows the required indicator. |
| `disabled` | `Boolean` | `false` | Applies disabled label and helper styling. |
| `helper_text` | `String` | `nil` | Supporting text below the control. |
| `error` | `String` | `nil` | Error text, shown instead of helper text. |
| `size` | `Symbol` | `:md` | Label and message size: `:sm`, `:md`, or `:lg`. |
| `variant` | `Symbol` | `:default` | Layout: `:default`, `:floating`, `:stacked`, or `:inline`. |
| `label_hidden` | `Boolean` | `false` | Visually hides the label while retaining it for assistive technology. |
| `classes` | `String` | `nil` | Additional wrapper classes. |
| `label_classes` | `String` | `nil` | Additional label classes. |
| `input_wrapper_classes` | `String` | `nil` | Additional control-wrapper classes. |

**Slots:** `with_input` supplies the raw `<input>`, `<textarea>`, or
`<select class="form-control">`. `with_addon_left` and `with_addon_right`
add inline content beside the control.

**Variants:** `default`, `floating`, `stacked`, and `inline`.

**States:** Supports helper text, error text, required and disabled labels, and
small, medium, and large text treatments. Apply `form-control`,
`form-control error`, and native `disabled` to the supplied control as needed.

**Preview:** `FormFieldComponentPreview`

**Usage:**

```erb
<%= render FormFieldComponent.new(label: "Email", name: "user[email]", required: true) do |component| %>
  <% component.with_input do %>
    <input class="form-control" id="user_email" name="user[email]" type="email">
  <% end %>
<% end %>
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
