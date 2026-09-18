require "test_helper"

class PlanTest < ActiveSupport::TestCase
  test "find_interval_plan" do
    assert_equal annual, monthly.find_interval_plan
    assert_equal monthly, annual.find_interval_plan
  end

  test "monthly?" do
    assert monthly.monthly?
    assert_not annual.monthly?
  end

  test "annual?" do
    assert annual.annual?
    assert_not monthly.annual?
  end

  test "yearly?" do
    assert annual.yearly?
    assert_not monthly.yearly?
  end

  test "monthly_version" do
    assert_equal monthly, annual.monthly_version
  end

  test "yearly_version" do
    assert_equal annual, monthly.yearly_version
  end

  test "annual_version" do
    assert_equal annual, monthly.annual_version
  end

  test "default scope only has visible plans" do
    assert_not_includes Plan.visible, plans(:hidden)
    assert_equal Plan.visible.count, Plan.count - Plan.hidden.count
  end

  test "visible doesn't include hidden plans" do
    assert_includes Plan.visible, plans(:personal)
    assert_not_includes Plan.visible, plans(:hidden)
  end

  test "hidden doesn't include visible plans" do
    assert_includes Plan.hidden, plans(:hidden)
    assert_not_includes Plan.hidden, plans(:personal)
  end

  test "plan converts stripe_tax to boolean" do
    plan = Plan.first
    plan.stripe_tax = "1"
    assert plan.stripe_tax

    plan.stripe_tax = "0"
    assert_not plan.stripe_tax
  end

  test "unit label required if charge_by_unit enabled" do
    plan = Plan.new(charge_per_unit: true, unit_label: "")
    assert_not plan.valid?
    assert plan.errors[:unit_label].any?
  end

  test "a plan with an active subscriber can't be deleted" do
    plan = plans(:personal)
    subscribe_to(plan.stripe_id)

    assert_not plan.destroy
    assert Plan.exists?(plan.id)
    assert_includes plan.errors.full_messages, "This plan has subscribers, so it can't be deleted. Hide it instead."
  end

  test "a plan referenced only by a canceled subscription can't be deleted" do
    plan = plans(:personal)
    subscribe_to(plan.stripe_id, status: "canceled")

    assert_not plan.destroy
    assert Plan.exists?(plan.id)
  end

  test "a subscriber on any of the plan's processor IDs blocks deletion" do
    plan = plans(:personal)
    plan.update_column(:fake_processor_id, "personal-fake")
    subscribe_to("personal-fake")

    assert_not plan.destroy
    assert Plan.exists?(plan.id)
  end

  test "a plan with no subscribers can be deleted" do
    plan = plans(:business)

    assert plan.destroy
    assert_not Plan.exists?(plan.id)
  end

  test "a plan with every processor ID blank can be deleted" do
    plan = Plan.create!(name: "Blank", amount: 100, interval: "month")

    assert plan.destroy
  end

  test "destroy! raises for a plan with subscribers" do
    plan = plans(:personal)
    subscribe_to(plan.stripe_id)

    assert_raises(ActiveRecord::RecordNotDestroyed) { plan.destroy! }
  end

  private

  def subscribe_to(processor_plan, status: "active")
    pay_customers(:subscribed).subscriptions.create!(
      name: "default", processor_id: "sub_#{SecureRandom.hex(4)}",
      processor_plan: processor_plan, quantity: 1, status: status
    )
  end

  def monthly
    @monthly ||= plans(:personal)
  end

  def annual
    @annual ||= plans(:personal_annual)
  end
end
