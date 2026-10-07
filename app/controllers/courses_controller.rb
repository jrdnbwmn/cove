class CoursesController < ApplicationController
  include CourseListReturn

  before_action :authenticate_user!
  before_action :set_course, only: %i[edit update delete destroy]

  helper_method :course_list_path

  def index
    @status = Course::STATUSES.include?(params[:status]) ? params[:status] : "active"
    @filter_learners = Current.account.learners.active.ordered.to_a
    # AIDEV-NOTE: Cards resolve enrollment IDs through the active-learner hash
    # so archived learners stay hidden without an N+1 query. Loading through
    # Current.account shares its memoized Free-limit check, so learner.editable?
    # in the cards costs no extra queries. The learner filter reuses the same lookup.
    @learners_by_id = @filter_learners.index_by(&:id)
    @learner_filter = @learners_by_id[string_param(:learner).to_i]
    @subject_filter = string_param(:subject)
    @subject_options = Course.subject_filter_options_for(Current.account)
    @family_has_courses = Current.account.courses.exists?

    filtered = filtered_courses
    # AIDEV-NOTE: Tab counts follow the learner and subject filters and use COUNT queries, not loaded records.
    @status_counts = Course::STATUSES.index_with { |status| filtered.public_send(status).count }
    @courses = filtered.public_send(@status).ordered.includes(:enrollments).load
  end

  def new
    @course = Current.account.courses.new
  end

  def create
    @course = Current.account.courses.new
    assign_course_attributes(@course)

    if @course.save
      redirect_to course_list_return_path, status: :see_other, notice: t("courses.notices.created")
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render_duplicate_enrollment(:new)
  end

  def edit
  end

  def update
    previous_status = @course.status
    assign_course_attributes(@course)
    @course.assign_status(course_params[:status])

    if @course.save
      redirect_to course_list_return_path, status: :see_other, notice: update_notice(previous_status)
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render_duplicate_enrollment(:edit)
  end

  def delete
  end

  def destroy
    @course.destroy!
    redirect_to course_list_return_path, status: :see_other, notice: t("courses.notices.deleted")
  end

  private

  # AIDEV-NOTE: Filter state lives only in the URL. The default Active tab is left out of it.
  def course_list_path(status: @status)
    courses_path({
      status: (status unless status == "active"),
      learner: @learner_filter&.id,
      subject: @subject_filter
    }.compact)
  end

  def filtered_courses
    courses = Current.account.courses
    courses = courses.taken_by(@learner_filter) if @learner_filter
    courses = courses.with_subject(@subject_filter) if @subject_filter
    courses
  end

  # Array or hash params (?learner[]=1) are treated as absent.
  def string_param(key)
    params[key].presence if params[key].is_a?(String)
  end

  def set_course
    @course = Current.account.courses.find(params[:id])
  end

  def assign_course_attributes(course)
    attributes = course_params
    # AIDEV-NOTE: Status is only applied on update (assign_status); a new class is always active.
    course.assign_attributes(attributes.except(:learner_ids, :status))
    course.assign_learners(attributes[:learner_ids])
  end

  # A status change made in the edit form gets the same toast as the card menu's action.
  def update_notice(previous_status)
    return t("courses.notices.updated") if @course.status == previous_status

    key = case @course.status
    when "completed" then :completed
    when "archived" then :archived
    else (previous_status == "archived") ? :restored : :reopened
    end
    t("courses.notices.#{key}", name: @course.name)
  end

  def render_duplicate_enrollment(template)
    @course.errors.add(:learners, :duplicate)
    render template, status: :unprocessable_content
  end

  def course_params
    params.expect(course: [:name, :subject, :status, learner_ids: []])
  end
end
