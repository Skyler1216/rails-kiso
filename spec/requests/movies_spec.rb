require 'rails_helper'

RSpec.describe 'Movies', type: :request do
  describe 'GET /movies' do
    let!(:movie) { create(:movie, name: '映画テスト') }

    it 'ゲストでも映画一覧を閲覧できること' do
      get movies_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(movie.name)
    end

    it 'ログイン済みでも同様に閲覧できること' do
      user = create(:user)
      sign_in(user)

      get movies_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /movies/:id' do
    it 'ゲストでも映画詳細を閲覧できること' do
      movie = create(:movie)

      get movie_path(movie)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(movie.name)
    end
  end
end
