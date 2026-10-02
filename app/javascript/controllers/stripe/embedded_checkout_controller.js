import { Controller } from "@hotwired/stimulus"

let stripePromise

function loadStripe() {
  if (stripePromise) return stripePromise

  const existingScript = document.querySelector('script[src="https://js.stripe.com/v3/"]')
  if (existingScript) {
    stripePromise = existingScript.dataset.loaded === "true" ? Promise.resolve() : new Promise((resolve, reject) => {
      existingScript.addEventListener("load", resolve, {once: true})
      existingScript.addEventListener("error", reject, {once: true})
    })
    return stripePromise
  }

  stripePromise = new Promise((resolve, reject) => {
    const script = document.createElement("script")
    script.src = "https://js.stripe.com/v3/"
    script.addEventListener("load", () => { script.dataset.loaded = "true"; resolve() }, {once: true})
    script.addEventListener("error", reject, {once: true})
    document.head.append(script)
  })
  return stripePromise
}

export default class extends Controller {
  static values = {
    publicKey: String,
    clientSecret: String,
  }

  async connect() {
    // AIDEV-NOTE: Stripe.js is checkout-only, so load it here instead of blocking every page head.
    await loadStripe()
    if (!this.isConnected) return
    this.stripe = Stripe(this.publicKeyValue)
    this.checkout = await this.stripe.createEmbeddedCheckoutPage({fetchClientSecret: this.fetchClientSecret.bind(this)})
    this.checkout.mount(this.element)
  }

  disconnect() {
    this.checkout?.destroy()
  }

  fetchClientSecret() {
    return Promise.resolve(this.clientSecretValue)
  }
}
