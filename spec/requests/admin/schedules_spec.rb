require 'rails_helper'

RSpec.describe 'Admin::Schedules', type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe 'GET /admin/schedules' do
    it 'lists future schedules and filters by theater' do
      theater_a = create(:theater, name: '対象シネマA')
      theater_b = create(:theater, name: '対象シネマB')

      screen_a = create(:screen, theater: theater_a, name: 'Aスクリーン')
      screen_b = create(:screen, theater: theater_b, name: 'Bスクリーン')

      movie_a = create(:movie, name: '映画A')
      movie_b = create(:movie, name: '映画B')

      start_a = 1.day.from_now.change(hour: 10, min: 0)
      start_b = 1.day.from_now.change(hour: 14, min: 0)

      create(:schedule, movie: movie_a, screen: screen_a, start_time: start_a, end_time: start_a + 2.hours)
      create(:schedule, movie: movie_b, screen: screen_b, start_time: start_b, end_time: start_b + 2.hours)

      get admin_schedules_path(theater_id: theater_a.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('上映スケジュール')
      expect(response.body).to include('映画A')
      expect(response.body).to include('対象シネマA')
      expect(response.body).not_to include('映画B')
    end
  end
end
