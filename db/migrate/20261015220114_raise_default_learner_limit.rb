class RaiseDefaultLearnerLimit < ActiveRecord::Migration[8.1]
  def up
    change_column_default :accounts, :learner_limit, from: 10, to: 15

    # AIDEV-NOTE: Use SQL so this backfill does not depend on the runtime Account model.
    execute "UPDATE accounts SET learner_limit = 15 WHERE learner_limit < 15"
  end

  def down
    # AIDEV-NOTE: Raised family caps stay raised when restoring the old default.
    change_column_default :accounts, :learner_limit, from: 15, to: 10
  end
end
