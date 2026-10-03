class StudentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_student, only: %i[edit update]
  before_action :redirect_archived_student, only: %i[edit update]

  def index
    @students = Current.account.students.active.ordered
  end

  def new
    @student = Current.account.students.new(color: Student.next_color_for(Current.account))
  end

  def create
    @student = Current.account.students.new(student_params)

    if @student.save
      redirect_to students_path, status: :see_other, notice: t("students.notices.created", name: @student.name)
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render_duplicate_name(:new)
  end

  def edit
  end

  def update
    if @student.update(student_params)
      redirect_to students_path, status: :see_other, notice: t("students.notices.updated")
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render_duplicate_name(:edit)
  end

  private

  # AIDEV-NOTE: Every lookup goes through the current family so another family's
  # student id is a 404. There is no Pundit policy: both parents are admins.
  def set_student
    @student = Current.account.students.find(params[:id])
  end

  def redirect_archived_student
    redirect_to students_path if @student.archived?
  end

  def student_params
    params.expect(student: [:name, :grade_level, :color])
  end

  # Two parents saving the same name at once get past the model check and hit the unique index.
  def render_duplicate_name(template)
    @student.errors.add(:name, :taken_active, name: @student.name)
    render template, status: :unprocessable_content
  end
end
