class Courses::CompletionsController < ApplicationController
  include CourseListReturn

  before_action :authenticate_user!
  before_action :set_course

  def create
    if @course.complete!
      redirect_to course_list_return_path, status: :see_other, notice: t("courses.notices.completed", name: @course.name)
    else
      redirect_to course_list_return_path, status: :see_other, alert: @course.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @course.reopen!
      redirect_to course_list_return_path, status: :see_other, notice: t("courses.notices.reopened", name: @course.name)
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
