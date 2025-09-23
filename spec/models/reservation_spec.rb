require 'rails_helper'

RSpec.describe Reservation, type: :model do
  describe 'validations' do
    let(:booking_date) { Date.new(2025, 9, 22) }

    it 'prevents double booking for the same schedule, sheet, screen, and date' do
      reservation = create(:reservation, date: booking_date)
      duplicate = build(:reservation,
                        schedule: reservation.schedule,
                        sheet: reservation.sheet,
                        screen: reservation.screen,
                        date: booking_date)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:sheet_id]).to include('はすでに予約されています')
    end

    it 'allows the same seat layout to be booked on a different theater screen' do
      first_reservation = create(:reservation, date: booking_date)

      other_screen = create(:screen)
      other_sheet = create(:sheet, screen: other_screen, row: first_reservation.sheet.row, column: first_reservation.sheet.column)
      other_schedule = create(:schedule, screen: other_screen)

      another_reservation = build(:reservation,
                                  schedule: other_schedule,
                                  screen: other_screen,
                                  sheet: other_sheet,
                                  date: booking_date)

      expect(another_reservation).to be_valid
    end
  end
end
