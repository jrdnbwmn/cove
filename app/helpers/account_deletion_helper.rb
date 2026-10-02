module AccountDeletionHelper
  def family_deletion_description(account)
    account.paid_premium? ? t("accounts.deletion.paid_description_html", link: refund_policy_link) : t("accounts.deletion.free_description")
  end

  # Returns the locale key prefix under devise.registrations.edit for the copy
  # that matches what deleting this user's login does to their Family.
  def login_deletion_copy_key(user)
    if !user.family&.owner?(user)
      "cancel_my_account_second_parent"
    elsif user.family.paid_premium?
      "cancel_my_account_paid"
    else
      "cancel_my_account"
    end
  end

  # AIDEV-NOTE: This mirrors the cancel_now! branches in Billing::Subscriptions::CancelsController#destroy; keep them in sync.
  def cancels_immediately?(subscription)
    subscription.metered? || subscription.past_due? || subscription.unpaid?
  end

  def cancellation_end_notice(subscription)
    if cancels_immediately?(subscription)
      t("billing.subscriptions.cancels.show.cancel_immediately")
    elsif subscription.current_period_end
      t("billing.subscriptions.cancels.show.active_until_no_refund_html", date: l(subscription.current_period_end.to_date, format: :long), link: refund_policy_link)
    else
      t("billing.subscriptions.cancels.show.active_until_no_refund_undated_html", link: refund_policy_link)
    end
  end

  private

  def refund_policy_link
    link_to t("billing.subscriptions.cancels.show.refund_policy"), refunds_path, class: "underline"
  end
end
