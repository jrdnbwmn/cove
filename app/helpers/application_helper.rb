module ApplicationHelper
  # AIDEV-NOTE: Single source of truth for mapping a flash key (:notice, :success, :alert, :error)
  # or a toast icon_name (:notice, :success, :alert, :default) to an AlertComponent/toast variant.
  FLASH_VARIANTS = {notice: :info, success: :success, alert: :error, error: :error, default: :default}.freeze

  def flash_variant(key)
    FLASH_VARIANTS.fetch(key.to_sym, :default)
  end

  def friendly_date(date)
    date = date.in_time_zone.to_date

    case date
    when Date.current
      t("friendly_dates.today")
    when Date.tomorrow
      t("friendly_dates.tomorrow")
    when Date.yesterday
      t("friendly_dates.yesterday")
    when Date.current.beginning_of_year..Date.current.end_of_year
      l(date, format: :friendly_short)
    else
      l(date, format: :friendly)
    end
  end

  def friendly_time(time)
    l(time.in_time_zone, format: :friendly)
  end

  def friendly_date_range(start_date, end_date)
    start_date = start_date.in_time_zone.to_date
    end_date = end_date.in_time_zone.to_date

    return friendly_date(start_date) if start_date == end_date

    if start_date.year != end_date.year
      "#{l(start_date, format: :friendly_short)} #{start_date.year}–#{l(end_date, format: :friendly_short)} #{end_date.year}"
    elsif start_date.month == end_date.month
      "#{start_date.day}–#{end_date.day} #{friendly_month(end_date)}#{friendly_year(end_date)}"
    else
      "#{l(start_date, format: :friendly_short)}–#{l(end_date, format: :friendly_short)}#{friendly_year(end_date)}"
    end
  end

  # AIDEV-NOTE: Sidebar/settings-tab highlighting. Matching is exact-path-or-descendant
  # (path + "/" as a real segment boundary), never a raw string prefix — e.g. the Family
  # tab must match "/accounts/:id" and its descendants without also matching the unrelated
  # top-level "/account_invitations/:id/edit" acceptance page, which merely shares the
  # "/account" characters.
  def dashboard_nav_active?
    current_page_or_descendant?(user_root_path)
  end

  def schedules_nav_active?
    current_page_or_descendant?(schedules_path)
  end

  def classes_nav_active?
    current_page_or_descendant?(courses_path)
  end

  def learners_nav_active?
    current_page_or_descendant?(learners_path)
  end

  def support_nav_active?
    current_page_or_descendant?(support_path)
  end

  def settings_nav_active?
    profile_tab_active? || security_tab_active? || connected_accounts_tab_active? ||
      billing_tab_active? || family_tab_active? || api_tokens_tab_active? || referrals_tab_active?
  end

  def profile_tab_active?
    current_page_or_descendant?(edit_user_registration_path)
  end

  def security_tab_active?
    current_page_or_descendant?(edit_account_password_path) || current_page_or_descendant?(user_two_factor_path)
  end

  def connected_accounts_tab_active?
    current_page_or_descendant?(user_connected_accounts_path)
  end

  def billing_tab_active?
    current_page_or_descendant?(billing_path)
  end

  def family_tab_active?
    Current.account.present? && current_page_or_descendant?(account_path(Current.account))
  end

  def api_tokens_tab_active?
    current_page_or_descendant?(api_tokens_path)
  end

  def referrals_tab_active?
    defined?(Refer) && current_page_or_descendant?(referrals_path)
  end

  private

  def friendly_month(date)
    l(date, format: :friendly_short).delete_prefix("#{date.day} ")
  end

  def friendly_year(date)
    " #{date.year}" unless date.year == Date.current.year
  end

  def current_page_or_descendant?(path)
    request.path == path || request.path.start_with?("#{path}/")
  end
end
