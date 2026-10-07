class Courses::ArchivesController < ApplicationController
  include CourseListReturn

  before_action :authenticate_user!
  before_action :set_nested_course

  def create
    redirect_to_course_list @course.archive!, notice: t("courses.notices.archived", name: @course.name)
  end

  def destroy
    redirect_to_course_list @course.restore!, notice: t("courses.notices.restored", name: @course.name)
  end
end
