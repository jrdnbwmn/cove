require "test_helper"

class Jumpstart::SubscriptionsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @plan = plans(:personal)
    @card_token = "tok_visa"
  end

  class AdminUsers < Jumpstart::SubscriptionsTest
    include ActiveJob::TestHelper

    # Applies to personal and team accounts

    setup do
      sign_in @admin
      @account = @admin.personal_account
      Jumpstart::Multitenancy.stub :selected, [] do
        switch_account(@account)
      end
    end

    test "can view billing" do
      Jumpstart.config.stub(:payments_enabled?, true) do
        get billing_path
        assert_response :success
      end
    end

    test "can successfully update a billing email" do
      Jumpstart.config.stub(:payments_enabled?, true) do
        @account.update!(billing_email: nil)
        patch billing_path, params: {account: {billing_email: "accounting@example.com"}}

        assert_response :redirect
        assert_not_nil @account.reload.billing_email
      end
    end

    test "Account can not be subscribed twice" do
      Jumpstart.config.stub(:payments_enabled?, true) do
        @account.set_payment_processor :fake_processor, allow_fake: true
        @account.payment_processor.subscribe
        get checkout_path(plan: @plan)
        assert_redirected_to billing_path
        assert_equal I18n.t("checkouts.already_subscribed"), flash[:alert]
      end
    end

    test "can successfully update a extra billing info" do
      Jumpstart.config.stub(:payments_enabled?, true) do
        patch billing_path, params: {account: {extra_billing_info: "VAT_ID"}}

        assert_response :redirect
        assert_equal "VAT_ID", @account.reload.extra_billing_info
      end
    end

    test "can manage a fake processor subscription lifecycle" do
      monthly_plan = plans(:per_seat)
      changed_plan = plans(:enterprise)
      @account.set_payment_processor :fake_processor, allow_fake: true

      get pricing_path
      assert_response :success

      subscription = @account.payment_processor.subscribe(plan: monthly_plan.fake_processor_id)
      assert_equal monthly_plan.fake_processor_id, subscription.processor_plan

      patch billing_subscription_path(subscription), params: {plan: changed_plan.to_param}
      assert_redirected_to billing_path
      assert_equal changed_plan.fake_processor_id, subscription.reload.processor_plan

      delete billing_subscription_cancel_path(subscription)
      assert_redirected_to billing_path
      assert subscription.reload.canceled?

      patch billing_subscription_resume_path(subscription)
      assert_redirected_to billing_path
      assert subscription.reload.active?
    end

    test "cancelling a subscription schedules one delayed Loops cancellation-survey delivery" do
      @account.set_payment_processor :fake_processor, allow_fake: true
      subscription = @account.payment_processor.subscribe
      captured_request = nil
      stub = stub_request(:post, "https://app.loops.so/api/v1/transactional")
        .with do |request|
          captured_request = request
          true
        end
        .to_return(status: 200, body: {success: true}.to_json)
      original_delivery_method = AccountMailer.delivery_method
      AccountMailer.delivery_method = :loops

      travel_to Time.current.change(usec: 0) do
        scheduled_at = 1.hour.from_now

        assert_enqueued_jobs 1, only: LoopsMailDeliveryJob do
          assert_enqueued_with(job: LoopsMailDeliveryJob, at: scheduled_at) do
            Jumpstart.config.stub(:payments_enabled?, true) do
              delete billing_subscription_cancel_path(subscription)
            end
          end
        end

        assert_redirected_to billing_path
        assert subscription.reload.canceled?
        assert_not_requested stub

        perform_enqueued_jobs(only: LoopsMailDeliveryJob, at: scheduled_at)
      end

      assert_requested stub, times: 1

      body = JSON.parse(captured_request.body)
      assert_equal @admin.email, body["email"]
      assert_equal "cmsdrmznp040g0jzsnkt9hpsa", body["transactionalId"]
      assert_equal({}, body["dataVariables"])
      expected_key = LoopsClient.client.idempotency_key(
        "cmsdrmznp040g0jzsnkt9hpsa", @admin.email, body["dataVariables"]
      )
      assert_equal expected_key, captured_request.headers["Idempotency-Key"]
    ensure
      AccountMailer.delivery_method = original_delivery_method
    end
  end

  class RegularUsers < Jumpstart::SubscriptionsTest
    # Regular users on a team account

    setup do
      @regular_user = users(:two)
      sign_in @regular_user
      @account = accounts(:company)
      Jumpstart.config.stub(:account_types, "both") do
        Jumpstart::Multitenancy.stub :selected, [] do
          switch_account(@account)
        end
      end
    end

    test "cannot navigate to new_subscription page" do
      Jumpstart.config.stub(:account_types, "both") do
        Jumpstart.config.stub(:payments_enabled?, true) do
          get checkout_path(plan: @plan)
          assert_redirected_to root_path
          assert_equal I18n.t("must_be_an_admin"), flash[:alert]
        end
      end
    end

    test "cannot subscribe" do
      Jumpstart.config.stub(:account_types, "both") do
        Jumpstart.config.stub(:payments_enabled?, true) do
          post checkout_path, params: {}
          assert_redirected_to root_path
          assert_equal I18n.t("must_be_an_admin"), flash[:alert]
        end
      end
    end

    test "cannot delete subscription" do
      @account.set_payment_processor :fake_processor, allow_fake: true
      subscription = @account.payment_processor.subscribe
      Jumpstart.config.stub(:payments_enabled?, true) do
        delete billing_subscription_cancel_path(subscription)
        assert_redirected_to root_path
        assert_equal I18n.t("must_be_an_admin"), flash[:alert]
      end
    end
  end
end
