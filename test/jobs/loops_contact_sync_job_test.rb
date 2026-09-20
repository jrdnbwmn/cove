require "test_helper"

class LoopsContactSyncJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup { clear_enqueued_jobs }

  test "opt_in from registration enqueues the signed-up event" do
    user = users(:marketing_subscribed)
    assert_equal "registration", user.marketing_opt_in_source

    assert_enqueued_with(job: LoopsEventJob, args: [user.id, "user_signed_up"]) do
      LoopsContactSyncJob.perform_now(user.id, "opt_in")
    end
  end

  test "opt_in from settings does not enqueue an event" do
    user = users(:marketing_subscribed)
    user.update!(marketing_opt_in_source: "settings")

    LoopsContactSyncJob.perform_now(user.id, "opt_in")

    assert_no_enqueued_jobs only: LoopsEventJob
  end

  test "opt_out and email_change intents do not enqueue an event" do
    opt_out_user = users(:marketing_unsubscribed)
    email_change_user = users(:marketing_subscribed)

    LoopsContactSyncJob.perform_now(opt_out_user.id, "opt_out")
    LoopsContactSyncJob.perform_now(email_change_user.id, "email_change")

    assert_no_enqueued_jobs only: LoopsEventJob
  end

  test "plan status forwards its intent to the synchronizer and does not enqueue an event" do
    user = users(:marketing_subscribed)
    synchronizer = Object.new
    calls = []
    synchronizer.define_singleton_method(:sync) { |record, **attributes| calls << [record, attributes] }

    LoopsContactSynchronizer.stub(:new, synchronizer) do
      LoopsContactSyncJob.perform_now(user.id, "plan_status")
    end

    assert_equal [[user, {intent: "plan_status", previously_consented: nil}]], calls
    assert_no_enqueued_jobs only: LoopsEventJob
  end

  test "a retryable plan-status failure is retried and enqueues no event" do
    user = users(:marketing_subscribed)
    raising_synchronizer = Object.new.tap { |double| double.define_singleton_method(:sync) { |*| raise LoopsClient::InternalError, "boom" } }

    LoopsContactSynchronizer.stub(:new, raising_synchronizer) do
      assert_enqueued_with(job: LoopsContactSyncJob, args: [user.id, "plan_status"]) do
        LoopsContactSyncJob.perform_now(user.id, "plan_status")
      end
    end

    assert_no_enqueued_jobs only: LoopsEventJob
  end

  test "an unknown user id is a no-op" do
    unknown_id = User.maximum(:id).to_i + 1

    LoopsContactSyncJob.perform_now(unknown_id, "opt_in")

    assert_no_enqueued_jobs only: LoopsEventJob
  end
end
