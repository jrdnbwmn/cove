class Students::KeptController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_unless_over_limit

  def edit
    @students = Current.account.students.active.ordered
  end

  def update
    if Current.account.keep_students_on_free(student_ids)
      names = Current.account.students.active.where(kept_on_free: true).ordered.pluck(:name).to_sentence
      redirect_to students_path, status: :see_other, notice: t("students.notices.kept", names: names)
    else
      @students = Current.account.students.active.ordered
      @selected_ids = student_ids
      render :edit, status: :unprocessable_content
    end
  end

  private

  # AIDEV-NOTE: Only plain strings count, so a forged hash or nested param is rejected as an invalid pick, not a 500.
  def student_ids
    Array(params[:student_ids]).grep(String)
  end

  def redirect_unless_over_limit
    redirect_to students_path unless Current.account.over_free_student_limit?
  end
end
