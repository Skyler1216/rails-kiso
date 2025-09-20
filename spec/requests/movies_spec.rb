require 'rails_helper'

RSpec.describe 'Movies', type: :request do
  describe 'GET /movies' do
    context 'when unauthenticated' do
      it 'redirects to the login page' do
        get movies_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated' do
      it 'returns http success' do
        user = create(:user)
        sign_in(user)

        get movies_path

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /movies/:id' do
    it 'requires authentication' do
      movie = create(:movie)

      get movie_path(movie)

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
