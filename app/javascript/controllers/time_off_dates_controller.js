import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["start", "end"]

  updateEnd() {
    if (this.startTarget.value && this.startTarget.value > this.endTarget.value) {
      this.endTarget.value = this.startTarget.value
    }
  }
}
