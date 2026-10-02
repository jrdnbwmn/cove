class EnforceMembershipColumnNulls < ActiveRecord::Migration[8.1]
  def up
    orphans = select_value("SELECT COUNT(*) FROM account_users WHERE account_id IS NULL OR user_id IS NULL").to_i
    if orphans.positive?
      raise "#{orphans} account_users row(s) have a NULL account_id or user_id. Review and fix or delete them by hand, then re-run this migration."
    end

    execute <<~SQL
      UPDATE accounts
      SET account_users_count = (
        SELECT COUNT(*)
        FROM account_users
        WHERE account_users.account_id = accounts.id
      )
      WHERE account_users_count IS NULL
    SQL

    change_column_null :accounts, :account_users_count, false, 0
    change_column_null :account_users, :account_id, false
    change_column_null :account_users, :user_id, false
  end

  def down
    change_column_null :account_users, :user_id, true
    change_column_null :account_users, :account_id, true
    change_column_null :accounts, :account_users_count, true
  end
end
