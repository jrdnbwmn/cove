class Dev::ClocksController < ApplicationController
  include ReferrerPath

  prepend_before_action :ensure_development_environment
  before_action :authenticate_user!

  def show
  end

  def update
    DevClock.set(Date.iso8601(params[:date].to_s))
    redirect_to dev_clock_path, status: :see_other
  rescue Date::Error
    @error = "Choose a valid date."
    render :show, status: :unprocessable_content
  end

  def destroy
    DevClock.clear
    referrer = same_origin_referrer
    # AIDEV-NOTE: Keep the verified origin: a bare path beginning // is interpreted as an external URL.
    redirect_to(referrer ? referrer.to_s : dev_clock_path, status: :see_other)
  end

  private

  def ensure_development_environment
    head :not_found unless Rails.env.development?
  end
end
