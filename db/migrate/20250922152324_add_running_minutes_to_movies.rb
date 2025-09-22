class AddRunningMinutesToMovies < ActiveRecord::Migration[7.1]
  def change
    add_column :movies, :running_minutes, :integer, comment: '上映時間（分）'
  end
end
