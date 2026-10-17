require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test "both parents use the family time zone even when their own zones differ" do
    family = accounts(:company)
    family.update!(time_zone: "Mountain Time (US & Canada)")
    [[users(:one), "Tokyo"], [users(:two), "London"]].each do |parent, zone|
      parent.time_zone = zone
      Current.user = parent
      Current.account = family
      assert_equal family.time_zone, Time.zone.name
    end
  end

  test "the family zone wins regardless of assignment order" do
    Current.account = accounts(:company)
    parent = users(:one)
    parent.time_zone = "Tokyo"
    Current.user = parent
    assert_equal accounts(:company).time_zone, Time.zone.name
  end

  test "changing or clearing the current family updates the zone" do
    parent = users(:one)
    parent.time_zone = "Tokyo"
    Current.user = parent
    Current.account = accounts(:company)
    family = accounts(:one)
    family.time_zone = "London"
    Current.account = family
    assert_equal "London", Time.zone.name
    Current.account = nil
    assert_equal "Tokyo", Time.zone.name
  end

  test "requests without a family retain the user zone or application fallback" do
    user = users(:one)
    user.time_zone = "Tokyo"
    Current.user = user
    assert_equal "Tokyo", Time.zone.name
    Current.user = nil
    assert_equal Rails.application.config.time_zone, Time.zone.name
  end

  test "reset prevents family time from leaking into another request" do
    family = accounts(:company)
    family.time_zone = "Tokyo"
    Current.account = family
    assert_equal "Tokyo", Time.zone.name
    Current.reset
    assert_nil Current.account
    assert_equal Rails.application.config.time_zone, Time.zone.name
  end
end
