class BackfillSchoolYears < ActiveRecord::Migration[8.1]
  def up
    Account.active.where.missing(:school_years).find_each do |account|
      SchoolYear.create_default_for!(account)
    end
  end

  def down
    # AIDEV-NOTE: Retain provisioned years on rollback; parents may already have edited them.
  end
end
