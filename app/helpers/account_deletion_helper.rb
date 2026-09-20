module AccountDeletionHelper
  def family_deletion_description(account)
    account.paid_premium? ? t("accounts.deletion.paid_description") : t("accounts.deletion.free_description")
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

  def cancellation_end_notice(subscription)
    if subscription.metered?
      t("billing.subscriptions.cancels.show.cancel_immediately")
    elsif subscription.current_period_end
      t("billing.subscriptions.cancels.show.active_until_no_refund", date: l(subscription.current_period_end.to_date, format: :long))
    else
      t("billing.subscriptions.cancels.show.active_until_no_refund_undated")
    end
  end
end
