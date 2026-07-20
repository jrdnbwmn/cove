module TurboResilienceSystemHelper
  def stub_notifications_frame_fetch(*outcomes)
    page.execute_script(<<~JAVASCRIPT, outcomes)
      window.__turboResilienceFetchOutcomes = arguments[0]
      window.__turboResilienceOriginalFetch = window.fetch
      window.fetch = (input, options) => {
        const url = new URL(typeof input === "string" ? input : input.url, window.location.href)

        if (url.pathname !== "/notifications/nav") {
          return window.__turboResilienceOriginalFetch(input, options)
        }

        const outcomes = window.__turboResilienceFetchOutcomes
        const outcome = outcomes[0] === "pending" ? outcomes[0] : outcomes.shift() || "reject"
        if (outcome === "pending") return new Promise(() => {})
        if (outcome === "reject") return Promise.reject(new TypeError("Network request failed"))

        return Promise.resolve(new Response(outcome.body, {
          status: outcome.status || 200,
          headers: {"Content-Type": "text/html"}
        }))
      }
    JAVASCRIPT
  end

  def set_notifications_frame_fetch_outcomes(*outcomes)
    page.execute_script("window.__turboResilienceFetchOutcomes = arguments[0]", outcomes)
  end

  def restore_turbo_resilience_fetch
    page.execute_script(<<~JAVASCRIPT)
      if (window.__turboResilienceOriginalFetch) {
        window.fetch = window.__turboResilienceOriginalFetch
        delete window.__turboResilienceOriginalFetch
        delete window.__turboResilienceFetchOutcomes
      }
    JAVASCRIPT
  end
end
