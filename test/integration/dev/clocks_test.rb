require "test_helper"
require "tmpdir"

class Dev::ClocksTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Time.utc(2026, 10, 17, 12)
    @directory = Dir.mktmpdir("cove-clock-page")
    @path = Pathname.new(@directory).join("dev_today")
  end

  teardown { FileUtils.remove_entry(@directory) }

  test "development requires sign in and shows the real family date while pretending" do
    with_development do
      get dev_clock_path
      assert_redirected_to new_user_session_path
      sign_in users(:one)
      get dev_clock_path
      assert_response :success
      assert_select "p", text: "Real today for your family: 17 Oct 2026"
      assert_select "p", text: "Override: none"
      assert_select "label", text: "Pretend date"
      assert_select "button", text: "Clear", count: 0
      patch dev_clock_path, params: {date: "2026-10-14"}
      assert_redirected_to dev_clock_path
      follow_redirect!
      assert_select "p", text: "Real today for your family: 17 Oct 2026"
      assert_select "p", text: "Override: 14 Oct 2026"
      assert_select "input[type=date][value='2026-10-14']"
      assert_select "button", text: /Clear/
      assert_equal Date.new(2026, 10, 14), accounts(:company).today
    end
  end

  test "empty and invalid dates preserve the current override with an inline error" do
    with_development do
      sign_in users(:one)
      DevClock.set(Date.new(2026, 10, 14))
      ["", "not-a-date", "2026-02-30"].each do |value|
        patch dev_clock_path, params: {date: value}
        assert_response :unprocessable_content
        assert_select "p", text: "Choose a valid date."
        assert_equal Date.new(2026, 10, 14), DevClock.today
      end
    end
  end

  test "clear returns to a same origin page and rejects external malformed or missing referrers" do
    with_development do
      sign_in users(:one)
      ["http://www.example.com/planner?tab=one", "https://evil.test/planner", "//www.example.com/planner", "http://[", nil].each do |referrer|
        DevClock.set(Date.new(2026, 10, 14))
        delete dev_clock_path, headers: referrer ? {"Referer" => referrer} : {}
        assert_redirected_to((referrer == "http://www.example.com/planner?tab=one") ? "/planner?tab=one" : dev_clock_path)
        assert_nil DevClock.today
      end
    end
  end

  %w[test staging production].each do |environment|
    test "#{environment} refuses every clock action before requiring sign in" do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(environment)) do
        get dev_clock_path
        assert_response :not_found
        patch dev_clock_path, params: {date: "2026-10-14"}
        assert_response :not_found
        delete dev_clock_path
        assert_response :not_found
      end
      assert_not @path.exist?
    end
  end

  test "clock routes exist only in local environments" do
    %w[development test staging production].each do |environment|
      routes = ActionDispatch::Routing::RouteSet.new
      routes.draw_paths = Rails.application.routes.draw_paths
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(environment)) do
        Rails.application.stub(:routes, -> { routes }) { load Rails.root.join("config/routes.rb") }
      end
      clock_routes = routes.routes.select { |route| route.defaults[:controller] == "dev/clocks" }
      assert_equal environment.in?(%w[development test]) ? 4 : 0, clock_routes.size, environment
    end
  end

  private

  def with_development(&block)
    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      DevClock.stub(:path, @path, &block)
    end
  end
end
