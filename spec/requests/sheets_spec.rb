require 'rails_helper'

RSpec.describe 'Sheets', type: :request do
  describe 'GET /sheets' do
    context 'when unauthenticated' do
      it 'redirects to the login page' do
        get sheets_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'when authenticated' do
      it 'returns http success' do
        user = create(:user)
        sign_in(user)

        get sheets_path

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
