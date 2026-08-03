class MarketingPreferencesController < ApplicationController
  before_action :authenticate_user!

  def update
    case subscribed
    when "1"
      update_marketing_preference { current_user.grant_marketing_consent(source: "settings") }
    when "0"
      update_marketing_preference { current_user.withdraw_marketing_consent(reason: "user_app") }
    else
      redirect_to edit_user_registration_path, alert: t(".invalid")
    end
  end

  private

  def subscribed
    params.dig(:marketing_preference, :subscribed)
  end

  def update_marketing_preference
    if yield
      redirect_to edit_user_registration_path, notice: t(".updated")
    else
      redirect_to edit_user_registration_path, alert: t(".protected")
    end
  end
end
