require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "account can be subscribed" do
    assert accounts(:subscribed).payment_processor.subscribed?
  end

  test "separates active and archived families" do
    account = accounts(:one)

    account.archive!

    assert_includes Account.archived, account
    assert_not_includes Account.active, account
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
end
