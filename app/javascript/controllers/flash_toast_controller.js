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
    autoDismiss: { type: Boolean, default: true },
    action: Object
  }

  connect() {
    this.showToast = this.showToast.bind(this)

    if (window.toast) {
      this.showToast()
      return
    }

    window.addEventListener("ui-toast:ready", this.showToast, { once: true })
  }

  disconnect() {
    window.removeEventListener("ui-toast:ready", this.showToast)
  }

  showToast() {
    window.dispatchEvent(new CustomEvent("toast-show", {
      detail: {
        type: this.typeValue,
        message: this.messageValue,
        description: this.descriptionValue,
        autoDismiss: this.autoDismissValue,
        action: this.hasActionValue ? this.serverAction() : null
      }
    }))
  }

  // Server-backed action (e.g. Undo): the toast button submits a normal POST
  // form so Turbo handles the redirect and the request carries the CSRF token.
  serverAction() {
    const { label, url, params = {} } = this.actionValue
    // The form carries the CSRF token, so it may only ever post back to this app.
    if (new URL(url, window.location.origin).origin !== window.location.origin) return null

    let submitted = false

    return {
      label,
      onClick: () => {
        if (submitted) return
        submitted = true
        this.submitForm(url, params)
      }
    }
  }

  submitForm(url, params) {
    const form = document.createElement("form")
    form.method = "post"
    form.action = url
    form.hidden = true

    const token = document.querySelector("meta[name='csrf-token']")?.content
    const fields = token ? { authenticity_token: token, ...params } : params
    for (const [name, value] of Object.entries(fields)) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = name
      input.value = value
      form.appendChild(input)
    }

    // The toast (and this controller) is removed with the click, so the form
    // lives on <body> until Turbo finishes with it.
    form.addEventListener("turbo:submit-end", () => form.remove(), { once: true })
    document.body.appendChild(form)
    form.requestSubmit()
  }
}
