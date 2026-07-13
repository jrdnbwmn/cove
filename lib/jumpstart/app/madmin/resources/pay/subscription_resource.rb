class Pay::SubscriptionResource < Madmin::Resource
  menu parent: "Payments", position: 2

  scope :active
  scope :on_trial
  scope :past_due
  scope :unpaid
  scope :canceled

  # Attributes
  attribute :id, form: false
  attribute :name
  attribute :processor_id, index: true
  attribute :processor_plan, index: true
  attribute :quantity, index: true
  attribute :trial_ends_at
  attribute :ends_at, index: true
  attribute :created_at, form: false
  attribute :updated_at, form: false
  attribute :status
  attribute :application_fee_percent
  attribute :metadata
  attribute :current_period_start
  attribute :current_period_end
  attribute :metered
  attribute :pause_behavior
  attribute :pause_starts_at
  attribute :pause_resumes_at
  attribute :stripe_account
  attribute :type

  # Associations
  attribute :customer
  attribute :payment_method
  attribute :charges

  # Uncomment this to customize the display name of records in the admin area.
  # def self.display_name(record)
  #   record.name
  # end

  # Uncomment this to customize the default sort column and direction.
  # def self.default_sort_column
  #   "created_at"
  # end
  #
  # def self.default_sort_direction
  #   "desc"
  # end

  member_action do
    case @record.type
    when "Pay::Stripe::Subscription"
      link_to "View on Stripe", ["https://dashboard.stripe.com", ("/test" if Pay::Stripe.public_key&.start_with?("pk_test")), "/subscriptions/#{@record.processor_id}"].join, class: "btn btn-secondary", target: :_blank
    end
  end
end
