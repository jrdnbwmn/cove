class CoursesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course, only: %i[edit update delete destroy]

  def index
    @courses = Current.account.courses.ordered.includes(:enrollments)
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
      redirect_to courses_path, status: :see_other, notice: t("courses.notices.created")
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render :new, status: :unprocessable_content
  end

  def edit
  end

  def update
    assign_course_attributes(@course)

    if @course.save
      redirect_to courses_path, status: :see_other, notice: t("courses.notices.updated")
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render :edit, status: :unprocessable_content
  end

  def delete
  end

  def destroy
    @course.destroy!
    redirect_to courses_path, status: :see_other, notice: t("courses.notices.deleted")
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

  def course_params
    params.expect(course: [:name, :subject, learner_ids: []])
  end
end
