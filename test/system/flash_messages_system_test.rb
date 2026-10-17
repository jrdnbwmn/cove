require "application_system_test_case"

class FlashMessagesSystemTest < ApplicationSystemTestCase
  test "notices dismiss automatically while errors remain until dismissed" do
    visit root_path
    set_toast_duration(300)

    dispatch_toast(type: "notice", message: "Saved", auto_dismiss: true)
    assert_selector "[role='status']", text: "Saved"
    assert_no_selector "[role='status']", text: "Saved", wait: 0.6

    dispatch_toast(type: "error", message: "Could not save", auto_dismiss: false)
    assert_selector "[role='alert']", text: "Could not save"
    find("button[aria-label='Dismiss notification']").click
    assert_no_selector "[role='alert']", text: "Could not save"
  end

  test "Turbo navigation clears active toasts" do
    visit root_path

    dispatch_toast(type: "notice", message: "Saved", auto_dismiss: true)
    assert_selector "[role='status']", text: "Saved"

    page.execute_script("Turbo.visit('/privacy')")

    assert_current_path privacy_path
    assert_no_selector "[role='status']", text: "Saved"
  end

  test "a server-backed toast action submits one CSRF-protected Turbo form" do
    visit root_path
    capture_turbo_requests
    add_server_toast(message: "Time off removed", action: {label: "Undo", url: "/restore", params: {restore: "<b>signed</b>"}})

    assert_selector "[role='status']", text: "Time off removed"
    # Forgery protection is off in tests, so the layout renders no token; supply one.
    csrf_token = "test-csrf-token"
    page.execute_script("const m = document.createElement('meta'); m.name = 'csrf-token'; m.content = arguments[0]; document.head.appendChild(m)", csrf_token)
    # Two clicks in the same tick must still submit once.
    page.execute_script("const b = document.querySelector('[data-action-type=primary]'); b.click(); b.click()")

    requests = recorded_turbo_requests
    assert_equal 1, requests.size
    assert_equal "POST", requests.first["method"]
    assert_match %r{/restore\z}, requests.first["url"]
    assert_equal "<b>signed</b>", requests.first["fields"]["restore"]
    assert_equal csrf_token, requests.first["fields"]["authenticity_token"]
  end

  test "ordinary toasts have no action button and server toast text is escaped" do
    visit root_path
    add_server_toast(message: "<i>Plain</i>", action: nil)

    assert_selector "[role='status']", text: "<i>Plain</i>"
    assert_no_selector "[role='status'] i"
    assert_no_button "Undo"
  end

  test "Turbo navigation clears a server-backed toast action" do
    visit root_path
    add_server_toast(message: "Time off removed", action: {label: "Undo", url: "/restore", params: {}})
    assert_button "Undo"

    page.execute_script("Turbo.visit('/privacy')")

    assert_current_path privacy_path
    assert_no_button "Undo"
  end

  private

  # Mounts a flash-toast element exactly as _flash.html.erb renders one.
  def add_server_toast(message:, action:)
    page.execute_script(<<~JAVASCRIPT, {message: message, action: action&.to_json})
      const el = document.createElement("div")
      el.dataset.controller = "flash-toast"
      el.dataset.flashToastMessageValue = arguments[0].message
      if (arguments[0].action) el.dataset.flashToastActionValue = arguments[0].action
      document.getElementById("toasts").appendChild(el)
    JAVASCRIPT
  end

  # The 404 answer reloads the page mid-poll, so retry through the navigation.
  def recorded_turbo_requests
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Capybara.default_max_wait_time
    until Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
      begin
        requests = JSON.parse(page.evaluate_script("sessionStorage.getItem('turboRequests')"))
        return requests if requests.any?
      rescue Selenium::WebDriver::Error::WebDriverError
        nil
      end
      sleep 0.05
    end
    flunk "No Turbo form request was recorded"
  end

  # Records Turbo's form fetch requests (kept in sessionStorage so they survive that reload); the target route doesn't exist, so the app answers 404.
  def capture_turbo_requests
    page.execute_script(<<~JAVASCRIPT)
      sessionStorage.setItem("turboRequests", "[]")
      document.addEventListener("turbo:before-fetch-request", (event) => {
        const { body, method } = event.detail.fetchOptions
        if (!body || typeof body.entries !== "function") return
        const requests = JSON.parse(sessionStorage.getItem("turboRequests"))
        requests.push({ method, url: event.detail.url.pathname, fields: Object.fromEntries(body.entries()) })
        sessionStorage.setItem("turboRequests", JSON.stringify(requests))
      })
    JAVASCRIPT
  end

  def set_toast_duration(duration)
    page.execute_script("window.__toastPrimaryController.autoDismissDurationValue = arguments[0]", duration)
  end

  def dispatch_toast(type:, message:, auto_dismiss:)
    page.execute_script(<<~JAVASCRIPT, {type: type, message: message, autoDismiss: auto_dismiss})
      window.dispatchEvent(new CustomEvent("toast-show", {detail: arguments[0]}))
    JAVASCRIPT
  end
end
