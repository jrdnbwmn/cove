import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "discardPrompt"];

  connect() {
    this.isDirty = false;
    this.boundMarkDirty = this.markDirty.bind(this);
    this.boundClearDirty = this.clearDirty.bind(this);
    this.boundRequestClose = this.requestClose.bind(this);

    this.dialogTarget.addEventListener("input", this.boundMarkDirty);
    this.dialogTarget.addEventListener("change", this.boundMarkDirty);
    this.dialogTarget.addEventListener("submit", this.boundClearDirty);
    this.dialogTarget.addEventListener("ui-modal:closed", this.boundClearDirty);
    this.dialogTarget.addEventListener("ui-modal:close-request", this.boundRequestClose);
  }

  disconnect() {
    this.dialogTarget.removeEventListener("input", this.boundMarkDirty);
    this.dialogTarget.removeEventListener("change", this.boundMarkDirty);
    this.dialogTarget.removeEventListener("submit", this.boundClearDirty);
    this.dialogTarget.removeEventListener("ui-modal:closed", this.boundClearDirty);
    this.dialogTarget.removeEventListener("ui-modal:close-request", this.boundRequestClose);
  }

  keepEditing() {
    this.hideDiscardPrompt();
  }

  discard() {
    this.clearDirty();
    this.element.dispatchEvent(new CustomEvent("ui-modal-unsaved-changes:discard", {bubbles: true}));
  }

  markDirty(event) {
    if (event.target.closest("form")) this.isDirty = true;
  }

  clearDirty() {
    this.isDirty = false;
    this.hideDiscardPrompt();
  }

  requestClose(event) {
    if (!this.isDirty) return;

    event.preventDefault();
    this.showDiscardPrompt();
  }

  showDiscardPrompt() {
    this.discardPromptTarget.classList.remove("hidden");
    this.notifyVisibilityChanged();
  }

  hideDiscardPrompt() {
    this.discardPromptTarget.classList.add("hidden");
    this.notifyVisibilityChanged();
  }

  notifyVisibilityChanged() {
    this.element.dispatchEvent(new CustomEvent("ui-modal-unsaved-changes:visibility-changed", {bubbles: true}));
  }
}
