class BackfillSchoolYears < ActiveRecord::Migration[8.1]
  def up
    # AIDEV-NOTE: Uses the app models on purpose; copying the default-year rules here would let two versions drift.
    # backfill_school_years_test.rb covers it, so update that test if Defaults changes.
    Account.active.where.missing(:school_years).find_each do |account|
      SchoolYear.create_default_for!(account)
    end
  end

  def down
    # AIDEV-NOTE: Retain provisioned years on rollback; parents may already have edited them.
  end
end
