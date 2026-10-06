class Learners::ArchivesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_learner

  def create
    @learner.archive!
    redirect_to learners_path, status: :see_other, notice: t("learners.notices.archived", name: @learner.name)
  end

  def destroy
    @learner.restore!
    redirect_to learners_path, status: :see_other, notice: t("learners.notices.restored", name: @learner.name)
  rescue ActiveRecord::RecordInvalid => e
    # AIDEV-NOTE: The model owns the limit copy, so the alert reuses its message.
    redirect_to learners_path, status: :see_other, alert: e.record.errors.full_messages.to_sentence
  end

  private

  # AIDEV-NOTE: Scoped through the current family so another family's learner is a 404.
  def set_learner
    @learner = Current.account.learners.find(params[:learner_id])
  end
end
