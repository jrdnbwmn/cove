import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: { type: String, default: "success" },
    message: { type: String, default: "Toast preview" },
    description: { type: String, default: "This toast was triggered from the component preview." }
  }

  show() {
    window.dispatchEvent(new CustomEvent("toast-show", {
      detail: {
        type: this.typeValue,
        message: this.messageValue,
        description: this.descriptionValue
      }
    }))
  }
}
