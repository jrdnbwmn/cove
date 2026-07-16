# Component Catalog

## Quick Reference

| Component | Purpose | Key args | Preview |
| --- | --- | --- | --- |
| `ButtonComponent` | Renders an action button or link with visual variants, sizes, and states. | `text`, `variant`, `size`, `style`, `href` | `ButtonComponentPreview` |
| `FormFieldComponent` | Wraps a labeled raw form control with helper, error, required, and layout states. | `label`, `name`, `size`, `variant`, `error` | `FormFieldComponentPreview` |
| `CheckboxComponent` | Renders a labeled checkbox with optional supporting text and validation state. | `label`, `name`, `checked`, `disabled`, `error` | `CheckboxComponentPreview` |
| `RadioComponent` | Renders a labeled radio option with optional supporting text and validation state. | `label`, `name`, `value`, `checked`, `disabled` | `RadioComponentPreview` |
| `SwitchComponent` | Renders a toggle switch with label, status, and validation state. | `label`, `name`, `checked`, `show_icons`, `disabled` | `SwitchComponentPreview` |
| `SelectComponent` | Renders a locally enhanced single or multiple select. | `name`, `options`, `selected`, `multiple`, `error` | `SelectComponentPreview` |
| `PasswordComponent` | Renders a password input with visibility toggle and optional guidance. | `name`, `show_strength`, `show_requirements`, `error` | `PasswordComponentPreview` |
| `AlertComponent` | Renders a titled feedback message with a semantic variant and optional icon. | `title`, `description`, `variant`, `show_icon` | `AlertComponentPreview` |
| `BadgeComponent` | Renders a small status/tag label with color, size, dot, and remove-button options. | `text`, `variant`, `size`, `pill`, `dot`, `removable` | `BadgeComponentPreview` |
| `LoadingIndicatorComponent` | Renders a spinner, dots, bars, or progress bar loading indicator. | `type`, `size`, `color`, `text`, `progress` | `LoadingIndicatorComponentPreview` |
| `SkeletonComponent` | Renders a pulsing placeholder shape while content loads. | `variant`, `width`, `height`, `count` | `SkeletonComponentPreview` |
| `UiToastComponent` | Provides the Rails Blocks toast container for new app UI. | `position`, `layout`, `auto_dismiss_duration`, `limit` | `UiToastComponentPreview` |
| `TooltipComponent` | Wraps content with a Rails Blocks tooltip. | `text`, `placement`, `delay`, `trigger`, `kbd` | `TooltipComponentPreview` |

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

### CheckboxComponent

**Purpose:** Renders a labeled native checkbox with optional description,
required, disabled, and error states.

**Arguments:** `label` is required. Use `name`, `value`, `checked`, `disabled`,
`required`, `description`, `size`, `indeterminate`, `error`, `classes`,
`input_classes`, and `label_classes` to configure its form and visual state.

**States:** Supports checked, disabled, required, indeterminate, description,
and error states.

**Preview:** `CheckboxComponentPreview`

**Usage:**

```erb
<%= render CheckboxComponent.new(label: "Receive updates", name: "preferences[updates]", checked: true) %>
```

### RadioComponent

**Purpose:** Renders one labeled radio option for a radio group.

**Arguments:** `label` is required. Use `name`, `value`, `checked`, `disabled`,
`required`, `description`, `size`, `error`, `classes`, `input_classes`, and
`label_classes` to configure the option.

**States:** Supports selected, disabled, required, description, and error states.

**Preview:** `RadioComponentPreview`

**Usage:**

```erb
<%= render RadioComponent.new(label: "Team", name: "plan", value: "team", checked: true) %>
```

### SwitchComponent

**Purpose:** Renders a labeled checkbox switch for an on/off preference.

**Arguments:** Use `label`, `name`, `value`, `checked`, `disabled`, `required`,
`description`, `size`, `show_icons`, `label_position`, `error`, `classes`,
`switch_classes`, and `label_classes` to configure it.

**States:** Supports checked, disabled, required, description, error, and
optional status-icon states.

**Preview:** `SwitchComponentPreview`

**Usage:**

```erb
<%= render SwitchComponent.new(label: "Enable summary", name: "preferences[summary]", checked: true) %>
```

### SelectComponent

**Purpose:** Renders a native select enhanced by the locally vendored
tom-select JavaScript and stylesheet.

**Arguments:** Use `name`, `options`, `selected`, `placeholder`, `multiple`,
`disabled`, `required`, `label`, `description`, `error`, and `size` for the
standard form case. Advanced remote-loading, grouping, tag, and rendering
options mirror the Rails Blocks component API.

**States:** Supports placeholder, single or multiple selection, disabled, error,
and optional searchable/dropdown behavior.

**Preview:** `SelectComponentPreview`

**Usage:**

```erb
<%= render SelectComponent.new(label: "Plan", name: "subscription[plan]", options: [["Starter", "starter"], ["Team", "team"]]) %>
```

### PasswordComponent

**Purpose:** Renders a password field with a Stimulus visibility toggle and
optional strength and requirements guidance.

**Arguments:** Use `label`, `name`, `placeholder`, `required`, `disabled`,
`autocomplete`, `show_toggle`, `show_strength`, `show_requirements`, `error`,
`hint`, `classes`, `input_classes`, and `label_classes` to configure it.

**States:** Supports disabled, error, hint, strength-meter, and requirements
states.

**Preview:** `PasswordComponentPreview`

**Usage:**

```erb
<%= render PasswordComponent.new(name: "user[password]", show_strength: true) %>
```

### AlertComponent

**Purpose:** Renders a titled feedback message with success, error, warning,
info, or neutral variants and an optional icon.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `title` | `String` | required | Alert heading text. |
| `description` | `String` | `nil` | Optional supporting text (may include HTML — see security note). |
| `variant` | `Symbol` | `:success` | `:success`, `:error`, `:warning`, `:info`, or `:neutral`. |
| `show_icon` | `Boolean` | `true` | Shows the variant icon. |
| `custom_icon` | `String` | `nil` | Overrides the variant icon with custom SVG/HTML. |
| `classes` | `String` | `nil` | Additional wrapper classes. |

**Variants:** `success`, `error`, `warning`, `info`, `neutral`. These are
semantic status colors, not the brand `primary` token.

**Security:** `description` is rendered with `.html_safe` (a Rails Blocks
default, to allow links/bold text in the message). Only pass static,
developer-authored strings — never raw user input — or you introduce an XSS
hole.

**Preview:** `AlertComponentPreview`

**Usage:**

```erb
<%= render AlertComponent.new(title: "Saved", description: "Your changes have been applied.", variant: :success) %>
```

### BadgeComponent

**Purpose:** Renders a small status/tag label with color, size, dot, and
remove-button options.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `text` | `String` | required | Badge text content. |
| `variant` | `Symbol` | `:neutral` | `:neutral`, `:red`, `:orange`, `:yellow`, `:green`, `:blue`, `:purple`, or `:pink`. |
| `size` | `Symbol` | `:md` | `:sm` or `:md`. |
| `pill` | `Boolean` | `false` | Fully rounded pill shape. |
| `dot` | `Boolean` | `false` | Shows a colored status dot. |
| `removable` | `Boolean` | `false` | Shows a remove/close button. |
| `classes` | `String` | `nil` | Additional wrapper classes. |

**Preview:** `BadgeComponentPreview`

**Usage:**

```erb
<%= render BadgeComponent.new(text: "Published", variant: :green, dot: true) %>
```

### LoadingIndicatorComponent

**Purpose:** Renders a spinner, dots, bars, or progress bar loading state.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `type` | `Symbol` | `:spinner` | `:spinner`, `:dots`, `:bars`, or `:progress`. |
| `size` | `Symbol` | `:md` | `:xs`, `:sm`, `:md`, `:lg`, or `:xl`. |
| `color` | `Symbol` | `:neutral` | `:neutral`, `:primary`, or a semantic color (`:red`, `:orange`, `:yellow`, `:green`, `:blue`, `:purple`, `:pink`). |
| `text` | `String` | `nil` | Optional loading text. |
| `progress` | `Integer` | `nil` | Percentage (0-100), used with `type: :progress`. |
| `stepped` | `Boolean` | `false` | iOS-style stepped spinner animation. |
| `classes` | `String` | `nil` | Additional wrapper classes. |

**Variants:** `:primary` uses the shared `bg-primary`/`text-primary` design
tokens (this diverges from the Rails Blocks default, which hard-coded
`:primary` to red).

**States:** The `:progress` type sets its fill width with an inline style
since the percentage is an unbounded runtime value with no static Tailwind
class form; dot/bar animation delays use static Tailwind arbitrary-value
classes instead of inline styles.

**Preview:** `LoadingIndicatorComponentPreview`

**Usage:**

```erb
<%= render LoadingIndicatorComponent.new(type: :progress, progress: 65, color: :primary) %>
```

### SkeletonComponent

**Purpose:** Renders a pulsing placeholder shape while content loads.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `variant` | `Symbol` | `:text` | `:text`, `:circle`, `:rectangle`, `:image`, `:button`, or `:input`. |
| `width` | `String` | variant default | Width classes, e.g. `"w-1/2"`. |
| `height` | `String` | variant default | Height classes, e.g. `"h-10"`. |
| `rounded` | `Symbol` | variant default | `:none`, `:sm`, `:md`, `:lg`, `:xl`, `:"2xl"`, or `:full`. |
| `animated` | `Boolean` | `true` | Toggles the pulse animation. |
| `count` | `Integer` | `1` | Renders multiple stacked skeletons. |
| `classes` | `String` | `nil` | Additional classes. |

**Preview:** `SkeletonComponentPreview`

**Usage:**

```erb
<%= render SkeletonComponent.new(variant: :circle) %>
```

### UiToastComponent

**Purpose:** Provides the Rails Blocks toast container and client-side toast
behavior for new application UI.

**Use this component for all new toast work.** `ToastComponent` belongs to
Jumpstart and remains available for its existing behavior; do not use it for new
product UI. Render this container once in the relevant layout, then use the
Rails Blocks toast API from client-side behavior.

**Arguments:**

| Argument | Type | Default | Description |
| --- | --- | --- | --- |
| `position` | `String` | `"top-center"` | `top-*` or `bottom-*` placement. |
| `layout` | `String` | `"default"` | `"default"` stacked or `"expanded"`. |
| `auto_dismiss_duration` | `Integer` | `4000` | Time before dismissal, in milliseconds. |
| `limit` | `Integer` | `3` | Maximum visible toast count. |
| `gap` | `Integer` | `14` | Expanded-layout gap, in pixels. |
| `classes` | `String` | `nil` | Additional container classes. |

**Safety:** Message text, descriptions, and action labels are escaped. The Rails
Blocks client API also supports custom HTML content; pass only static,
developer-authored HTML there, never untrusted user input.

**Dependencies:** Uses the collision-free `ui-toast` Stimulus controller.
Motion is locally vendored through the import map; no CDN dependency is added.

**Preview:** `UiToastComponentPreview`

**Usage:**

```erb
<%= render UiToastComponent.new(position: "bottom-right") %>
```

### TooltipComponent

**Purpose:** Wraps a trigger with a Rails Blocks tooltip that positions itself
with the existing locally vendored Floating UI dependency.

**Arguments:** Use `text`, `placement`, `offset`, `max_width`, `delay`, `size`,
`animation`, `trigger`, `kbd`, `mac_kbd`, `non_mac_kbd`, `arrow`, `classes`,
and `tag` to configure the tooltip.

**States:** Supports desktop hover/focus, touch click, keyboard-shortcut, and
arrow-free variants. It uses `ui-tooltip`, leaving Jumpstart's `tooltip`
controller intact.

**Preview:** `TooltipComponentPreview`

**Usage:**

```erb
<%= render TooltipComponent.new(text: "Helpful information") do %>
  <button type="button">Hover for help</button>
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
