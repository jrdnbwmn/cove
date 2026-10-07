class CoursesController < ApplicationController
  include CourseListReturn

  before_action :authenticate_user!
  before_action :set_course, only: %i[edit update delete destroy]

  def index
    @courses = Current.account.courses.active.ordered.includes(:enrollments)
    # AIDEV-NOTE: Cards resolve enrollment IDs through the active-learner hash
    # so archived learners stay hidden without an N+1 query. Loading through
    # Current.account shares its memoized Free-limit check, so learner.editable?
    # in the cards costs no extra queries.
    @learners_by_id = Current.account.learners.active.index_by(&:id)
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
    assign_course_attributes(@course)

    if @course.save
      redirect_to course_list_return_path, status: :see_other, notice: t("courses.notices.updated")
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

  def set_course
    @course = Current.account.courses.find(params[:id])
  end

  def assign_course_attributes(course)
    attributes = course_params
    course.assign_attributes(attributes.except(:learner_ids))
    course.assign_learners(attributes[:learner_ids])
  end

  def render_duplicate_enrollment(template)
    @course.errors.add(:learners, :duplicate)
    render template, status: :unprocessable_content
  end

  def course_params
    params.expect(course: [:name, :subject, learner_ids: []])
  end
end
