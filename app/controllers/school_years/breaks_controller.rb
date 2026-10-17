class SchoolYears::BreaksController < ApplicationController
  before_action :authenticate_user!
  before_action :set_school_year
  before_action :set_time_off, only: %i[edit update destroy]

  def new
    @time_off = @school_year.breaks.new(starts_on: current_account.today, ends_on: current_account.today)
    head :forbidden if @school_year.ended?
  end

  def create
    return restore if params[:restore].present?

    @time_off = @school_year.breaks.new(time_off_params)
    if save_time_off
      redirect_to planner_school_year_path, status: :see_other, notice: "#{@time_off.name} added."
    else
      render_invalid
    end
  end

  def edit
    @school_year.ended? ? head(:forbidden) : render(:new)
  end

  def update
    @time_off.assign_attributes(time_off_params)
    if save_time_off
      redirect_to planner_school_year_path, status: :see_other, notice: "Saved."
    else
      render_invalid
    end
  end

  def destroy
    token = @time_off.restore_token
    if @time_off.destroy
      toast = {title: "Time off removed", action: {label: "Undo", url: planner_school_year_breaks_path, params: {restore: token}}}
      redirect_to planner_school_year_path, status: :see_other, notice: toast
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def restore
    attributes = Break.restore_attributes(params[:restore], @school_year)
    restored = @school_year.breaks.new(attributes) if attributes
    if restored&.save
      redirect_to planner_school_year_path, status: :see_other, notice: "#{restored.name} restored."
    else
      redirect_to planner_school_year_path, status: :see_other, flash: {restore_error: restore_error_message(restored)}
    end
  end

  def restore_error_message(entry)
    return "We couldn't restore that time off." unless entry

    reason = if entry.overlaps.exists?
      "It overlaps #{entry.overlaps.map(&:name).to_sentence}."
    elsif entry.starts_on < current_account.today
      "It would start in the past."
    else
      entry.errors.full_messages.to_sentence
    end
    "We couldn't restore #{entry.name}. #{reason}"
  end

  # AIDEV-NOTE: Replace is an explicit flag only; the conflicts to delete are always re-queried by the service, never taken from params.
  def save_time_off
    return @time_off.save unless params.dig(:break, :replace) == "1"

    ReplaceTimeOff.new(time_off: @time_off).call.success?
  end

  def render_invalid
    @conflicts = @time_off.overlaps.to_a
    render :new, status: :unprocessable_content
  end

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
