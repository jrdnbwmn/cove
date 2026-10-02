require "test_helper"

class LoopsJobPriorityTest < ActiveJob::TestCase
  test "marketing sync jobs yield to mail and billing jobs" do
    [
      LoopsContactBackfillJob,
      LoopsContactSyncJob,
      LoopsContactDeletionJob,
      LoopsEventJob,
      LoopsWebhookEventJob
    ].each do |job_class|
      assert_equal 10, job_class.new.priority
    end
  end
end
