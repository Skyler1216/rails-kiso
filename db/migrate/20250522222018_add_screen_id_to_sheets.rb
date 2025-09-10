class AddScreenIdToSheets < ActiveRecord::Migration[7.1]
  def change
    add_column :sheets, :screen_id, :integer
  end
end
