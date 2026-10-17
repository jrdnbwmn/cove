require "test_helper"

class Jumpstart::AccountsEditTest < ActionDispatch::IntegrationTest
  test "either parent can save the shared family time zone" do
    [users(:one), users(:two)].each do |parent|
      sign_in parent
      patch account_path(accounts(:company)), params: {account: {time_zone: "Tokyo"}}
      assert_response :redirect
      assert_equal "Tokyo", accounts(:company).reload.time_zone
      accounts(:company).update!(time_zone: "Mountain Time (US & Canada)")
      sign_out parent
    end
  end

  test "an unknown time zone is rejected and retained in the edit form" do
    sign_in users(:one)
    patch account_path(accounts(:company)), params: {account: {time_zone: "Unknown/Zone"}}
    assert_response :unprocessable_content
    assert_equal "Mountain Time (US & Canada)", accounts(:company).reload.time_zone
    assert_select "select[name='account[time_zone]'] option[selected][value='Unknown/Zone']"
    assert_select "p.text-red-600", text: /not included/
  end

  test "family time zones list US zones first without duplicates" do
    sign_in users(:one)
    get edit_account_path(accounts(:company))
    assert_select "label[for='account_time_zone']", text: "Time zone"
    assert_includes response.body, "Sets when each school day starts and ends for everyone in your family."
    options = css_select("select[name='account[time_zone]'] option").map { |option| option["value"] }
    assert_equal ActiveSupport::TimeZone.us_zones.map(&:name), options.first(ActiveSupport::TimeZone.us_zones.size)
    assert_equal options.uniq, options
    assert_equal (ActiveSupport::TimeZone.us_zones + ActiveSupport::TimeZone.all).map(&:name).uniq.sort, options.sort
  end

  test "every offered US time zone can be saved" do
    sign_in users(:one)
    ActiveSupport::TimeZone.us_zones.each do |zone|
      patch account_path(accounts(:company)), params: {account: {time_zone: zone.name}}
      assert_response :redirect
      assert_equal zone.name, accounts(:company).reload.time_zone
    end
  end

  test "a parent cannot change another family's time zone" do
    sign_in users(:one)
    patch account_path(accounts(:one)), params: {account: {time_zone: "Tokyo"}}
    assert_response :not_found
    assert_equal "Mountain Time (US & Canada)", accounts(:one).reload.time_zone
  end

  test "the family edit response has no delete control" do
    sign_in users(:one)

    get edit_account_path(accounts(:company))

    assert_response :success
    assert_select "form[action=?][method=?] input[name=?][value=?]", account_path(accounts(:company)), "post", "_method", "delete", count: 0
  end

  test "a non-owner admin also receives no delete control" do
    sign_in users(:two)

    get edit_account_path(accounts(:company))

    assert_response :success
    assert_select "form[action=?][method=?] input[name=?][value=?]", account_path(accounts(:company)), "post", "_method", "delete", count: 0
  end

  # AIDEV-NOTE: No "owner viewing a personal account" case here — this app's
  # accounts table has a DB check constraint (accounts_personal_must_be_false,
  # db/schema.rb) that forces personal to always be false, so a personal
  # account fixture cannot exist to test against.
end
