import { Controller } from "@hotwired/stimulus"

// Bridges server-rendered flash toasts (see FlashHelper#toasts) into the
// Rails Blocks toast system (UiToastComponent + ui_toast_controller.js),
// which is JS-driven and only shows toasts in response to a "toast-show"
// window event.
export default class extends Controller {
  static values = {
    type: { type: String, default: "default" },
    message: String,
    description: String,
    autoDismiss: { type: Boolean, default: true }
  }

  connect() {
    window.dispatchEvent(new CustomEvent("toast-show", {
      detail: {
        type: this.typeValue,
        message: this.messageValue,
        description: this.descriptionValue,
        autoDismiss: this.autoDismissValue
      }
    }))
  }
}
