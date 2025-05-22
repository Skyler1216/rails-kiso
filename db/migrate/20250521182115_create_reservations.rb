class CreateReservations < ActiveRecord::Migration[7.1]
  def change
    create_table :reservations do |t|
      t.date :date
      t.references :schedule, null: false, foreign_key: true
      t.references :sheet, null: false, foreign_key: true
      t.string :name
      t.string :email

      t.timestamps
    end
    
    add_index :reservations, [:date, :schedule_id, :sheet_id], unique: true, name: 'index_reservations_on_date_schedule_sheet'

  end
end
