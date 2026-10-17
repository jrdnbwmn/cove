# Loads the signed-in family's school year for the Planner's School year controllers.
module CurrentSchoolYear
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    before_action :set_school_year
  end

  private

  def set_school_year
    @school_year = current_account.school_year!
  end

  def forbid_ended_year
    head :forbidden if @school_year.ended?
  end
end
