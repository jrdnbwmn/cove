import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["dialog", "wrapper", "content", "discardPrompt", "heading"];

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
    this.formSnapshot = null;
    this.dialogTarget.removeEventListener("input", this.boundMarkDirty);
    this.dialogTarget.removeEventListener("change", this.boundMarkDirty);
    this.dialogTarget.removeEventListener("submit", this.boundClearDirty);
    this.dialogTarget.removeEventListener("ui-modal:closed", this.boundClearDirty);
    this.dialogTarget.removeEventListener("ui-modal:close-request", this.boundRequestClose);
  }

  keepEditing() {
    this.hideDiscardPrompt();
  }

  // AIDEV-NOTE: Don't hide the prompt here. The modal animates closed after this, and restoring the form first
  // made it flash back into view. ui-modal:closed (clearDirty) puts the content back once the dialog is gone.
  discard() {
    this.isDirty = false;
    this.element.dispatchEvent(new CustomEvent("ui-modal-unsaved-changes:discard", {bubbles: true}));
  }

  markDirty(event) {
    if (event.target.closest("form")) this.isDirty = true;
  }

  // AIDEV-NOTE: Only opted-in confirmation links capture a draft. Keep it in
  // memory on this dialog, never in a URL, storage, or a request to the server.
  captureForm() {
    const form = this.contentTarget.querySelector("form[id]");
    if (!form) return;

    this.formSnapshot = {
      id: form.id,
      dirty: this.isDirty,
      fields: this.editableFields(form).map((field) => ({
        name: field.name,
        type: field.type,
        value: field.value,
        checked: field.checked,
        options: field.tagName === "SELECT"
          ? Array.from(field.selectedOptions, (option) => ({value: option.value, text: option.text}))
          : null,
      })),
    };
  }

  editableFields(form) {
    return Array.from(form.elements).filter((field) =>
      field.name && !["authenticity_token", "_method", "utf8"].includes(field.name) &&
      ["INPUT", "TEXTAREA", "SELECT"].includes(field.tagName) &&
      !["password", "file", "submit", "button"].includes(field.type));
  }

  // AIDEV-NOTE: Restore the incoming frame before Turbo inserts it, so TomSelect
  // and other enhanced controls connect to the draft values, including new options.
  beforeFrameRender(event) {
    const snapshot = this.formSnapshot;
    if (!snapshot) return;
    const form = Array.from(event.detail.newFrame.querySelectorAll("form[id]"))
      .find((candidate) => candidate.id === snapshot.id);
    if (!form) return;

    const fields = this.editableFields(form);
    snapshot.fields.forEach((saved) => {
      const index = fields.findIndex((field) => field.name === saved.name && field.type === saved.type);
      if (index !== -1) this.restoreField(fields.splice(index, 1)[0], saved);
    });
    this.restoredDirty = snapshot.dirty;
    this.formSnapshot = null;
  }

  restoreField(field, saved) {
    if (saved.options) {
      this.restoreSelect(field, saved.options);
    } else if (["radio", "checkbox"].includes(field.type)) {
      field.checked = saved.checked;
    } else {
      field.value = saved.value;
    }
  }

  // Options typed in by the user (e.g. a new subject) may be absent from the fetched form, so add them first.
  restoreSelect(field, savedOptions) {
    savedOptions.forEach((option) => {
      if (!Array.from(field.options).some((existing) => existing.value === option.value)) {
        field.add(new Option(option.text, option.value));
      }
    });
    Array.from(field.options).forEach((option) => {
      option.selected = savedOptions.some((savedOption) => savedOption.value === option.value);
    });
  }

  frameRendered(event) {
    const response = event.detail?.fetchResponse;
    this.isDirty = this.restoredDirty ?? Boolean(response && !response.succeeded);
    this.restoredDirty = null;
    this.hideDiscardPrompt();
  }

  clearDirty() {
    this.formSnapshot = null;
    this.restoredDirty = null;
    this.isDirty = false;
    this.hideDiscardPrompt();
  }

  // AIDEV-NOTE: A close request (cross, outside click, Escape) while the prompt is already showing dismisses the
  // question like "Keep editing", so nothing is lost and the cross never looks dead.
  requestClose(event) {
    if (!this.isDirty) return;

    event.preventDefault();
    if (this.discardPromptTarget.classList.contains("hidden")) {
      this.showDiscardPrompt();
    } else {
      this.keepEditing();
    }
  }

  showDiscardPrompt() {
    this.contentTarget.classList.add("hidden");
    // The modal's title (e.g. "Add class") would otherwise sit above the prompt.
    if (this.hasHeadingTarget) this.headingTarget.classList.add("hidden");
    this.wrapperTarget.classList.replace("h-full", "h-auto");
    this.discardPromptTarget.classList.remove("hidden");
    this.notifyVisibilityChanged();
  }

  hideDiscardPrompt() {
    this.contentTarget.classList.remove("hidden");
    if (this.hasHeadingTarget) this.headingTarget.classList.remove("hidden");
    this.wrapperTarget.classList.replace("h-auto", "h-full");
    this.discardPromptTarget.classList.add("hidden");
    this.notifyVisibilityChanged();
  }

  notifyVisibilityChanged() {
    this.element.dispatchEvent(new CustomEvent("ui-modal-unsaved-changes:visibility-changed", {bubbles: true}));
  }
}
