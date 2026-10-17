class CoursesController < ApplicationController
  include CourseListReturn

  before_action :authenticate_user!
  before_action :set_course, only: %i[edit update delete destroy]

  helper_method :course_list_path, :course_list_params

  def index
    prepare_list_filters
    return redirect_to courses_path(course_list_params.merge(page: string_param(:page)).compact) if params[:q].is_a?(String) && @query.nil?

    filtered = filtered_courses
    filtered = filtered.search(@query) if @query
    # AIDEV-NOTE: Counts follow filters and search without loading every class.
    @status_counts = Course::STATUSES.index_with { |status| filtered.public_send(status).count }
    @show_search = @query.present? || @status_counts[@status] > 12
    paginate_courses(filtered)
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

  def prepare_list_filters
    @status = Course::STATUSES.include?(params[:status]) ? params[:status] : "active"
    @filter_learners = Current.account.learners.active.ordered.to_a
    # AIDEV-NOTE: Resolve enrollment IDs through active learners so archived learners
    # stay hidden without an N+1 query; the filter reuses the same lookup.
    @learners_by_id = @filter_learners.index_by(&:id)
    @learner_filter = @learners_by_id[string_param(:learner).to_i]
    @subject_filter = string_param(:subject)
    @query = string_param(:q)&.strip&.slice(0, 100)&.presence
    @subject_options = Course.subject_filter_options_for(Current.account)
    @family_has_courses = Current.account.courses.exists?
  end

  def paginate_courses(filtered)
    count = @status_counts[@status]
    requested_page = string_param(:page)
    page = requested_page&.match?(/\A[0-9]+\z/) ? [requested_page.to_i, 1].max : 1
    # AIDEV-NOTE: Pagy 43 returns empty overflow pages. A modal action may remove
    # the final row, so clamp locally with the tab count we already have.
    page = page.clamp(1, [(count / 12.0).ceil, 1].max)
    @pagy, @courses = pagy(filtered.public_send(@status).ordered.includes(:enrollments), limit: 12, count: count, page: page)
    @courses.load
  end

  # AIDEV-NOTE: Filter state lives only in the URL; tabs omit page to start over.
  def course_list_path(status: @status)
    courses_path(course_list_params(status: status))
  end

  def course_list_params(status: @status)
    {
      status: (status unless status == "active"),
      learner: @learner_filter&.id,
      subject: @subject_filter,
      q: @query
    }.compact
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

  # A status change made in the edit form gets the same toast as the row menu's action.
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
