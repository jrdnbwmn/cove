require "test_helper"
require "view_component/test_case"

class DevClockStripComponentTest < ViewComponent::TestCase
  test "the strip only appears in development with an override" do
    %w[test staging production].each do |environment|
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(environment)) do
        render_inline DevClockStripComponent.new(date: Date.new(2026, 10, 14))
        assert_no_selector "[data-dev-clock-strip]"
      end
    end
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      render_inline DevClockStripComponent.new(date: nil)
      assert_no_selector "[data-dev-clock-strip]"
    end
  end

  test "parents can change or clear the displayed pretend date" do
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      render_inline DevClockStripComponent.new(date: Date.new(2026, 10, 14))
      assert_text "Dev clock: pretending it's 14 Oct 2026"
      assert_selector "a[href='/dev/clock']", text: "Change"
      assert_selector "form[action='/dev/clock'][method=post]" do
        assert_selector "input[name=_method][value=delete]", visible: :all
        assert_selector "button[type=submit]", text: "Clear"
      end
    end
  end
end
