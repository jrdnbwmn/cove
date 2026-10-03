class Students::ArchivesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_student

  def create
    @student.archive!
    redirect_to students_path, status: :see_other, notice: t("students.notices.archived", name: @student.name)
  end

  def destroy
    @student.restore!
    redirect_to students_path, status: :see_other, notice: t("students.notices.restored", name: @student.name)
  rescue ActiveRecord::RecordInvalid => e
    # AIDEV-NOTE: The model owns the limit copy, so the alert reuses its message.
    redirect_to students_path, status: :see_other, alert: e.record.errors.full_messages.to_sentence
  end

  private

  # AIDEV-NOTE: Scoped through the current family so another family's student is a 404.
  def set_student
    @student = Current.account.students.find(params[:student_id])
  end
end
