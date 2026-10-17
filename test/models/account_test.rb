require "test_helper"
require "tmpdir"
require_relative "../support/stripe_schedule_helper"

class AccountTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include StripeScheduleHelper

  test "every family shares a fixed pretend date and clearing restores its own clock" do
    Dir.mktmpdir("cove-account-clock") do |directory|
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
        DevClock.stub(:path, Pathname.new(directory).join("dev_today")) do
          west = accounts(:one)
          east = accounts(:company)
          west.time_zone = "International Date Line West"
          east.time_zone = "Nuku'alofa"
          DevClock.set(Date.new(2026, 10, 14))
          [Time.utc(2026, 10, 17, 12), Time.utc(2026, 10, 20, 12)].each do |instant|
            travel_to instant do
              assert_equal Date.new(2026, 10, 14), west.today
              assert_equal west.today, east.today
              assert_not_equal west.real_today, east.real_today
            end
          end
          DevClock.clear
          travel_to Time.utc(2026, 10, 17, 12) do
            assert_equal Date.new(2026, 10, 16), west.today
            assert_equal Date.new(2026, 10, 18), east.today
          end
        end
      end
    end
  end

  test "families default to Mountain time and require a recognized Rails time zone" do
    account = Account.new(owner: users(:admin), name: "Clock family")
    assert_equal "Mountain Time (US & Canada)", account.time_zone
    ActiveSupport::TimeZone.all.each do |zone|
      account.time_zone = zone.name
      assert account.valid?, zone.name
    end
    [nil, "", "Unknown/Zone", "America/Denver"].each do |zone|
      account.time_zone = zone
      assert_not account.valid?
      assert_not_empty account.errors[:time_zone]
    end
  end

  test "the family day turns over at one in the morning" do
    account = accounts(:one)
    travel_to Time.utc(2026, 10, 17, 6, 59) do
      assert_equal Date.new(2026, 10, 16), account.today
    end
    travel_to Time.utc(2026, 10, 17, 7) do
      assert_equal Date.new(2026, 10, 17), account.today
    end
  end

  test "the family day follows its own zone across date boundaries" do
    travel_to Time.utc(2026, 10, 17, 12) do
      account = accounts(:one)
      account.time_zone = "International Date Line West"
      assert_equal Date.new(2026, 10, 16), account.today
      account.time_zone = "Nuku'alofa"
      assert_equal Date.new(2026, 10, 18), account.today
    end
  end

  test "the family clock subtracts an elapsed hour across daylight saving transitions" do
    account = accounts(:one)
    {
      Time.utc(2026, 3, 8, 7, 59) => Date.new(2026, 3, 7),
      Time.utc(2026, 3, 8, 8) => Date.new(2026, 3, 8),
      Time.utc(2026, 3, 8, 9) => Date.new(2026, 3, 8),
      Time.utc(2026, 11, 1, 6, 59) => Date.new(2026, 10, 31),
      Time.utc(2026, 11, 1, 7) => Date.new(2026, 11, 1),
      Time.utc(2026, 11, 1, 8) => Date.new(2026, 11, 1)
    }.each do |instant, day|
      travel_to(instant) { assert_equal day, account.today }
    end
  end

  test "validates uniqueness of domain" do
    account = accounts(:company).dup
    assert_not account.valid?
    assert_not_empty account.errors[:domain]
  end

  test "can have multiple accounts with nil domain" do
    assert_nothing_raised do
      Account.create!(owner: users(:admin), name: "test")
      Account.create!(owner: users(:marketing_subscribed), name: "test2")
    end
  end

  test "validates uniqueness of subdomain" do
    account = accounts(:company).dup
    assert_not account.valid?
    assert_not_empty account.errors[:subdomain]
  end

  test "can have multiple accounts with nil subdomain" do
    assert_nothing_raised do
      Account.create!(owner: users(:admin), name: "test")
      Account.create!(owner: users(:marketing_subscribed), name: "test2")
    end
  end

  test "validates against reserved domains" do
    account = Account.new(domain: Jumpstart.config.domain)
    assert_not account.valid?
    assert_not_empty account.errors[:domain]
  end

  test "validates against reserved subdomains" do
    subdomain = Account::RESERVED_SUBDOMAINS.first
    account = Account.new(subdomain: subdomain)
    assert_not account.valid?
    assert_not_empty account.errors[:subdomain]
  end

  test "subdomain format must start with alphanumeric char" do
    account = Account.new(subdomain: "-abcd")
    assert_not account.valid?
    assert_not_empty account.errors[:subdomain]
  end

  test "subdomain format must end with alphanumeric char" do
    account = Account.new(subdomain: "abcd-")
    assert_not account.valid?
    assert_not_empty account.errors[:subdomain]
  end

  test "must be at least two characters" do
    account = Account.new(subdomain: "a")
    assert_not account.valid?
    assert_not_empty account.errors[:subdomain]
  end

  test "can use a mixture of alphanumeric, hyphen, and underscore" do
    [
      "ab",
      "12",
      "a-b",
      "a-9",
      "1-2",
      "1_2",
      "a_3"
    ].each do |subdomain|
      account = Account.new(subdomain: subdomain)
      account.valid?
      assert_empty account.errors[:subdomain]
    end
  end

  test "does not allow personal families" do
    account = Account.new(owner: users(:admin), name: "Personal Family", personal: true)

    assert_not account.valid?
    assert_includes account.errors[:personal], "must be false"
  end

  test "owner?" do
    account = accounts(:one)
    assert account.owner?(users(:noaccount))
    assert_not account.owner?(users(:one))
  end

  test "can_transfer? true for owner" do
    account = accounts(:company)
    assert account.can_transfer?(account.owner)
  end

  test "can_transfer? false for non-owner" do
    assert_not accounts(:company).can_transfer?(users(:two))
  end

  test "transfer ownership to a new owner" do
    account = accounts(:company)
    new_owner = users(:two)
    assert accounts(:company).transfer_ownership(new_owner.id)
    assert_equal new_owner, account.reload.owner
  end

  test "transfer ownership fails transferring to a user outside the account" do
    account = accounts(:company)
    owner = account.owner
    assert_not account.transfer_ownership(users(:invited).id)
    assert_equal owner, account.reload.owner
  end

  test "transfer ownership enqueues stripe sync" do
    account = accounts(:company)
    new_owner = users(:two)
    payment_processor = account.set_payment_processor :fake_processor, allow_fake: true
    assert_enqueued_with job: Pay::CustomerSyncJob, args: [payment_processor.id] do
      account.transfer_ownership(new_owner.id)
    end
  end

  test "billing_email shouldn't be included in receipts if empty" do
    account = accounts(:company)
    account.update!(billing_email: nil)
    pay_customer = account.set_payment_processor :fake_processor, allow_fake: true
    pay_charge = pay_customer.charge(10_00)

    mail = Pay::UserMailer.with(pay_customer: pay_customer, pay_charge: pay_charge).receipt
    assert_equal [account.owner.email, users(:two).email], mail.to
  end

  test "billing_email should be included in receipts if present" do
    account = accounts(:company)
    account.update!(billing_email: "accounting@example.com")
    pay_customer = account.set_payment_processor :fake_processor, allow_fake: true
    pay_charge = pay_customer.charge(10_00)

    mail = Pay::UserMailer.with(pay_customer: pay_customer, pay_charge: pay_charge).receipt
    assert_equal [account.owner.email, users(:two).email, "accounting@example.com"], mail.to
  end

  test "destroys noticed events when associated" do
    account = accounts(:one)
    Noticed::Event.create!(account: account)

    assert_difference "Noticed::Event.count", -1 do
      account.destroy
    end
  end

  test "destroys noticed events when associated as record" do
    account = accounts(:one)
    Noticed::Event.create!(account: accounts(:two), record: account)

    assert_difference "Noticed::Event.count", -1 do
      account.destroy
    end
  end

  test "deleting a family deletes its classes" do
    account = Account.create!(owner: users(:marketing_subscribed), name: "Class Family")
    course = Course.create!(account: account, name: "Algebra 1")

    assert_difference "Course.count", -1 do
      account.destroy!
    end

    assert_not Course.exists?(course.id)
  end

  test "account can be subscribed" do
    assert accounts(:subscribed).payment_processor.subscribed?
  end

  [:one, :subscribed, :complimentary].each do |label|
    test "#{label} family can add fourteen learners and reaches capacity at fifteen" do
      account = accounts(label)
      account.learners.load
      14.times { |i| Learner.create!(account: account, name: "Learner #{i}") }
      assert account.can_add_learner?
      Learner.create!(account: account, name: "Final learner")
      assert_not account.can_add_learner?
    end
  end

  test "a Free family uses its superadmin-raised cap" do
    account = accounts(:one)
    account.update!(learner_limit: 20)
    19.times { |i| Learner.create!(account: account, name: "Learner #{i}") }
    assert account.can_add_learner?
    Learner.create!(account: account, name: "Final learner")
    assert_not account.can_add_learner?
  end

  test "archived learners free a slot at the family cap" do
    account = accounts(:one)
    15.times { |i| Learner.create!(account: account, name: "Learner #{i}") }
    assert_not account.can_add_learner?
    account.learners.first.archive!
    assert account.can_add_learner?
  end

  test "a complimentary family is Premium without billing records" do
    account = accounts(:complimentary)

    assert account.premium?
    assert_not account.free?
    assert_equal 15, account.learner_limit
    assert_equal "complimentary", account.plan_status
    assert_empty account.pay_customers
    assert_empty account.pay_subscriptions
  end

  test "revoking complimentary Premium retains its note and restores Free access" do
    account = accounts(:complimentary)
    note = account.complimentary_premium_note

    account.update!(complimentary_premium: false)

    assert_equal note, account.complimentary_premium_note
    assert account.free?
    assert_equal "free", account.plan_status
    assert_equal 15, account.learner_limit
  end

  test "a family cannot receive complimentary Premium without a note" do
    account = accounts(:one)

    [nil, "", "   "].each do |note|
      account.assign_attributes(complimentary_premium: true, complimentary_premium_note: note)

      assert_not account.valid?, "expected #{note.inspect} to be invalid"
      assert_not_empty account.errors[:complimentary_premium_note]
    end
  end

  test "an unsubscribed family has free plan status" do
    assert_equal "free", accounts(:one).plan_status
  end

  test "checking premium status repeatedly only queries once" do
    account = accounts(:one).reload

    assert_queries_count(1) { 3.times { account.paid_premium? } }
  end

  test "reload picks up a new subscription" do
    account = accounts(:one)
    assert_not account.paid_premium?

    customer = account.set_payment_processor(:fake_processor, allow_fake: true)
    customer.subscriptions.create!(name: "default", processor_id: "fake_new", processor_plan: plans(:premium_monthly).fake_processor_id, quantity: 1, status: "active")

    assert account.reload.paid_premium?
  end

  test "a paid subscription takes precedence over complimentary Premium" do
    account = accounts(:subscribed)
    account.update!(complimentary_premium: true, complimentary_premium_note: "Converted tester")

    assert account.premium?
    assert_equal "premium", account.plan_status

    account.update!(complimentary_premium: false)

    assert account.premium?
    assert_equal "premium", account.plan_status
  end

  test "a family with an active monthly subscription is premium and allowed its limit" do
    account = accounts(:subscribed)
    subscription = account.pay_subscriptions.first
    subscription.update!(processor_plan: plans(:premium_monthly).fake_processor_id)

    assert account.premium?
    assert_not account.free?
    assert_equal 15, account.learner_limit
  end

  test "a family with an active yearly subscription is premium and allowed its limit" do
    account = accounts(:subscribed)
    subscription = account.pay_subscriptions.first
    subscription.update!(processor_plan: plans(:premium_yearly).fake_processor_id)

    assert account.premium?
    assert_equal 15, account.learner_limit
  end

  test "a raised learner limit is retained while a family is free" do
    account = accounts(:subscribed)
    account.update!(learner_limit: 20)

    assert_equal 20, account.learner_limit

    account.pay_subscriptions.first.update!(status: "unpaid")

    assert account.reload.free?
    assert_equal 20, account.learner_limit
  end

  test "a canceled family stays premium through its paid period" do
    account = accounts(:canceled_in_period)

    assert account.premium?
    assert_equal 15, account.learner_limit
  end

  test "a family is free when its canceled subscription has ended" do
    account = accounts(:canceled_ended)

    assert account.free?
    assert_equal 15, account.learner_limit
  end

  test "a past due family remains premium while payment is retried" do
    account = accounts(:past_due)

    assert account.premium?
    assert_equal 15, account.learner_limit
  end

  test "an unpaid family is free" do
    account = accounts(:unpaid)

    assert account.free?
    assert_equal 15, account.learner_limit
  end

  test "a paused family is free" do
    account = accounts(:paused)

    assert account.free?
    assert_equal 15, account.learner_limit
  end

  test "a family on a hidden old price remains premium" do
    account = accounts(:old_price)
    subscription = account.pay_subscriptions.first

    assert plans(:hidden).hidden?
    assert_equal plans(:hidden).stripe_id, subscription.processor_plan
    assert account.premium?
    assert_equal 15, account.learner_limit
  end

  test "a family can use a superadmin-raised Premium limit" do
    account = accounts(:complimentary)

    account.update!(learner_limit: 20)

    assert_equal 20, account.learner_limit
  end

  test "a family's learner limit can't be below the default or a decimal" do
    account = accounts(:one)

    [nil, "", 0, 1, 14, -1, 15.5].each do |learner_limit|
      account.learner_limit = learner_limit

      assert_not account.valid?, "expected #{learner_limit.inspect} to be invalid"
      assert_not_empty account.errors[:learner_limit]
    end

    account.learner_limit = 15
    assert account.valid?

    account.learner_limit = 20
    assert account.valid?
  end

  test "separates active and archived families" do
    account = accounts(:one)

    account.archive!

    assert_includes Account.archived, account
    assert_not_includes Account.active, account
  end

  test "a pending invitation holds a seat so a family can't invite past two parents" do
    account = accounts(:invited)

    assert_predicate account, :invitations_full?

    account.account_invitations.destroy_all

    assert_not_predicate account.reload, :invitations_full?
  end

  test "a family reports whether it is archived" do
    account = accounts(:one)

    assert_not_predicate account, :archived?
    account.archive!
    assert_predicate account, :archived?
  end

  test "parents are the family admins" do
    assert_equal accounts(:company).admins.order(:id).to_a, accounts(:company).parents.order(:id).to_a
  end

  test "archiving a family preserves its payment records" do
    account = accounts(:one)
    customer = account.set_payment_processor(:fake_processor, allow_fake: true)
    subscription = customer.subscribe(plan: "per_seat")

    account.archive!

    assert_equal customer, account.pay_customers.find(customer.id)
    assert_equal subscription, account.pay_subscriptions.find(subscription.id)
  end

  test "a one-parent family without billable subscriptions is joinable by its parent" do
    account = accounts(:one)

    assert account.joinable_by?(users(:noaccount))
    assert_not account.joinable_by?(users(:admin))
  end

  test "a family with an active or past-due subscription is not joinable" do
    account = accounts(:one)
    customer = account.set_payment_processor(:fake_processor, allow_fake: true)
    active_subscription = customer.subscribe(name: "active", plan: "per_seat")

    assert_not account.joinable_by?(users(:noaccount))

    active_subscription.update!(status: "past_due")

    assert_not account.joinable_by?(users(:noaccount))
  end

  test "a family with active learners is not joinable and reports has_learners" do
    account = accounts(:one)
    Learner.create!(account: account, name: "Maya")

    assert_not account.joinable_by?(users(:noaccount))
    assert_equal :has_learners, account.unjoinable_reason(users(:noaccount))
  end

  test "a family with only archived learners is not joinable" do
    account = accounts(:one)
    Learner.create!(account: account, name: "Maya", archived_at: Time.current)

    assert_equal :has_learners, account.unjoinable_reason(users(:noaccount))
  end

  test "another parent takes precedence over learners when explaining why a family is not joinable" do
    account = accounts(:company)

    assert account.learners.any?
    assert_equal :other_members, account.unjoinable_reason(users(:one))
  end

  test "learners block joining before a billable subscription does" do
    account = accounts(:one)
    Learner.create!(account: account, name: "Maya")
    customer = account.set_payment_processor(:fake_processor, allow_fake: true)
    customer.subscribe(name: "active", plan: "per_seat")

    assert_equal :has_learners, account.unjoinable_reason(users(:noaccount))
  end

  test "learner emptiness is read from the association without a respond_to guard" do
    account = accounts(:company)
    account.define_singleton_method(:respond_to?) { |name, *args| (name == :learners) ? false : super(name, *args) }

    assert_not account.send(:learners_empty?)
  end

  test "destroying a family destroys its learners" do
    account = accounts(:company)
    learner_ids = account.learners.pluck(:id)
    assert_not_empty learner_ids

    account.destroy!

    assert_empty Learner.where(id: learner_ids)
  end

  test "a family whose Premium is canceled but still paid through the period is joinable" do
    account = accounts(:canceled_in_period)

    assert account.joinable_by?(users(:canceled_in_period))
  end

  test "destroying a family immediately cancels active and past-due subscriptions" do
    account = accounts(:one)
    customer = account.set_payment_processor(:fake_processor, allow_fake: true)
    active_subscription = customer.subscribe(name: "active", plan: "per_seat")
    past_due_subscription = customer.subscribe(name: "past_due", plan: "per_seat")
    past_due_subscription.update!(status: "past_due")

    account.destroy!

    assert_predicate active_subscription.reload, :canceled?
    assert_predicate past_due_subscription.reload, :canceled?
  end

  test "deleting a family with an unpaid subscription cancels it in Stripe" do
    account = accounts(:unpaid)
    subscription = account.pay_subscriptions.sole

    account.destroy!

    assert_predicate subscription.reload, :canceled?
  end

  test "deleting a family with an incomplete subscription cancels it in Stripe" do
    account = accounts(:unpaid)
    subscription = account.pay_subscriptions.sole
    subscription.update_columns(status: "incomplete")

    account.destroy!

    assert_predicate subscription.reload, :canceled?
  end

  test "destroying a family releases a pending plan switch before cancelling its subscription" do
    stripe_api_key!
    subscription = stripe_subscription_for(accounts(:one), plan: plans(:premium_yearly), schedule: {"id" => "sub_sched_delete", "phases" => []})
    events = []
    stub_stripe_release("sub_sched_delete", events: events)
    stub_stripe_sync(subscription, events: events)
    stub_cancel_now(subscription, events)

    accounts(:one).destroy!

    assert_equal [:release, :sync, :cancel], events
  end

  test "destroying a family still cancels its subscription when the schedule cannot be released" do
    stripe_api_key!
    subscription = stripe_subscription_for(accounts(:one), plan: plans(:premium_yearly), schedule: {"id" => "sub_sched_delete", "phases" => []})
    events = []
    stub_stripe_release("sub_sched_delete", events: events, status: 400)
    stub_cancel_now(subscription, events)

    accounts(:one).destroy!

    assert_equal [:release, :cancel], events
    assert_not Account.exists?(accounts(:one).id)
  end

  private

  def stub_cancel_now(subscription, events)
    stub_request(:delete, %r{https://api\.stripe\.com/v1/subscriptions/#{subscription.processor_id}}).to_return {
      events << :cancel
      {status: 200, body: stripe_subscription_json(subscription, "status" => "canceled", "ended_at" => Time.current.to_i).to_json}
    }
  end

  test "browser zones map to the Rails zone names we store" do
    assert_equal "Eastern Time (US & Canada)", Account.normalize_time_zone("America/New_York")
    assert_equal "Eastern Time (US & Canada)", Account.normalize_time_zone("Eastern Time (US & Canada)")
    assert_nil Account.normalize_time_zone("Unknown/Zone")
    assert_nil Account.normalize_time_zone(nil)
  end

  test "a family without a school year raises not found when one is required" do
    assert_equal accounts(:company).school_year, accounts(:company).school_year!
    accounts(:company).school_years.destroy_all
    assert_raises(ActiveRecord::RecordNotFound) { accounts(:company).school_year! }
  end
end
