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
| `UiModalComponent` | Renders a Rails Blocks dialog without replacing Jumpstart's modal. | `title`, `size`, `prevent_dismiss`, `trigger_text` | `UiModalComponentPreview` |
| `DropdownComponent` | Renders an accessible, positioned menu with item slots. | `trigger_text`, `placement`, `hover`, `portal` | `DropdownComponentPreview` |
| `NavbarComponent` | Renders responsive primary navigation with optional dropdown panels. | `variant`, `sticky`, `show_mobile_menu` | `NavbarComponentPreview` |
| `BreadcrumbComponent` | Renders an accessible page hierarchy trail. | `items`, `separator`, `variant`, `truncate_at` | `BreadcrumbComponentPreview` |
| `UiTabsComponent` | Renders Rails Blocks tabs without replacing Jumpstart's tabs. | `variant`, `orientation`, `default_tab`, `url_sync` | `UiTabsComponentPreview` |
| `PaginationComponent` | Renders Pagy navigation in full, compact, or minimal form. | `pagy`, `variant`, `size`, `frame_id` | `PaginationComponentPreview` |
| `SidebarComponent` | Renders responsive primary navigation with collapsible groups. | `variant`, `collapsible`, `storage_key`, `position` | `SidebarComponentPreview` |
| `CardComponent` | Renders a content container with optional image, header, body, and footer slots. | `variant`, `padding`, `shadow`, `divide`, `hoverable` | `CardComponentPreview` |
| `AvatarComponent` | Renders a user or account image with accessible initials fallback and optional online status. | `alt`, `src`, `fallback`, `size`, `status` | `AvatarComponentPreview` |
| `TableComponent` | Renders a responsive, accessible data table with row and column slots. | `striped`, `hoverable`, `density`, `sticky_header` | `TableComponentPreview` |

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

### UiModalComponent

**Purpose:** Renders the Rails Blocks native-dialog modal for new product UI.
Use this component instead of `ModalComponent`, which belongs to Jumpstart and
continues to serve its existing behavior.

**Arguments:** Use `size`, `title`, `show_close_button`, `prevent_dismiss`,
`lazy_load`, `turbo_frame_src`, `auto_focus`, `classes`, `trigger_text`, and
`trigger_classes` to configure the dialog and its trigger.

**Variants:** Supports `:sm`, `:md`, `:lg`, `:xl`, `:"2xl"` through `:"7xl"`,
and `:fullscreen` sizes. Header and footer slots replace the default title and
add dialog actions.

**States:** Supports dismissible dialogs, non-dismissible confirmations, lazy
content, and keyboard/backdrop close behavior. It uses `ui-modal`, leaving
Jumpstart's `modal` controller intact.

**Preview:** `UiModalComponentPreview`

**Usage:**

```erb
<%= render UiModalComponent.new(title: "Archive project", trigger_text: "Archive") do |modal| %>
  <p>Archived projects can be restored later.</p>
  <% modal.with_footer do %>
    <%= render ButtonComponent.new(text: "Cancel", variant: :secondary, data: { action: "click->ui-modal#close:prevent" }) %>
  <% end %>
<% end %>
```

### DropdownComponent

**Purpose:** Renders an accessible menu with links, buttons, labels, dividers,
custom items, and nested submenus. Floating UI positions the menu locally with
no CDN dependency.

**Arguments:** Use `placement`, `trigger_text`, `trigger_variant`,
`trigger_icon`, `auto_close`, `hover`, `portal`, `width`, `classes`,
`trigger_classes`, `menu_classes`, `menu_role`, `trigger_aria_haspopup`,
`trigger_aria_controls`, `menu_id`, and `flip_class` to configure the menu.

**Slots:** `with_item_link`, `with_item_button`, `with_item_submenu`,
`with_item_label`, `with_item_divider`, and `with_item_custom` create menu
content. `with_trigger` supplies a custom trigger.

**States:** Supports default click menus, hover menus, nested submenus,
disabled and destructive items, and keyboard navigation. It uses
`ui-dropdown-popover` and `ui-menu`, leaving Jumpstart's `dropdown` controller
intact.

**Safety:** Icon and custom-trigger markup may be rendered as HTML. Pass only
static, developer-authored markup to those options and slots.

**Preview:** `DropdownComponentPreview`

**Usage:**

```erb
<%= render DropdownComponent.new(trigger_text: "Project actions") do |dropdown| %>
  <% dropdown.with_item_link(text: "Settings", href: project_settings_path) %>
  <% dropdown.with_item_divider %>
  <% dropdown.with_item_button(text: "Archive", destructive: true) %>
<% end %>
```

### NavbarComponent

**Purpose:** Renders responsive primary navigation with optional dropdown panels.

**Arguments:** Use `variant`, `sticky`, `show_mobile_menu`,
`mobile_menu_content_id`, and `classes` to configure the navigation container.

**Slots:** `with_logo`, `with_item`, `with_dropdown_content`, and `with_actions`.

**Variants:** `:default`, `:bordered`, and `:transparent`.

**Dependencies:** Uses the locally installed `navbar` Stimulus controller; no
external dependency is added.

**Preview:** `NavbarComponentPreview`

**Usage:**

```erb
<%= render NavbarComponent.new do |navbar| %>
  <% navbar.with_item(label: "Dashboard", href: dashboard_path) %>
<% end %>
```

### BreadcrumbComponent

**Purpose:** Renders an accessible hierarchy trail with a marked current page.

**Arguments:** Use `items`, `separator`, `variant`, `show_home_icon`,
`truncate_at`, `current_max_width`, and `classes` to configure the trail.

**Variants:** `:default`, `:with_background`, and `:with_icons`.

**Safety:** Per-item `icon` markup is rendered as HTML. Supply only static,
developer-authored SVG markup.

**Preview:** `BreadcrumbComponentPreview`

**Usage:**

```erb
<%= render BreadcrumbComponent.new(items: [{label: "Home", href: root_path}, {label: "Settings"}]) %>
```

### UiTabsComponent

**Purpose:** Renders Rails Blocks tabs for new product UI. Use this component
instead of `TabsComponent`, which belongs to Jumpstart and remains unchanged.

**Arguments:** Use `variant`, `orientation`, `default_tab`, `url_sync`,
`scroll_to_anchor`, `auto_switch`, `lazy_load`, `arrow_focus_only`, and class
options to configure the tab group.

**Slots:** `with_tab` adds a tab button; `with_panel` adds its matching panel.

**Variants:** `:pills`, `:underline`, and `:low_contrast`; `:bordered` remains
a legacy alias for `:low_contrast`.

**Dependencies:** Uses the collision-free `ui-tabs` controller. Jumpstart's
existing `tabs` controller and `TabsComponent` remain intact.

**Safety:** Tab `icon` markup is rendered as HTML. Supply only static,
developer-authored SVG markup.

**Preview:** `UiTabsComponentPreview`

**Usage:**

```erb
<%= render UiTabsComponent.new do |tabs| %>
  <% tabs.with_tab(title: "Overview", id: "overview") %>
  <% tabs.with_panel do %>Overview content<% end %>
<% end %>
```

### PaginationComponent

**Purpose:** Renders accessible Pagy pagination using the app's existing Pagy
object.

**Arguments:** Use `pagy`, `variant`, `size`, `frame_id`, `show_info`,
`show_page_form`, `show_limit_form`, `limit_options`, `preserve_params`,
`request_path`, and `classes` to configure navigation.

**Variants:** `:full`, `:compact`, and `:minimal`.

**Preview:** `PaginationComponentPreview`

**Usage:**

```erb
<%= render PaginationComponent.new(pagy: @pagy, frame_id: "projects") %>
```

### SidebarComponent

**Purpose:** Renders a responsive navigation sidebar with optional collapsible
sections and mobile drawer behavior.

**Arguments:** Use `variant`, `collapsible`, `default_collapsed`, `position`,
`storage_key`, `width`, `collapsed_width`, `min_height_class`,
`show_mobile_toggle`, and `classes` to configure the layout.

**Slots:** `with_logo`, `with_item`, `with_section`, `with_footer`, and
`with_collapsed_footer`.

**Variants:** `:default`, `:bordered`, and `:minimal`.

**Dependencies:** Uses the locally installed `sidebar` Stimulus controller and
the existing Jumpstart tooltip controller for collapsed-item labels.

**Safety:** Item and section-item `icon` markup is rendered as HTML. Supply
only static, developer-authored SVG markup.

**Preview:** `SidebarComponentPreview`

**Usage:**

```erb
<%= render SidebarComponent.new do |sidebar| %>
  <% sidebar.with_item(label: "Dashboard", href: dashboard_path, active: true) %>
  <p>Page content</p>
<% end %>
```

### CardComponent

**Purpose:** Renders related content in a container with optional image, header,
body, and footer slots.

**Arguments:** Use `variant`, `padding`, `shadow`, `rounded`, `border`,
`hoverable`, `clickable`, `divide`, `full_width_mobile`, and `classes` to
configure the card.

**Slots:** `with_header`, `with_body`, `with_footer`, and `with_image` compose
the card. The default block content renders in the body when no body slot is
provided.

**Variants:** `:default`, `:elevated`, and `:well`.

**States:** Supports optional section dividers, hover and clickable treatments,
and edge-to-edge mobile rendering.

**Preview:** `CardComponentPreview`

**Usage:**

```erb
<%= render CardComponent.new(divide: true) do |card| %>
  <% card.with_header { "Project summary" } %>
  <% card.with_body { "Three tasks are ready." } %>
  <% card.with_footer { "View project" } %>
<% end %>
```

### AvatarComponent

**Purpose:** Renders a user or account avatar with a supplied image or accessible
initials fallback. Use `AvatarComponent::GroupComponent` for compact member
groups.

**Arguments:** Use `alt`, `src`, `fallback`, `size`, `status`, `status_label`,
`pulse`, `classes`, `html_options`, and `image_options`. `alt` is required;
when `src` is absent, initials are derived from it.

**Variants:** Sizes are `:xs`, `:sm`, `:md`, `:lg`, and `:xl`. The only status
variant is `:online` and includes non-color status text for assistive technology.

**Slots:** `AvatarComponent::GroupComponent` provides `with_avatar` and accepts
`remaining_count`, `label`, and `animated` for a member group.

**Preview:** `AvatarComponentPreview`

**Usage:**

```erb
<%= render AvatarComponent.new(src: avatar_url_for(current_user), alt: current_user.name) %>
```

### TableComponent

**Purpose:** Renders a responsive semantic table for account lists and other
structured data.

**Arguments:** Use `striped`, `hoverable`, `bordered`, `density`,
`sticky_header`, `rounded`, `full_width`, `responsive`, `max_height`,
`container`, `classes`, and `container_classes`. Pass a Tailwind max-height
utility such as `"max-h-96"` to `max_height` when the header should scroll.

**Slots:** `with_caption`, `with_head`, `with_body`, and `with_foot` support
custom markup. The standard API uses `with_column`, `with_row`, and each row's
`with_cell` slots.

**Variants:** `density` accepts `:default` or `:compact`; `rounded` accepts
`:none`, `:sm`, `:md`, `:lg`, or `:xl`.

**Preview:** `TableComponentPreview`

**Usage:**

```erb
<%= render TableComponent.new(striped: true) do |table| %>
  <% table.with_column(label: "Name") %>
  <% table.with_row do |row| %>
    <% row.with_cell(primary: true) { current_user.name } %>
  <% end %>
<% end %>
```

## On-demand component policy

When a feature needs a generic primitive not already in this catalog, install
only that one Rails Blocks component through the `rails-blocks-cli` workflow:
confirm its API, dry-run it as a ViewComponent, self-host any dependency,
preserve Jumpstart controllers, add tests and previews, then update this catalog
and the component map. Do not bulk-install the Rails Blocks catalog.

Native file inputs remain wrapped by `FormFieldComponent` until Rails Blocks
ships a matching primitive; do not create a parallel base component.

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
