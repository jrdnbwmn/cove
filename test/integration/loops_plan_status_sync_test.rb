require "test_helper"

class LoopsPlanStatusSyncTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  class RecordingClient
    attr_reader :updates

    def initialize
      @updates = []
    end

    def update_contact(**attributes)
      updates << attributes
    end
  end

  setup { clear_enqueued_jobs }

  test "an active subscription queues and sends premium to every consented parent" do
    account = accounts(:company)
    consent_all_parents(account)
    assert_equal account.parents.pluck(:id).sort, account.parents.marketing_subscribed.pluck(:id).sort
    clear_enqueued_jobs

    customer = account.set_payment_processor(:fake_processor, allow_fake: true)
    assert_equal account, customer.owner

    assert_enqueued_with(job: LoopsContactSyncJob, args: [account.owner.id, "plan_status"]) do
      Pay::FakeProcessor::Subscription.create!(
        customer:,
        name: "plan-status",
        processor_id: "fake-plan-status",
        processor_plan: "premium-monthly",
        quantity: 1,
        status: "active"
      )
    end
    assert_enqueued_with(job: LoopsContactSyncJob, args: [users(:two).id, "plan_status"])

    assert_plan_status_updates(account.parents, "premium")
  end

  test "an ended subscription queues and sends free to consented parents" do
    account = accounts(:subscribed)
    parent = account.owner
    parent.grant_marketing_consent(source: "settings")
    clear_enqueued_jobs

    subscription = pay_subscriptions(:subscribed)
    subscription.update!(status: "canceled", ends_at: 1.day.ago)

    assert_enqueued_with(job: LoopsContactSyncJob, args: [parent.id, "plan_status"])
    assert_plan_status_updates([parent], "free")
  end

  test "complimentary changes queue current statuses and skip parents without consent" do
    account = accounts(:company)
    consenting_parent = account.owner
    other_parent = users(:two)
    consenting_parent.grant_marketing_consent(source: "settings")
    clear_enqueued_jobs

    account.update!(complimentary_premium: true, complimentary_premium_note: "Temporary Premium access")

    assert_enqueued_with(job: LoopsContactSyncJob, args: [consenting_parent.id, "plan_status"])
    assert_equal [[consenting_parent.id, "plan_status"]], enqueued_jobs.filter_map { |job| job[:args] if job[:job] == LoopsContactSyncJob }
    assert_plan_status_updates([consenting_parent], "complimentary")

    clear_enqueued_jobs
    account.update!(complimentary_premium: false, complimentary_premium_note: nil)
    assert_enqueued_with(job: LoopsContactSyncJob, args: [consenting_parent.id, "plan_status"])
    assert_plan_status_updates([consenting_parent], "free")

    paid_account = accounts(:subscribed)
    paid_parent = paid_account.owner
    paid_parent.grant_marketing_consent(source: "settings")
    clear_enqueued_jobs
    paid_account.update!(complimentary_premium: true, complimentary_premium_note: "Temporary Premium access")
    paid_account.update!(complimentary_premium: false, complimentary_premium_note: nil)

    assert_plan_status_updates([paid_parent, paid_parent], "premium")
    assert_equal other_parent, account.parents.find(other_parent.id)
  end

  test "invitation acceptance queues the moving consented parent twice and sends the destination family's status" do
    moving_parent = users(:noaccount)
    destination = accounts(:complimentary)
    moving_parent.grant_marketing_consent(source: "settings")
    invitation = AccountInvitation.create!(account: destination, invited_by: destination.owner, name: moving_parent.name, email: moving_parent.email)
    clear_enqueued_jobs

    result = FamilyInvitationAcceptance.new(invitation:, user: moving_parent).call

    assert_predicate result, :success?
    assert_equal destination, moving_parent.reload.family
    assert_equal [[moving_parent.id, "plan_status"], [moving_parent.id, "plan_status"]], plan_status_job_arguments
    assert_plan_status_updates([moving_parent, moving_parent], "complimentary")
  end

  test "parent removal queues only the moving consented parent and sends the new family's status" do
    family = accounts(:company)
    moving_parent = users(:two)
    remaining_parent = family.owner
    moving_parent.grant_marketing_consent(source: "settings")
    clear_enqueued_jobs
    sign_in remaining_parent

    delete account_account_user_path(family, account_users(:company_regular_user))

    assert_redirected_to family
    assert_equal [remaining_parent], family.reload.users.to_a
    assert_equal moving_parent, moving_parent.reload.family.owner
    assert_equal [[moving_parent.id, "plan_status"], [moving_parent.id, "plan_status"]], plan_status_job_arguments
    assert_plan_status_updates([moving_parent, moving_parent], "free")
  end

  test "membership moves do not queue plan status for a parent without marketing consent" do
    moving_parent = users(:noaccount)
    destination = accounts(:invited)
    invitation = AccountInvitation.create!(account: destination, invited_by: destination.owner, name: moving_parent.name, email: moving_parent.email)
    clear_enqueued_jobs

    result = FamilyInvitationAcceptance.new(invitation:, user: moving_parent).call

    assert_predicate result, :success?
    assert_empty plan_status_job_arguments
  end

  private

  def consent_all_parents(account)
    account.parents.each { |parent| parent.grant_marketing_consent(source: "settings") }
  end

  def plan_status_job_arguments
    enqueued_jobs.filter_map { |job| job[:args] if job[:job] == LoopsContactSyncJob && job[:args].second == "plan_status" }
  end

  def assert_plan_status_updates(parents, status)
    client = RecordingClient.new
    synchronizer = LoopsContactSynchronizer.new(
      config: Rails.application.config_for(:loops, env: "production"),
      environment: ActiveSupport::StringInquirer.new("production"),
      client:
    )

    LoopsContactSynchronizer.stub(:new, synchronizer) do
      perform_enqueued_jobs(only: LoopsContactSyncJob)
    end

    expected_updates = parents.map { |parent| {email: parent.email, user_id: parent.id.to_s, contact_properties: {planStatus: status}} }.sort_by { |attributes| attributes[:user_id] }
    assert_equal expected_updates, client.updates.sort_by { |attributes| attributes[:user_id] }
  end
end
