class Courses::ArchivesController < ApplicationController
  include CourseListReturn

  before_action :authenticate_user!
  before_action :set_course

  def create
    if @course.archive!
      redirect_to course_list_return_path, status: :see_other, notice: t("courses.notices.archived", name: @course.name)
    else
      redirect_to course_list_return_path, status: :see_other, alert: @course.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @course.restore!
      redirect_to course_list_return_path, status: :see_other, notice: t("courses.notices.restored", name: @course.name)
    else
      redirect_to course_list_return_path, status: :see_other, alert: @course.errors.full_messages.to_sentence
    end
  end

  private

  # AIDEV-NOTE: Scoped through the current family so another family's class is a 404.
  def set_course
    @course = Current.account.courses.find(params[:course_id])
  end
end
