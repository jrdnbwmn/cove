# Component Catalog

## Quick Reference

| Component | Purpose | Key args | Preview |
| --- | --- | --- | --- |

## Component Details

No components have been cataloged yet.

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
