require "test_helper"

class AccountInvitationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @account_invitation = account_invitations(:one)
    @account = @account_invitation.account
  end

  test "cannot invite same email twice" do
    invitation = @account.account_invitations.create(name: "whatever", email: @account_invitation.email)
    assert_not invitation.valid?
  end

  test "accept" do
    user = users(:invited)
    assert_difference "AccountUser.count" do
      account_user = @account_invitation.accept!(user)
      assert account_user.persisted?
      assert_equal user, account_user.user
    end

    assert_raises ActiveRecord::RecordNotFound do
      @account_invitation.reload
    end
  end

  test "reject" do
    assert_difference "AccountInvitation.count", -1 do
      @account_invitation.reject!
    end
  end

  test "accept sends notifications account owner and inviter" do
    assert_difference "Noticed::Notification.count", 2 do
      account_invitations(:two).accept!(users(:invited))
    end
    event = Noticed::Event.last
    assert_equal @account, event.account
    assert_equal users(:invited), event.user
  end

  test "sending a valid invitation delivers one Loops account-invite request" do
    invitation = @account.account_invitations.new(name: "New invitee", email: "new-invitee@example.com", invited_by: users(:one))
    captured_request = nil
    stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
      .with do |request|
        captured_request = request
        true
      end
      .to_return(status: 200, body: {success: true}.to_json)

    with_loops_delivery do
      assert_enqueued_jobs 1, only: LoopsMailDeliveryJob do
        assert invitation.save_and_send_invite
      end

      perform_enqueued_jobs only: LoopsMailDeliveryJob
    end

    assert_requested stub, times: 1

    body = JSON.parse(captured_request.body)
    data_variables = body.fetch("dataVariables")
    invitation_url = data_variables.fetch("invitation_url")

    assert_equal invitation.email, body.fetch("email")
    assert_equal "cmsdr01rw02s00j3ozshehy4f", body.fetch("transactionalId")
    assert_equal({
      "inviter_name" => invitation.invited_by.name,
      "account_name" => invitation.account.name,
      "invitation_url" => invitation_url
    }, data_variables)

    uri = URI.parse(invitation_url)
    recognized = Rails.application.routes.recognize_path(uri.path, method: :get)
    assert_equal "account_invitations", recognized[:controller]
    assert_equal "show", recognized[:action]
    assert_equal invitation.token, recognized[:id]

    expected_key = LoopsClient.client.idempotency_key(
      body.fetch("transactionalId"), invitation.email, data_variables
    )
    assert_equal expected_key, captured_request.headers["Idempotency-Key"]
  end

  test "sending an invalid invitation does not enqueue or deliver mail" do
    invitation = @account.account_invitations.new(name: "", email: "")

    with_loops_delivery do
      assert_enqueued_jobs 0, only: LoopsMailDeliveryJob do
        assert_not invitation.save_and_send_invite
      end
    end

    assert_not_requested :post, "https://app.loops.so/api/v1/transactional"
  end

  private

  def with_loops_delivery
    original_delivery_method = AccountMailer.delivery_method
    AccountMailer.delivery_method = :loops
    yield
  ensure
    AccountMailer.delivery_method = original_delivery_method
  end
end
