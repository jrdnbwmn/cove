module LearnerReturn
  extend ActiveSupport::Concern
  include ReferrerPath

  private

  # AIDEV-NOTE: Modal requests keep the containing page's Referer. Only the
  # scoped learner's exact page on this origin qualifies; build the URL locally.
  def learner_return_path
    (same_origin_referrer&.path == learner_path(@learner)) ? learner_path(@learner) : learners_path
  end
end
