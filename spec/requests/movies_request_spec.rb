require 'rails_helper'

RSpec.describe 'Movies', type: :request do
  describe 'GET /movies' do
    let!(:movie1) { create(:movie, name: '映画1', is_showing: 1) }
    let!(:movie2) { create(:movie, name: '映画2', is_showing: 0) }

    it '映画一覧ページが表示されること' do
      get movies_path
      expect(response).to have_http_status(200)
      expect(response.body).to include(movie1.name)
      expect(response.body).to include(movie2.name)
    end

    it 'is_showingパラメータで絞り込みできること' do
      get movies_path, params: { is_showing: '1' }
      expect(response).to have_http_status(200)
      expect(response.body).to include(movie1.name)
      expect(response.body).not_to include(movie2.name)
    end

    it 'keywordパラメータで検索できること' do
      get movies_path, params: { keyword: '映画1' }
      expect(response).to have_http_status(200)
      expect(response.body).to include(movie1.name)
      expect(response.body).not_to include(movie2.name)
    end
  end

  describe 'GET /movies/:id' do
    let!(:theater) { create(:theater) }
    let!(:screen) { create(:screen, theater: theater) }
    let!(:movie) { create(:movie) }
    let!(:schedule) { create(:schedule, movie: movie, screen: screen) }

    it '映画詳細ページが表示されること' do
      get movie_path(movie)
      expect(response).to have_http_status(200)
      expect(response.body).to include(movie.name)
    end

    it 'theater_idパラメータで劇場を指定できること' do
      get movie_path(movie), params: { theater_id: theater.id }
      expect(response).to have_http_status(200)
    end

    it 'dateパラメータで日付を指定できること' do
      get movie_path(movie), params: { 
        theater_id: theater.id, 
        date: schedule.start_time.to_date.to_s 
      }
      expect(response).to have_http_status(200)
    end
  end

  describe 'GET /movies/:id/reservation' do
    let!(:theater) { create(:theater) }
    let!(:screen) { create(:screen, theater: theater) }
    let!(:movie) { create(:movie) }
    let!(:schedule) { create(:schedule, movie: movie, screen: screen) }

    it '予約ページが表示されること' do
      get reservation_movie_path(movie), params: {
        schedule_id: schedule.id,
        date: '2025-09-22',
        theater_id: theater.id
      }
      expect(response).to have_http_status(200)
    end

    it '必須パラメータが不足している場合はリダイレクトすること' do
      get reservation_movie_path(movie)
      expect(response).to have_http_status(302)
    end
  end

  describe 'GET /' do
    let!(:movie) { create(:movie) }

    it 'ルートページが映画一覧を表示すること' do
      get root_path
      expect(response).to have_http_status(200)
      expect(response.body).to include(movie.name)
    end
  end
end
