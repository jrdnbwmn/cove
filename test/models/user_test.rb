require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Fixtures are loaded directly by Rails before each test, so their records do
  # not exercise User creation callbacks; callback coverage builds users here.
  test "user has one family" do
    user = users(:one)
    assert_equal accounts(:company), user.family
    assert_equal [accounts(:company)], user.accounts.to_a
  end

  test "new users receive one owner-admin family with an automatic name" do
    user = User.create!(name: "Test Parent", email: "test-parent@example.com", password: "password", password_confirmation: "password", terms_of_service: true)

    assert_equal "Test Parent's Family", user.family.name
    assert_equal user, user.family.owner
    assert_predicate user.family.account_users.find_by!(user: user), :admin?
  end

  test "an invitation signup skips default family creation" do
    user = User.new(name: "Invited Parent", email: "invited-parent@example.com", password: "password", password_confirmation: "password", terms_of_service: true)
    user.invitation_signup = true

    assert user.save
    assert_nil user.family
  end

  test "can delete user with accounts" do
    assert_difference "User.count", -1 do
      users(:one).destroy
    end
  end

  test "renders name with ActionText to_plain_text" do
    user = users(:one)
    assert_equal user.name, user.attachable_plain_text_representation
  end

  test "can search users by name generated column" do
    assert_equal users(:one), User.search("one").first
  end
end
