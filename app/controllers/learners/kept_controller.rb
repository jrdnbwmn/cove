class Learners::KeptController < ApplicationController
  before_action :authenticate_user!
  before_action :redirect_unless_over_limit

  def edit
    @learners = Current.account.learners.active.ordered
  end

  def update
    if Current.account.keep_learners_on_free(learner_ids)
      names = Current.account.learners.active.where(kept_on_free: true).ordered.pluck(:name).to_sentence
      redirect_to learners_path, status: :see_other, notice: t("learners.notices.kept", names: names)
    else
      @learners = Current.account.learners.active.ordered
      @selected_ids = learner_ids
      render :edit, status: :unprocessable_content
    end
  end

  private

  # AIDEV-NOTE: Only plain strings count, so a forged hash or nested param is rejected as an invalid pick, not a 500.
  def learner_ids
    Array(params[:learner_ids]).grep(String)
  end

  def redirect_unless_over_limit
    redirect_to learners_path unless Current.account.over_free_learner_limit?
  end
end
