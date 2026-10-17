class SchoolYearsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_school_year

  def show
  end

  def edit
    head :forbidden if @school_year.ended?
  end

  def update
    if @school_year.update(school_year_params)
      redirect_to planner_school_year_path, status: :see_other, notice: "Saved."
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_school_year
    @school_year = current_account.school_year || raise(ActiveRecord::RecordNotFound)
  end

  def school_year_params
    params.expect(school_year: [:starts_on, :ends_on, school_weekdays: []]).tap do |permitted|
      permitted[:school_weekdays] = permitted[:school_weekdays].reject(&:blank?) if permitted.key?(:school_weekdays)
    end
  end
end
