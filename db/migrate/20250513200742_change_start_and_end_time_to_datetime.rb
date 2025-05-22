class ChangeStartAndEndTimeToDatetime < ActiveRecord::Migration[7.0]
  def change
    change_column :schedules, :start_time, :datetime
    change_column :schedules, :end_time, :datetime
  end
end
