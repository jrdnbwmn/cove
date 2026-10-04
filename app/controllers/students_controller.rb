class StudentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_student, only: %i[show edit update delete destroy]
  before_action :redirect_archived_student, only: %i[edit update]
  before_action :redirect_read_only_student, only: %i[edit update]
  before_action :redirect_editable_student, only: :show

  def index
    @students = Current.account.students.active.ordered.load
    @archived_students = Current.account.students.archived.ordered
    @archived_count = @archived_students.size
    @show_archived = params[:archived] == "1" && @archived_count.positive?
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

  def show
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

  def delete
  end

  def destroy
    @student.destroy!
    redirect_to students_path, status: :see_other, notice: t("students.notices.deleted", name: @student.name)
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

  # AIDEV-NOTE: The View modal explains why a student is read-only, so a stale link to an editable one goes to Edit.
  def redirect_editable_student
    redirect_to edit_student_path(@student) if @student.editable?
  end

  def redirect_read_only_student
    return if @student.editable?

    redirect_to students_path, alert: t("students.notices.read_only", name: @student.name)
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
