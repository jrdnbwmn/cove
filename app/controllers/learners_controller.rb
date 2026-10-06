class LearnersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_learner, only: %i[show edit update delete destroy]
  before_action :redirect_archived_learner, only: %i[edit update]
  before_action :redirect_read_only_learner, only: %i[edit update]
  before_action :redirect_editable_learner, only: :show

  def index
    @learners = Current.account.learners.active.ordered.load
    @archived_learners = Current.account.learners.archived.ordered
    @archived_count = @archived_learners.size
    @show_archived = params[:archived] == "1" && @archived_count.positive?
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

  def show
  end

  def update
    if @learner.update(learner_params)
      redirect_to learners_path, status: :see_other, notice: t("learners.notices.updated")
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
    redirect_to learners_path if @learner.archived?
  end

  # AIDEV-NOTE: The View modal explains why a learner is read-only, so a stale link to an editable one goes to Edit.
  def redirect_editable_learner
    redirect_to edit_learner_path(@learner) if @learner.editable?
  end

  def redirect_read_only_learner
    return if @learner.editable?

    redirect_to learners_path, alert: t("learners.notices.read_only", name: @learner.name)
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
