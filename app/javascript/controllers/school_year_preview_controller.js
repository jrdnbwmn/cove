import { Controller } from "@hotwired/stimulus"

// Asks the server how many school days a later Ends date adds. The counting rule lives only on the server.
export default class extends Controller {
  static targets = ["ends", "frame", "skeleton"]
  static values = { url: String }

  connect() {
    this.requested = this.endsTarget.value
  }

  update() {
    const value = this.endsTarget.value
    if (value === this.requested) return

    this.requested = value
    if (value) {
      this.showSkeleton()
      this.frameTarget.src = this.previewUrl(value)
    } else {
      this.clear()
    }
  }

  // AIDEV-NOTE: Turbo doesn't cancel an earlier frame request when src changes again, so a slow older
  // response could land last. Drop any response that isn't for the most recent Ends value.
  beforeFetchResponse(event) {
    const responseUrl = new URL(event.detail.fetchResponse.location, window.location.href)
    if (responseUrl.searchParams.get("ends_on") !== this.requested) event.preventDefault()
  }

  // AIDEV-NOTE: The preview frame sits inside the modal, whose unsaved-changes controller treats any bubbling
  // turbo:frame-render as the form being re-rendered and resets its dirty flag. Keep these events local.
  rendered(event) {
    event.stopPropagation()
    if (event.type === "turbo:frame-render") this.hideSkeleton()
  }

  failed() {
    this.hideSkeleton()
  }

  clear() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren()
    this.hideSkeleton()
  }

  previewUrl(value) {
    const url = new URL(this.urlValue, window.location.origin)
    url.searchParams.set("ends_on", value)
    return url.toString()
  }

  showSkeleton() {
    this.frameTarget.classList.add("hidden")
    this.skeletonTarget.classList.remove("hidden")
  }

  hideSkeleton() {
    this.frameTarget.classList.remove("hidden")
    this.skeletonTarget.classList.add("hidden")
  }
}
