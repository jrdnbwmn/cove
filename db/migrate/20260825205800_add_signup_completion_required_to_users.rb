class AddSignupCompletionRequiredToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :signup_completion_required, :boolean, default: false, null: false
  end
end
