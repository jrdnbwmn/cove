require "test_helper"

class AdminBootstrapTest < ActiveSupport::TestCase
  TOKEN = "generated-bootstrap-token"

  test "blank email skips without creating a user" do
    output, = capture_io do
      assert_no_difference -> { User.count } do
        assert_nil AdminBootstrap.call(email: " ", name: "Cove Admin")
      end
    end

    assert_includes output, "[admin:bootstrap] skipped: BOOTSTRAP_ADMIN_EMAIL unset"
  end

  test "creates a confirmed system admin with the default name" do
    user = with_bootstrap_token { AdminBootstrap.call(email: " BOOTSTRAP-ADMIN@EXAMPLE.COM ", name: " ") }

    assert_equal "bootstrap-admin@example.com", user.email
    assert_equal "Cove", user.first_name
    assert_equal "Admin", user.last_name
    assert_predicate user, :admin?
    assert_not_nil user.confirmed_at
    assert_not_equal TOKEN, user.encrypted_password
  end

  test "repeated calls preserve a created user's password and name" do
    user = with_bootstrap_token { AdminBootstrap.call(email: "bootstrap@example.com", name: "First Last") }
    password = user.encrypted_password

    result = AdminBootstrap.call(email: " BOOTSTRAP@example.com ", name: "Changed Name")

    assert_equal user, result
    assert_equal 1, User.where(email: "bootstrap@example.com").count
    assert_equal password, result.encrypted_password
    assert_equal "First", result.first_name
    assert_equal "Last", result.last_name
  end

  test "promotes an existing user without changing profile password or marketing consent" do
    user = users(:marketing_subscribed)
    original_attributes = user.attributes.slice("encrypted_password", "first_name", "last_name", "marketing_opt_in_at", "marketing_opt_in_source", "marketing_opt_out_at", "marketing_opt_out_reason")

    result = AdminBootstrap.call(email: user.email, name: "Changed Name")

    assert_predicate result, :admin?
    assert_equal original_attributes, result.attributes.slice(*original_attributes.keys)
  end

  test "already-admin user is returned without another grant" do
    user = users(:admin)

    result = Jumpstart.stub(:grant_system_admin!, ->(_) { flunk "already-admin users must not be granted again" }) do
      AdminBootstrap.call(email: user.email, name: "Changed Name")
    end

    assert_equal user, result
  end

  test "invalid email logs the error without exposing the generated password" do
    output, = with_bootstrap_token { capture_io { assert_nil AdminBootstrap.call(email: "not-an-email", name: "Cove Admin") } }

    assert_includes output, "[admin:bootstrap] error:"
    assert_not_includes output, TOKEN
  end

  private

  def with_bootstrap_token(&)
    Devise.stub(:friendly_token, TOKEN, &)
  end
end
