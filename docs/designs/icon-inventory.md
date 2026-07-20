# Icon Inventory

This is the migration backlog for the follow-up icon-replacement ticket. The
scan (`grep -rn "tag.svg\\|<svg" app/components app/views`) found 53 SVG
occurrences in 33 source files: 16 design-system component files and 17 app
view files. The Lucide names below are proposed mappings, not replacements made
by this ticket. Preserve each location's existing interaction, visibility
states, sizing, and accessibility treatment during migration.

## Completed in COV-27

| Location | Purpose | Status / Lucide mapping |
| --- | --- | --- |
| `app/components/alert_component.rb` | Variant feedback icons | Done in Task 2: `circle-check`, `circle-alert`, `triangle-alert`, and `info`. |

## Design-system components

| Location | Purpose | Suggested Lucide icon |
| --- | --- | --- |
| `app/components/badge_component.html.erb` | Remove a dismissible badge | `x` |
| `app/components/breadcrumb_component.rb` | Home item and breadcrumb separator | `house`, `chevron-right` |
| `app/components/button_component.rb` | Loading spinner | `loader-circle` with the existing spin class |
| `app/components/dropdown_component.rb` | Default trigger chevron and icon-only kebab menu | `chevron-down`, `ellipsis` |
| `app/components/dropdown_component/submenu_component.rb` | Nested-menu disclosure | `chevron-right` |
| `app/components/loading_indicator_component.html.erb` | Stepped and circular loading spinners | `loader-circle` (verify whether either custom animation should remain) |
| `app/components/navbar_component.rb` | Mobile navigation toggle | `menu` |
| `app/components/navbar_component/item_component.rb` | Dropdown-item disclosure | `chevron-down` |
| `app/components/pagination_component.rb` | Previous and next navigation controls | `chevron-left`, `chevron-right` |
| `app/components/password_component.html.erb` | Password visibility toggle and requirement states | `eye`, `circle`, `circle-check` |
| `app/components/plan_card_component.html.erb` | Included plan feature | `check` |
| `app/components/sidebar_component.html.erb` | Expand, collapse, and mobile navigation controls | `panel-left-open`, `panel-left-close`, `menu` |
| `app/components/sidebar_component/section_component.html.erb` | Section disclosure | `chevron-right` |
| `app/components/sidebar_component/section_item_component.html.erb` | Per-item overflow actions | `ellipsis` |
| `app/components/switch_component.html.erb` | Unchecked and checked switch states | `x`, `check` |
| `app/components/ui_modal_component.rb` | Close control | `x` |

## App views

| Location | Purpose | Suggested Lucide icon |
| --- | --- | --- |
| `app/views/account_users/edit.html.erb` | Account-to-member breadcrumb separator | `chevron-right` |
| `app/views/accounts/account_invitations/edit.html.erb` | Account-to-invitation breadcrumb separator | `chevron-right` |
| `app/views/accounts/account_invitations/new.html.erb` | Account-to-new-invitation breadcrumb separator | `chevron-right` |
| `app/views/accounts/edit.html.erb` | Account settings breadcrumb separator | `chevron-right` |
| `app/views/accounts/new.html.erb` | New-account heading icon | `building-2` |
| `app/views/accounts/show.html.erb` | Account members link/action | `users` |
| `app/views/api_tokens/edit.html.erb` | API-token breadcrumb/action icons | `key-round`, `chevron-right` |
| `app/views/api_tokens/new.html.erb` | New API-token heading icon | `key-round` |
| `app/views/api_tokens/show.html.erb` | API-token heading and copy affordance | `key-round`, `copy` |
| `app/views/application/_account_menu.html.erb` | Account/team menu entry | `users` |
| `app/views/application/_dev_menu.html.erb` | Development menu mark | `wrench` (confirm desired product meaning before replacing the custom mark) |
| `app/views/application/_navbar.html.erb` | Responsive navigation toggle | `menu` |
| `app/views/application/_notifications.html.erb` | Notifications entry | `bell` |
| `app/views/billing/_charges.html.erb` | Charge receipt and refund status | `receipt`, `rotate-ccw` |
| `app/views/billing/subscriptions/payment_methods/new.html.erb` | Billing breadcrumb separator | `chevron-right` |
| `app/views/checkouts/show.html.erb` | Included plan feature and checkout-help marker | `check`, `circle-question-mark` |
| `app/views/dev/kitchen_sink/show.html.erb` | Existing EmptyState examples | `folder`, `search` |

## Out of scope

SVG markup injected by JavaScript controllers or CSS is not part of this
inventory because it uses a different mechanism. This includes locations such
as `app/javascript/controllers/select_controller.js` and CSS such as
`app/assets/stylesheets/forms.css`; assess those separately before changing
them.
