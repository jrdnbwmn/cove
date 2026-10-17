require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Fixtures are loaded directly by Rails before each test, so their records do
  # not exercise User creation callbacks; callback coverage builds users here.
  test "user has one family" do
    user = users(:one)
    assert_equal accounts(:company), user.family
    assert_equal [accounts(:company)], user.accounts.to_a
  end

  test "looking up a user's family repeatedly only queries once" do
    user = users(:one).reload

    assert_queries_count(1) { 3.times { user.family } }
  end

  test "reload clears the cached family" do
    user = users(:one)
    assert_equal accounts(:company), user.family
    AccountUser.where(user: user).delete_all

    assert_nil user.reload.family
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

  test "signup creates the family year and holidays together using the parent's time zone" do
    travel_to Time.utc(2026, 7, 10, 12) do
      user = nil
      assert_difference({"Account.count" => 1, "SchoolYear.count" => 1, "Break.count" => 2}) do
        user = User.create!(name: "School Parent", email: "school-parent@example.com", password: "password", terms_of_service: true, time_zone: "Eastern Time (US & Canada)")
      end
      assert_equal "Eastern Time (US & Canada)", user.family.time_zone
      assert_equal Date.new(2026, 8, 17), user.family.school_year.starts_on
      assert_no_difference ["Account.count", "SchoolYear.count", "Break.count"] do
        assert_equal user.family, user.create_default_account
      end
    end
  end

  test "signup falls back to Mountain time when the parent has no zone" do
    user = User.create!(name: "Default Parent", email: "default-parent@example.com", password: "password", terms_of_service: true)
    assert_equal "Mountain Time (US & Canada)", user.family.time_zone
    assert user.family.school_year
  end

  test "a failure creating the family leaves no partial signup records" do
    assert_no_difference ["User.count", "Account.count", "SchoolYear.count", "Break.count"] do
      assert_raises ActiveRecord::RecordInvalid do
        User.create!(name: "Invalid Zone", email: "invalid-zone@example.com", password: "password", terms_of_service: true, time_zone: "Unknown/Zone")
      end
    end
  end

  test "an invitation signup creates no year or holidays" do
    assert_no_difference ["Account.count", "SchoolYear.count", "Break.count"] do
      User.create!(name: "Invited School Parent", email: "invited-school@example.com", password: "password", terms_of_service: true, invitation_signup: true)
    end
  end

  test "changing the password revokes the user's API tokens" do
    user = users(:one)
    assert user.api_tokens.exists?

    user.update!(password: "a-new-password", password_confirmation: "a-new-password")

    assert_empty user.api_tokens.reload
    assert api_tokens(:two).reload
  end

  test "updating the name keeps API tokens" do
    user = users(:one)

    assert_no_difference "user.api_tokens.count" do
      user.update!(name: "Renamed Parent")
    end
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

  test "finds a user by email regardless of case or surrounding spaces" do
    user = users(:one)

    assert_equal user, User.by_email("  #{user.email.upcase} ").sole
  end
end
