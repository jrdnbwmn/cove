import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "wrapper", "content", "discardPrompt"];

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

  // AIDEV-NOTE: A frame render means the modal's content was swapped (e.g. Edit -> Delete confirmation), so
  // earlier edits are gone and closing shouldn't ask. A failed response (422) re-renders the user's form
  // with their typed values, so it stays dirty even though the submit event just cleared the flag.
  frameRendered(event) {
    const response = event.detail?.fetchResponse;

    if (response && !response.succeeded) {
      this.isDirty = true;
    } else {
      this.clearDirty();
    }
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
    this.contentTarget.classList.add("hidden");
    this.wrapperTarget.classList.replace("h-full", "h-auto");
    this.discardPromptTarget.classList.remove("hidden");
    this.notifyVisibilityChanged();
  }

  hideDiscardPrompt() {
    this.contentTarget.classList.remove("hidden");
    this.wrapperTarget.classList.replace("h-auto", "h-full");
    this.discardPromptTarget.classList.add("hidden");
    this.notifyVisibilityChanged();
  }

  notifyVisibilityChanged() {
    this.element.dispatchEvent(new CustomEvent("ui-modal-unsaved-changes:visibility-changed", {bubbles: true}));
  }
}
