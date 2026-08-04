require "test_helper"
require "rake"

class LoopsContactsTaskTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  TASK_FILE = Rails.root.join("lib/tasks/loops_contacts.rake")

  class ReadinessSynchronizer
    attr_reader :ready_checks

    def initialize(error: nil)
      @error = error
      @ready_checks = 0
    end

    def ensure_backfill_ready!
      @ready_checks += 1
      raise @error if @error

      true
    end
  end

  setup do
    clear_enqueued_jobs
    @original_rake_application = Rake.application
    reload_tasks
  end

  teardown do
    Rake.application = @original_rake_application
  end

  test "dry run reports the current consenting count and every guard state" do
    config = config(enabled: false, list_id: nil)

    Rails.application.stub(:config_for, ->(*) { config }) do
      output = invoke("loops:contacts:backfill:dry_run")

      assert_includes output, "environment: test"
      assert_includes output, "production: false"
      assert_includes output, "contact sync enabled: false"
      assert_includes output, "mailing list configured: false"
      assert_includes output, "consenting users: #{User.marketing_subscribed.count}"
    end
  end

  test "dry run never constructs a client or enqueues a job" do
    config = config(enabled: true)

    LoopsContactSynchronizer.stub(:new, -> { flunk "dry run must not construct a synchronizer" }) do
      Rails.application.stub(:config_for, ->(*) { config }) do
        assert_no_enqueued_jobs { invoke("loops:contacts:backfill:dry_run") }
      end
    end
  end

  test "enqueue refuses each failed readiness guard without queuing work" do
    {
      LoopsContactSynchronizer::ProductionRequired => "requires production",
      LoopsContactSynchronizer::ContactSyncDisabled => "is disabled",
      LoopsContactSynchronizer::MailingListMissing => "mailing list is not configured"
    }.each do |error_class, message|
      readiness = ReadinessSynchronizer.new(error: error_class.new(message))
      reload_tasks

      LoopsContactSynchronizer.stub(:new, readiness) do
        error = assert_raises(error_class) { invoke("loops:contacts:backfill:enqueue") }

        assert_equal message, error.message
        assert_equal 1, readiness.ready_checks
        assert_no_enqueued_jobs
      end
    end
  end

  test "ready production enqueue starts one backfill job at the initial cursor without contact requests" do
    readiness = ReadinessSynchronizer.new

    LoopsContactSynchronizer.stub(:new, readiness) do
      output = nil
      assert_enqueued_with(job: LoopsContactBackfillJob, args: [nil]) do
        output = invoke("loops:contacts:backfill:enqueue")
      end

      assert_equal 1, readiness.ready_checks
      assert_includes output, "environment: test"
      assert_includes output, "initial cursor: nil"
    end
  end

  private

  def invoke(name)
    task = Rake::Task[name]
    task.reenable
    output, = capture_io { task.invoke }
    output
  end

  def reload_tasks
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    load TASK_FILE
  end

  def config(enabled:, list_id: "cmsdo8ncl02wc0j0j4rxwhy4l")
    ActiveSupport::OrderedOptions.new.tap do |result|
      result.contact_sync_enabled = enabled
      result.contact_sync_mailing_list_id = list_id
    end
  end
end
