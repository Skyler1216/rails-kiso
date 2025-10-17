require 'rails_helper'

RSpec.describe 'Admin::DailyMovieRankings', type: :request do
  let(:admin) { create(:user, :admin) }

  describe 'GET /admin/daily_movie_rankings' do
    before { sign_in admin }

    it '最新の集計日を表示できること' do
      create(:daily_movie_ranking, aggregated_on: Date.new(2025, 10, 12), rank_position: 1, reservation_count: 15, movie: create(:movie, name: '過去の映画'))
      latest_ranking = create(:daily_movie_ranking, aggregated_on: Date.new(2025, 10, 15), rank_position: 1, reservation_count: 30, movie: create(:movie, name: '最新の映画'))

      get admin_daily_movie_rankings_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('人気作品ランキング履歴')
      expect(response.body).to include('2025/10/15')
      expect(response.body).to include(latest_ranking.movie.name)
    end

    it '日付パラメータで指定した過去日を表示できること' do
      previous_ranking = create(:daily_movie_ranking, aggregated_on: Date.new(2025, 10, 12), rank_position: 2, reservation_count: 20, movie: create(:movie, name: '前回の映画'))
      create(:daily_movie_ranking, aggregated_on: Date.new(2025, 10, 15), rank_position: 1, reservation_count: 30)

      get admin_daily_movie_rankings_path, params: { date: '2025-10-12' }

      expect(response).to have_http_status(:success)
      expect(response.body).to include('2025/10/12')
      expect(response.body).to include(previous_ranking.movie.name)
    end
  end
end
