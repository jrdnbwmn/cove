class SchoolYears::BreaksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_school_year
  before_action :set_time_off, only: %i[edit update destroy]

  def new
    @time_off = @school_year.breaks.new(starts_on: current_account.today, ends_on: current_account.today)
    head :forbidden if @school_year.ended?
  end

  def create
    @time_off = @school_year.breaks.new(time_off_params)
    if @time_off.save
      redirect_to planner_school_year_path, status: :see_other, notice: "#{@time_off.name} added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @school_year.ended? ? head(:forbidden) : render(:new)
  end

  def update
    if @time_off.update(time_off_params)
      redirect_to planner_school_year_path, status: :see_other, notice: "Saved."
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    if @time_off.destroy
      redirect_to planner_school_year_path, status: :see_other, notice: "Time off removed"
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def set_school_year
    @school_year = current_account.school_year || raise(ActiveRecord::RecordNotFound)
  end

  def set_time_off
    @time_off = @school_year.breaks.find(params[:id])
  end

  def time_off_params
    params.expect(break: %i[name starts_on ends_on])
  end
end
