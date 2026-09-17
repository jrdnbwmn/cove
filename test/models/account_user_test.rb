require "test_helper"

class AccountUserTest < ActiveSupport::TestCase
  test "converts roles to booleans" do
    member = AccountUser.new admin: "1"
    assert_equal true, member.admin
  end

  test "can be assigned a role" do
    member = AccountUser.new admin: true
    assert_equal true, member.admin
    assert_equal true, member.admin?
  end

  test "role can be false" do
    member = AccountUser.new admin: false
    assert_equal false, member.admin
    assert_equal false, member.admin?
  end

  test "keeps track of active roles" do
    member = AccountUser.new admin: true
    assert_equal [:admin], member.active_roles
  end

  test "has no active roles" do
    member = AccountUser.new admin: false
    assert_empty member.active_roles
  end

  test "owner cannot remove the admin role" do
    member = account_users(:company_admin)
    assert member.account_owner?
    member.update(admin: false)
    assert_not member.valid?
  end

  test "family memberships must be admins" do
    membership = AccountUser.new(account: accounts(:fake_processor), user: users(:admin), admin: false)

    assert_not membership.valid?
    assert_includes membership.errors[:admin], "must be an admin"
  end

  test "a user cannot belong to a second family" do
    membership = AccountUser.new(account: accounts(:fake_processor), user: users(:one), admin: true)

    assert_not membership.valid?
    assert_includes membership.errors[:user], "already belongs to a family"
  end

  test "a family cannot have more than two parents" do
    membership = AccountUser.new(account: accounts(:company), user: users(:admin), admin: true)

    assert_not membership.valid?
    assert_includes membership.errors[:base], "Family already has two parents"
  end
end
