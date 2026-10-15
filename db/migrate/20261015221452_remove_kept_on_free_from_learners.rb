class RemoveKeptOnFreeFromLearners < ActiveRecord::Migration[8.1]
  def change
    remove_column :learners, :kept_on_free, :boolean, default: false, null: false
  end
end
