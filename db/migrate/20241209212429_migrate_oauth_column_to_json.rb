class MigrateOauthColumnToJson < ActiveRecord::Migration[8.0]
  def up
    case connection.adapter_name
    when "PostgreSQL"
      change_column :connected_accounts, :auth, :jsonb, using: "auth::jsonb"
    else
      change_column :connected_accounts, :auth, :json
    end
  end

  def down
    case connection.adapter_name
    when "PostgreSQL"
      change_column :connected_accounts, :auth, :text, using: "auth::text"
    else
      change_column :connected_accounts, :auth, :text
    end
  end
end
