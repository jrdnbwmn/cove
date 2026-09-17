require "test_helper"

class FamilyFixtureContractTest < ActiveSupport::TestCase
  test "fixtures give every user at most one family membership" do
    duplicate_memberships = AccountUser.group(:user_id).count.select { |_user_id, count| count > 1 }

    assert_empty duplicate_memberships
  end

  test "company is a two-parent family" do
    company = accounts(:company)

    assert_equal 2, company.account_users.count
    assert_equal company.owner, users(:one)
    assert_equal [users(:one), users(:two)].sort_by(&:id), company.users.sort_by(&:id)
    assert_predicate company.account_users.find_by!(user: users(:one)), :admin?
    assert_predicate company.account_users.find_by!(user: users(:two)), :admin?
  end

  test "fixtures use non-personal families with accurate membership counters" do
    Account.includes(:account_users).find_each do |account|
      assert_not_predicate account, :personal?
      assert_equal account.account_users.size, account.account_users_count
      assert_operator account.account_users.count(&:admin?), :<=, 2
    end
  end
end
