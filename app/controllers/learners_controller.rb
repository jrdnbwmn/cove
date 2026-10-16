class LearnersController < ApplicationController
  include LearnerReturn

  before_action :authenticate_user!
  before_action :set_learner, only: %i[show edit update delete destroy]
  before_action :redirect_archived_learner, only: %i[edit update]

  def index
    @learners = Current.account.learners.active.ordered.load
    @archived_learners = Current.account.learners.archived.ordered
    @archived_count = @archived_learners.size
    @show_archived = params[:archived] == "1" && @archived_count.positive?
  end

  def show
    @current_courses = @learner.courses.active.ordered unless @learner.archived?
    @switchable_learners = Current.account.learners.active.ordered.where.not(id: @learner.id)
  end

  def new
    @learner = Current.account.learners.new(color: Learner.next_color_for(Current.account))
  end

  def create
    @learner = Current.account.learners.new(learner_params)

    if @learner.save
      redirect_to learners_path, status: :see_other, notice: t("learners.notices.created", name: @learner.name)
    else
      render :new, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render_duplicate_name(:new)
  end

  def edit
  end

  def update
    if @learner.update(learner_params)
      redirect_to learner_return_path, status: :see_other, notice: t("learners.notices.updated")
    else
      render :edit, status: :unprocessable_content
    end
  rescue ActiveRecord::RecordNotUnique
    render_duplicate_name(:edit)
  end

  def delete
  end

  def destroy
    @learner.destroy!
    redirect_to learners_path, status: :see_other, notice: t("learners.notices.deleted", name: @learner.name)
  end

  private

  # AIDEV-NOTE: Every lookup goes through the current family so another family's
  # learner id is a 404. There is no Pundit policy: both parents are admins.
  def set_learner
    @learner = Current.account.learners.find(params[:id])
  end

  def redirect_archived_learner
    redirect_to learner_return_path if @learner.archived?
  end

  def learner_params
    params.expect(learner: [:name, :grade_level, :color])
  end

  # Two parents saving the same name at once get past the model check and hit the unique index.
  def render_duplicate_name(template)
    @learner.errors.add(:name, :taken_active, name: @learner.name)
    render template, status: :unprocessable_content
  end
end
