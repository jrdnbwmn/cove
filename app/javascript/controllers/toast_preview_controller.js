import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  show() {
    window.dispatchEvent(new CustomEvent("toast-show", {
      detail: {
        type: "success",
        message: "Toast preview",
        description: "This toast was triggered from the component preview."
      }
    }))
  }
}
