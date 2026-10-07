class Courses::CompletionsController < ApplicationController
  include CourseListReturn

  before_action :authenticate_user!
  before_action :set_nested_course

  def create
    redirect_to_course_list @course.complete!, notice: t("courses.notices.completed", name: @course.name)
  end

  def destroy
    redirect_to_course_list @course.reopen!, notice: t("courses.notices.reopened", name: @course.name)
  end
end
