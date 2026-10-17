require "application_system_test_case"

class SignupTimeZoneSystemTest < ApplicationSystemTestCase
  test "signup silently captures the browser time zone" do
    visit new_user_registration_path

    zone = page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")
    assert_selector "input[type='hidden'][name='user[time_zone]'][value='#{zone}']", visible: :all
    assert_no_selector "input[name='user[time_zone]']", visible: true
  end

  test "signup remains usable when browser time zone detection fails" do
    visit new_user_session_path
    page.execute_script(<<~JAVASCRIPT)
      window.timeZoneDetectionCalls = 0;
      window.originalDateTimeFormat = Intl.DateTimeFormat;
      Intl.DateTimeFormat = function() {
        window.timeZoneDetectionCalls += 1;
        throw new Error("Time zone unavailable");
      };
    JAVASCRIPT

    wait_for_turbo_navigation { page.execute_script("Turbo.visit(arguments[0])", new_user_registration_path) }
    assert_selector "input[type='hidden'][name='user[time_zone]']", visible: :all
    page.document.synchronize do
      unless page.evaluate_script("window.timeZoneDetectionCalls") == 1
        raise Capybara::ExpectationNotMet, "Browser time zone detection did not run"
      end
    end
    assert_equal "", find("input[name='user[time_zone]']", visible: :all).value
    fill_in "user_name", with: "New Parent"
    assert_field "user_name", with: "New Parent"
    assert_selector "button[type='submit']:enabled"
  ensure
    page.execute_script("if (window.originalDateTimeFormat) Intl.DateTimeFormat = window.originalDateTimeFormat")
  end

  test "Turbo visits safely capture the zone again when signup reconnects" do
    visit new_user_registration_path
    zone = page.evaluate_script("Intl.DateTimeFormat().resolvedOptions().timeZone")
    assert_selector "input[name='user[time_zone]'][value='#{zone}']", visible: :all
    page.execute_script("window.signupTurboVisit = true")

    wait_for_turbo_navigation { page.execute_script("Turbo.visit(arguments[0])", new_user_session_path) }
    wait_for_turbo_navigation { page.execute_script("Turbo.visit(arguments[0])", new_user_registration_path) }

    assert page.evaluate_script("window.signupTurboVisit")
    assert_selector "input[type='hidden'][name='user[time_zone]'][value='#{zone}']", visible: :all, count: 1
  end
end
