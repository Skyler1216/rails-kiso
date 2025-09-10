class RemoveScreenIdFromSchedules < ActiveRecord::Migration[7.1]
  def change
    remove_column :schedules, :screen_id, :integer
  end
end
