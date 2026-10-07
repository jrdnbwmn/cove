class CoursesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_course, only: %i[edit update delete destroy]

  def index
    @courses = Current.account.courses.ordered.includes(:enrollments)
    @learners_by_id = Current.account.learners.active.ordered.index_by(&:id)
    # AIDEV-NOTE: Cards resolve enrollment IDs through the active-learner hash
    # so archived learners stay hidden without an N+1 query. Reusing
    # Current.account also shares its memoized Free-limit check per request.
    @read_only_ids = @learners_by_id.values.filter { |learner| !learner.editable? }.map(&:id)
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
