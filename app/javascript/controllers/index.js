// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
import { Alert, Dropdown, Modal, Tabs, Popover, Toggle, Slideover } from "tailwindcss-stimulus-components"
application.register('alert', Alert)
application.register('dropdown', Dropdown)
application.register('modal', Modal)
application.register('tabs', Tabs)
application.register('popover', Popover)
application.register('toggle', Toggle)
application.register('slideover', Slideover)

// AIDEV-NOTE: Eager loading imports every controller at boot. Lazy loading imports only
// controllers present in the DOM (including later additions); ui-* filenames still avoid
// Rails Blocks and Jumpstart identifier collisions.
lazyLoadControllersFrom("controllers", application)
