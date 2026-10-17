class SchoolYears::EndDatePreviewsController < ApplicationController
  before_action :authenticate_user!

  # AIDEV-NOTE: Read-only. The Edit year form asks this whenever Ends changes so the counting
  # rule lives only on the server.
  def show
    school_year = current_account.school_year || raise(ActiveRecord::RecordNotFound)
    date = parsed_date
    @added_days = school_year.added_days_if_ended_on(date) if date && date > school_year.ends_on && date <= school_year.starts_on.advance(years: 1)
  end

  private

  def parsed_date
    Date.iso8601(params[:ends_on].to_s)
  rescue Date::Error
    nil
  end
end
