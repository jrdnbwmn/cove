import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.frameStates = new WeakMap()
    this.handleFetchRequestError = this.handleFetchRequestError.bind(this)
    this.handleFrameMissing = this.handleFrameMissing.bind(this)
    this.handleFrameLoad = this.handleFrameLoad.bind(this)

    document.addEventListener("turbo:fetch-request-error", this.handleFetchRequestError)
    document.addEventListener("turbo:frame-missing", this.handleFrameMissing)
    document.addEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  disconnect() {
    document.removeEventListener("turbo:fetch-request-error", this.handleFetchRequestError)
    document.removeEventListener("turbo:frame-missing", this.handleFrameMissing)
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  retryFrame(event) {
    event.preventDefault()

    const frame = event.target.closest("turbo-frame")
    const state = frame && this.frameStates.get(frame)
    if (!state || state.pending || !state.retryURL) return

    state.pending = true
    event.target.closest("button")?.setAttribute("disabled", "disabled")
    frame.removeAttribute("src")
    frame.src = state.retryURL
  }

  handleFetchRequestError(event) {
    const frame = this.frameFrom(event.target)
    if (!frame) return

    this.showFrameFailure(frame)
  }

  handleFrameMissing(event) {
    const frame = this.frameFrom(event.target)
    if (!frame) return

    event.preventDefault()
    this.showFrameFailure(frame)
  }

  handleFrameLoad(event) {
    const frame = this.frameFrom(event.target)
    if (frame) this.frameStates.delete(frame)
  }

  showFrameFailure(frame) {
    const existingState = this.frameStates.get(frame)
    const retryURL = this.safeRetryURL(frame.getAttribute("src")) || existingState?.retryURL

    this.frameStates.set(frame, {pending: false, retryURL})
    frame.replaceChildren(this.templateContent("turbo-resilience-frame-failure-template"))

    if (!retryURL) frame.querySelector("[data-turbo-resilience-retry]")?.remove()
  }

  safeRetryURL(value) {
    if (!value) return null

    try {
      const url = new URL(value, window.location.origin)
      return ["http:", "https:"].includes(url.protocol) && url.origin === window.location.origin ? url.href : null
    } catch {
      return null
    }
  }

  templateContent(id) {
    return document.getElementById(id).content.cloneNode(true)
  }

  frameFrom(element) {
    return element?.tagName === "TURBO-FRAME" ? element : null
  }
}
