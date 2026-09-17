class EnforceFamilyAccountConstraints < ActiveRecord::Migration[8.1]
  def up
    add_column :accounts, :archived_at, :datetime
    add_index :accounts, :archived_at

    execute <<~SQL
      UPDATE accounts
      SET personal = FALSE
      WHERE personal IS DISTINCT FROM FALSE
    SQL
    change_column_null :accounts, :personal, false, false
    add_check_constraint :accounts, "personal = FALSE", name: "accounts_personal_must_be_false"

    # AIDEV-NOTE: This pre-production cleanup irreversibly removes duplicate
    # memberships so a user belongs to one family. Rollback restores schema,
    # not the deleted memberships or prior personal-account state.
    execute <<~SQL
      DELETE FROM account_users
      WHERE id IN (
        SELECT id
        FROM (
          SELECT account_users.id,
            ROW_NUMBER() OVER (
              PARTITION BY account_users.user_id
              ORDER BY
                CASE WHEN accounts.owner_id = account_users.user_id THEN 0 ELSE 1 END,
                accounts.created_at ASC,
                account_users.created_at ASC,
                account_users.id ASC
            ) AS membership_rank
          FROM account_users
          INNER JOIN accounts ON accounts.id = account_users.account_id
        ) ranked_memberships
        WHERE membership_rank > 1
      )
    SQL

    execute <<~SQL
      UPDATE accounts
      SET archived_at = CURRENT_TIMESTAMP
      WHERE archived_at IS NULL
        AND NOT EXISTS (
          SELECT 1
          FROM account_users
          WHERE account_users.account_id = accounts.id
        )
    SQL

    execute <<~SQL
      UPDATE accounts
      SET account_users_count = (
        SELECT COUNT(*)
        FROM account_users
        WHERE account_users.account_id = accounts.id
      )
    SQL

    add_index :account_users, :user_id, unique: true
  end

  def down
    remove_index :account_users, :user_id
    remove_check_constraint :accounts, name: "accounts_personal_must_be_false"
    change_column_null :accounts, :personal, true
    remove_index :accounts, :archived_at
    remove_column :accounts, :archived_at
  end
end
