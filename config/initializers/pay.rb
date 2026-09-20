Pay.setup do |config|
  config.application_name = Jumpstart.config.application_name
  config.business_name = Jumpstart.config.business_name
  config.business_address = Jumpstart.config.business_address
  config.support_email = Jumpstart.config.support_email

  config.routes_path = "/"

  config.mail_to = -> {
    pay_customer = params[:pay_customer]
    account = pay_customer.owner

    recipients = account ? account.parents.map { |parent| ActionMailer::Base.email_address_with_name(parent.email, pay_customer.customer_name) } : []
    recipients << account.billing_email if account&.billing_email?
    recipients.uniq
  }
end

# Use Inter font for full UTF-8 support in PDFs
# https://github.com/rsms/inter
Receipts.default_font = {
  bold: Jumpstart::Engine.root.join("app/assets/fonts/Inter-Bold.ttf"),
  normal: Jumpstart::Engine.root.join("app/assets/fonts/Inter-Regular.ttf")
}

ActiveSupport.on_load :pay_subscription do
  has_prefix_id :sub
  delegate :currency, to: :plan
  # AIDEV-NOTE: Separate method names on purpose — Rails de-duplicates callbacks
  # registered with the same method, so sharing one would drop the create hook.
  after_commit :sync_owner_plan_status_after_create, on: :create
  after_commit :sync_owner_plan_status_after_update, on: :update, if: -> { saved_change_to_status? || saved_change_to_ends_at? }

  def plan
    @plan ||= Plan.where("#{customer.processor}_id": processor_plan).first
  end

  def amount
    (quantity == 0) ? plan.amount : plan.amount * quantity
  end

  def sync_owner_plan_status
    customer.owner&.sync_plan_status_to_marketing_subscribed_parents
  end

  def sync_owner_plan_status_after_create
    sync_owner_plan_status
  end

  def sync_owner_plan_status_after_update
    sync_owner_plan_status
  end
end

ActiveSupport.on_load :pay_charge do
  has_prefix_id :ch
  after_create :complete_referral, if: -> { defined?(Refer) }

  # Mark the account owner's referral complete on the first successful payment
  def complete_referral
    customer.owner.owner.referral&.complete!
  end
end
