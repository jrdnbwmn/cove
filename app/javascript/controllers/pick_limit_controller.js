import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="pick-limit"
export default class extends Controller {
  static targets = ["checkbox", "submit"];
  static values = { limit: Number };

  connect() {
    this.update();
  }

  change() {
    this.update();
  }

  update() {
    const selectedCount = this.checkboxTargets.filter((checkbox) => checkbox.checked).length;
    const limitReached = selectedCount >= this.limitValue;

    this.checkboxTargets.forEach((checkbox) => {
      checkbox.disabled = limitReached && !checkbox.checked;
    });
    this.submitTarget.disabled = selectedCount !== this.limitValue;
  }
}
