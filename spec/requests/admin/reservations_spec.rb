require 'rails_helper'

RSpec.describe 'Admin::Reservations', type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    sign_in admin
  end

  describe 'GET /admin/reservations' do
    it 'filters upcoming reservations by theater' do
      theater_a = create(:theater, name: 'Aシネマ')
      theater_b = create(:theater, name: 'Bシネマ')

      screen_a = create(:screen, theater: theater_a, name: 'スクリーンA')
      screen_b = create(:screen, theater: theater_b, name: 'スクリーンB')

      schedule_a = create(:schedule, screen: screen_a, start_time: 1.day.from_now.change(hour: 10))
      schedule_b = create(:schedule, screen: screen_b, start_time: 1.day.from_now.change(hour: 12))

      create(:reservation,
             schedule: schedule_a,
             screen: screen_a,
             sheet: create(:sheet, screen: screen_a),
             date: schedule_a.start_time.to_date,
             name: '予約A')

      create(:reservation,
             schedule: schedule_b,
             screen: screen_b,
             sheet: create(:sheet, screen: screen_b),
             date: schedule_b.start_time.to_date,
             name: '予約B')

      get admin_reservations_path(theater_id: theater_a.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Aシネマ')
      expect(response.body).to include('予約A')
      expect(response.body).not_to include('Bシネマ')
      expect(response.body).not_to include('予約B')
    end
  end
end
