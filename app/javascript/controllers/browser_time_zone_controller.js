import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    try {
      this.element.value = Intl.DateTimeFormat().resolvedOptions().timeZone || ""
    } catch {
      // AIDEV-NOTE: Blank detection lets signup use the family's server-side fallback.
      this.element.value = ""
    }
  }
}
