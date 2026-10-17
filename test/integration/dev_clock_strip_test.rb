require "test_helper"
require "tmpdir"

class DevClockStripTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @directory = Dir.mktmpdir("cove-clock-strip")
    @path = Pathname.new(@directory).join("dev_today")
    sign_in users(:one)
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "signed in pages show one strip with change and clear actions while pretending" do
    with_clock do
      DevClock.set(Date.new(2026, 10, 14))
      [planner_path, planner_school_year_path, learners_path, courses_path, dev_clock_path].each do |path|
        get path
        assert_response :success
        assert_select "[data-dev-clock-strip]", count: 1 do
          assert_select "span", text: "Dev clock: pretending it's 14 Oct 2026"
          assert_select "a[href=?]", dev_clock_path, text: "Change"
          assert_select "form[action=?] input[name=_method][value=delete]", dev_clock_path
        end
      end
    end
  end

  test "strip is absent without an override outside development and when signed out" do
    with_clock do
      get planner_path
      assert_select "[data-dev-clock-strip]", count: 0
      DevClock.set(Date.new(2026, 10, 14))
      sign_out users(:one)
      get new_user_session_path
      assert_select "[data-dev-clock-strip]", count: 0
    end
  end

  test "strip is absent outside development even with an override file" do
    @path.write("2026-10-14")
    DevClock.stub(:path, @path) do
      get planner_path
      assert_select "[data-dev-clock-strip]", count: 0
    end
  end

  test "clearing from the strip returns to the current signed in page" do
    with_clock do
      DevClock.set(Date.new(2026, 10, 14))
      get planner_school_year_path
      delete dev_clock_path, headers: {"Referer" => "http://www.example.com#{planner_school_year_path}"}
      assert_redirected_to planner_school_year_path
      follow_redirect!
      assert_select "[data-dev-clock-strip]", count: 0
      assert_nil DevClock.today
    end
  end

  private

  def with_clock(&block)
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      DevClock.stub(:path, @path, &block)
    end
  end
end
