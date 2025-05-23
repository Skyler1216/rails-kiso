class AddScreenRefToReservations < ActiveRecord::Migration[7.1]
  def change
    add_reference :reservations, :screen, null: false, foreign_key: true
  end
end
