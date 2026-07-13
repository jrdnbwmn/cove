import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: { type: String, default: "/action_text/embeds" } // endpoint that handles unfurling
  }

  unfurl(event) {
    this.#unfurlLink(event.detail.url, event.detail)
  }

  async #unfurlLink(url, callbacks) {
    const response = await fetch(this.urlValue, {
      method: "POST",
      body: JSON.stringify({ id: event.detail.url }),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      }
    })

    const metadata = await response.json()
    this.#insertUnfurledLink(metadata, callbacks)
  }

  #insertUnfurledLink(metadata, callbacks) {
    // Replace the pasted link with your custom HTML
    // callbacks.replaceLinkWith(this.#renderUnfurledLinkHTML(metadata))

    // Or, insert below the link as an attachment:
    callbacks.insertBelowLink(metadata.content, { attachment: { sgid: metadata.sgid } })
  }

  #renderUnfurledLinkHTML(link) {
    return `<a href="${link.canonical_url}">${link.title}</a>`
  }
}
