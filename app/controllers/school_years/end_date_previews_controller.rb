class SchoolYears::EndDatePreviewsController < ApplicationController
  include CurrentSchoolYear

  # AIDEV-NOTE: Read-only. The Edit year form asks this whenever Ends changes so the counting
  # rule lives only on the server.
  def show
    date = parsed_date
    @added_days = @school_year.added_days_if_ended_on(date) if date && date > @school_year.ends_on
  end

  private

  def parsed_date
    Date.iso8601(params[:ends_on].to_s)
  rescue Date::Error
    nil
  end
end
