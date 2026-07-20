import { Controller } from "@hotwired/stimulus"

const DEFAULT_TIMEOUT = 15000

export default class extends Controller {
  connect() {
    this.frameStates = new Map()
    this.handleBeforeFetchRequest = this.handleBeforeFetchRequest.bind(this)
    this.handleFetchRequestError = this.handleFetchRequestError.bind(this)
    this.handleFrameMissing = this.handleFrameMissing.bind(this)
    this.handleFrameLoad = this.handleFrameLoad.bind(this)

    document.addEventListener("turbo:before-fetch-request", this.handleBeforeFetchRequest)
    document.addEventListener("turbo:fetch-request-error", this.handleFetchRequestError)
    document.addEventListener("turbo:frame-missing", this.handleFrameMissing)
    document.addEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  disconnect() {
    this.clearAllFrameTimers()
    document.removeEventListener("turbo:before-fetch-request", this.handleBeforeFetchRequest)
    document.removeEventListener("turbo:fetch-request-error", this.handleFetchRequestError)
    document.removeEventListener("turbo:frame-missing", this.handleFrameMissing)
    document.removeEventListener("turbo:frame-load", this.handleFrameLoad)
  }

  handleBeforeFetchRequest(event) {
    const frame = this.frameFrom(event.target)
    const method = event.detail.fetchOptions?.method?.toUpperCase() || "GET"
    if (!frame || !frame.hasAttribute("src") || method !== "GET") return

    const timeout = this.timeoutFor(frame)
    if (timeout === null) return

    const existingState = this.frameStates.get(frame)
    this.clearFrameTimer(existingState)

    const retryURL = this.safeRetryURL(frame.getAttribute("src")) || existingState?.retryURL
    const state = {pending: true, retryURL, timeoutId: null}
    state.timeoutId = window.setTimeout(() => this.handleFrameTimeout(frame), timeout)
    this.frameStates.set(frame, state)
  }

  retryFrame(event) {
    event.preventDefault()

    const frame = event.target.closest("turbo-frame")
    const state = frame && this.frameStates.get(frame)
    if (!state || state.pending || !state.retryURL) return

    state.pending = true
    event.target.closest("button")?.setAttribute("disabled", "disabled")
    frame.removeAttribute("src")
    frame.loading = "eager"
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
    if (!frame) return

    this.clearFrameTimer(this.frameStates.get(frame))
    this.frameStates.delete(frame)
  }

  showFrameFailure(frame) {
    const existingState = this.frameStates.get(frame)
    const retryURL = this.safeRetryURL(frame.getAttribute("src")) || existingState?.retryURL

    this.clearFrameTimer(existingState)
    this.frameStates.set(frame, {pending: false, retryURL, timeoutId: null})
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

  handleFrameTimeout(frame) {
    const state = this.frameStates.get(frame)
    if (!state?.pending) return

    frame.removeAttribute("src")
    this.showFrameFailure(frame)
  }

  timeoutFor(element) {
    const value = element.dataset.turboResilienceTimeout
    if (value === "false") return null

    const timeout = Number(value)
    return Number.isFinite(timeout) && timeout > 0 ? timeout : DEFAULT_TIMEOUT
  }

  clearFrameTimer(state) {
    if (state?.timeoutId === null || state?.timeoutId === undefined) return

    window.clearTimeout(state.timeoutId)
    state.timeoutId = null
  }

  clearAllFrameTimers() {
    this.frameStates?.forEach((state) => this.clearFrameTimer(state))
  }

  templateContent(id) {
    return document.getElementById(id).content.cloneNode(true)
  }

  frameFrom(element) {
    return element?.tagName === "TURBO-FRAME" ? element : null
  }
}
