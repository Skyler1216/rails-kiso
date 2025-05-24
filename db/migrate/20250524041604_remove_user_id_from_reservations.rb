class RemoveUserIdFromReservations < ActiveRecord::Migration[7.1]
  def change
    remove_column :reservations, :user_id, :integer
  end
end
