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

  test "form deadlines restore the submit control without resubmitting" do
    visit new_user_registration_path
    set_registration_form_timeout("50")
    stub_user_form_fetch("pending")

    submit_registration

    assert_selector "form button[disabled] .when-disabled", text: I18n.t("devise.registrations.new.submitting")
    assert_selector "form + [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.form_timeout.title")
    assert_no_selector "form button[disabled]"
    assert_equal 1, user_form_fetch_count
  end

  test "form network failures show a local notice" do
    visit new_user_registration_path
    stub_user_form_fetch("reject")

    submit_registration

    assert_selector "form + [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.form_network_error.title")
    assert_no_selector "form button[disabled]"
  end

  test "forms can opt out of deadlines" do
    visit new_user_registration_path
    set_registration_form_timeout("false")
    stub_user_form_fetch("pending")

    submit_registration

    assert_no_selector "form + [data-turbo-resilience-notice]", wait: 0.2
  end

  test "form deadlines show the fallback pending label" do
    visit new_user_session_path
    set_registration_form_timeout("50")
    stub_user_form_fetch("pending")

    fill_in "user[email]", with: users(:one).email
    fill_in "user[password]", with: UNIQUE_PASSWORD
    find("form button[type='submit']").click

    assert_selector "form button[disabled] .when-disabled", text: I18n.t("turbo_resilience.button.working")
    assert_selector "form + [data-turbo-resilience-notice][role='alert']", text: I18n.t("turbo_resilience.form_timeout.title")
  end

  test "resolved HTTP form responses do not show a resilience notice" do
    visit new_user_registration_path
    stub_user_form_fetch({
      status: 422,
      contentType: "text/vnd.turbo-stream.html",
      body: "<turbo-stream action='append' target='flash'><template></template></turbo-stream>"
    })

    submit_registration

    assert_no_selector "[data-turbo-resilience-notice]", wait: 0.2
  end

  test "page navigation failures show a global resilience notice" do
    visit root_path

    dispatch_global_fetch_error

    assert_selector "#flash [data-turbo-resilience-global-notice][role='alert']", text: I18n.t("turbo_resilience.global_network_error.title")
  end

  test "standalone stream failures replace only the prior global resilience notice" do
    visit root_path
    page.execute_script("document.querySelector('#flash').insertAdjacentHTML('beforeend', '<div data-test-rails-flash>Saved</div>')")

    dispatch_global_fetch_error
    dispatch_global_fetch_error

    assert_selector "#flash [data-turbo-resilience-global-notice]", count: 1
    assert_selector "#flash [data-test-rails-flash]", text: "Saved"
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

  def set_registration_form_timeout(value)
    page.execute_script("document.querySelector('form').dataset.turboResilienceTimeout = arguments[0]", value)
  end

  def submit_registration
    fill_in "user[name]", with: "New User"
    fill_in "user[email]", with: "new-user@example.com"
    fill_in "user[password]", with: UNIQUE_PASSWORD
    find("input[name='user[terms_of_service]']").click
    find("form button[type='submit']").click
  end

  def dispatch_global_fetch_error
    page.execute_script("document.dispatchEvent(new Event('turbo:fetch-request-error', {bubbles: true}))")
  end
end
