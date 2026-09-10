require "test_helper"

class User::AccountCreatedEmailTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup { clear_enqueued_jobs }

  ["0", "1"].each do |marketing_opt_in|
    test "new user receives an account-created email when marketing opt-in is #{marketing_opt_in}" do
      user = build_user(marketing_opt_in:)

      assert_enqueued_email_with UserMailer, :account_created, params: {user: user} do
        user.save!
      end
    end
  end

  test "updating a user does not send another account-created email" do
    user = build_user(marketing_opt_in: "0")
    user.save!
    clear_enqueued_jobs

    assert_no_enqueued_jobs only: LoopsMailDeliveryJob do
      user.update!(first_name: "Updated")
    end
  end

  test "creating a user does not make an inline Loops request when delivery would fail" do
    user = build_user(marketing_opt_in: "0")
    stub_request(:post, "https://app.loops.so/api/v1/transactional").to_return(status: 500)

    assert_nothing_raised { user.save! }
    assert_enqueued_email_with UserMailer, :account_created, params: {user: user}
    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
  end

  private

  def build_user(marketing_opt_in:)
    User.new(
      email: "account-created-#{SecureRandom.hex(4)}@example.com",
      first_name: "Account",
      last_name: "Created",
      password: UNIQUE_PASSWORD,
      password_confirmation: UNIQUE_PASSWORD,
      terms_of_service: "1",
      marketing_opt_in:
    )
  end
end
