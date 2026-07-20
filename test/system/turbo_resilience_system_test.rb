require "application_system_test_case"

class TurboResilienceSystemTest < ApplicationSystemTestCase
  TEMPLATE_IDS = %w[
    turbo-resilience-frame-failure-template
    turbo-resilience-form-timeout-template
    turbo-resilience-form-network-error-template
    turbo-resilience-global-network-error-template
  ].freeze

  test "application layout provides the resilience controller and templates" do
    visit root_path

    assert_resilience_wiring
  end

  test "minimal Devise layout provides the resilience controller and templates" do
    visit new_user_session_path

    assert_resilience_wiring
  end

  test "frame network failures show a retry that cannot be clicked repeatedly" do
    login_as users(:one), scope: :user
    visit root_path
    stub_notifications_frame_fetch("reject")

    open_notifications

    assert_selector "turbo-frame#notifications [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.frame.title")
    set_notifications_frame_fetch_outcomes("pending")
    click_button I18n.t("turbo_resilience.frame.retry")
    assert page.evaluate_script("document.querySelector('turbo-frame#notifications button')?.disabled")
  end

  test "missing frame responses replace Turbo's generic error" do
    login_as users(:one), scope: :user
    visit root_path
    stub_notifications_frame_fetch({body: "<main>Unexpected content</main>"})

    open_notifications

    assert_selector "turbo-frame#notifications [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.frame.title")
    assert_no_text "Content missing"
  end

  test "repeated frame failures restore the retry action" do
    login_as users(:one), scope: :user
    visit root_path
    stub_notifications_frame_fetch("reject")

    open_notifications
    assert_selector "turbo-frame#notifications [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.frame.title")
    set_notifications_frame_fetch_outcomes("reject")
    click_button I18n.t("turbo_resilience.frame.retry")

    assert_selector "turbo-frame#notifications button:not([disabled])", text: I18n.t("turbo_resilience.frame.retry")
  end

  test "frame failures omit retry actions for cross-origin sources" do
    visit root_path

    page.execute_script(<<~JAVASCRIPT)
      const frame = document.createElement("turbo-frame")
      frame.id = "external-frame"
      frame.src = "https://example.com/content"
      document.body.append(frame)
      frame.dispatchEvent(new Event("turbo:fetch-request-error", {bubbles: true}))
    JAVASCRIPT

    assert_selector "turbo-frame#external-frame [data-turbo-resilience-notice][role='alert']"
    assert_no_selector "turbo-frame#external-frame button"
  end

  test "remote frame deadlines render a retryable failure" do
    login_as users(:one), scope: :user
    visit root_path
    set_notifications_frame_timeout("50")
    stub_notifications_frame_fetch("pending")

    open_notifications

    assert_selector "turbo-frame#notifications [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.frame.title")
    assert_button I18n.t("turbo_resilience.frame.retry")
  end

  test "remote frames can opt out of deadlines" do
    login_as users(:one), scope: :user
    visit root_path
    set_notifications_frame_timeout("false")
    stub_notifications_frame_fetch("pending")

    open_notifications

    assert_no_selector "turbo-frame#notifications [data-turbo-resilience-notice]", wait: 0.2
  end

  test "invalid remote frame deadlines fall back to the default" do
    login_as users(:one), scope: :user
    visit root_path
    set_notifications_frame_timeout("soon")
    stub_notifications_frame_fetch("pending")

    open_notifications

    assert_no_selector "turbo-frame#notifications [data-turbo-resilience-notice]", wait: 0.2
  end

  test "a timed out frame retry restores the failure when it rejects" do
    login_as users(:one), scope: :user
    visit root_path
    set_notifications_frame_timeout("50")
    stub_notifications_frame_fetch("pending")

    open_notifications
    assert_selector "turbo-frame#notifications [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.frame.title")
    set_notifications_frame_fetch_outcomes("reject")
    click_button I18n.t("turbo_resilience.frame.retry")

    assert_selector "turbo-frame#notifications button:not([disabled])", text: I18n.t("turbo_resilience.frame.retry")
  end

  teardown do
    restore_turbo_resilience_fetch
  end

  private

  def assert_resilience_wiring
    assert_selector "body[data-controller~='turbo-resilience']"

    TEMPLATE_IDS.each do |template_id|
      assert_selector "template##{template_id}", visible: :all
    end
  end

  def open_notifications
    find("button[aria-label='Notifications']").click
  end

  def set_notifications_frame_timeout(value)
    page.execute_script("document.querySelector('turbo-frame#notifications').dataset.turboResilienceTimeout = arguments[0]", value)
  end
end
