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

  private

  def set_toast_duration(duration)
    page.execute_script("window.__toastPrimaryController.autoDismissDurationValue = arguments[0]", duration)
  end

  def dispatch_toast(type:, message:, auto_dismiss:)
    page.execute_script(<<~JAVASCRIPT, {type: type, message: message, autoDismiss: auto_dismiss})
      window.dispatchEvent(new CustomEvent("toast-show", {detail: arguments[0]}))
    JAVASCRIPT
  end
end
