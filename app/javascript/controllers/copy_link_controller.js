import { Controller } from "@hotwired/stimulus"

// Copies a URL to the clipboard and confirms with a toast. The clipboard controller's tooltip needs a
// visible button to anchor to; "…" menu items close on click, so those use this instead.
export default class extends Controller {
  static values = { url: String, message: { type: String, default: "Link copied" } }

  async copy() {
    await navigator.clipboard.writeText(this.urlValue)

    window.dispatchEvent(new CustomEvent("toast-show", {
      detail: { type: "default", message: this.messageValue, description: "", autoDismiss: true }
    }))
  }
}
