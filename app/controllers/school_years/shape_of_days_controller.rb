class SchoolYears::ShapeOfDaysController < ApplicationController
  include CurrentSchoolYear
  include ReferrerPath

  before_action :forbid_ended_year

  def edit
  end

  def update
    if @school_year.update(params.expect(school_year: [:school_starts_at]))
      redirect_to return_path, status: :see_other, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def return_path
    path = same_origin_referrer&.path
    path.in?([planner_path, planner_school_year_path]) ? path : planner_school_year_path
  end
end
