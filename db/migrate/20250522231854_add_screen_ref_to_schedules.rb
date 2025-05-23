class AddScreenRefToSchedules < ActiveRecord::Migration[7.1]
  def change
    add_reference :schedules, :screen, null: true, foreign_key: true
  end
end
