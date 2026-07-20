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

  private

  def assert_resilience_wiring
    assert_selector "body[data-controller~='turbo-resilience']"

    TEMPLATE_IDS.each do |template_id|
      assert_selector "template##{template_id}", visible: :all
    end
  end
end
