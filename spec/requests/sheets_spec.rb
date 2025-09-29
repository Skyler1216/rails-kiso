require 'rails_helper'

RSpec.describe 'Sheets', type: :request do
  describe 'GET /sheets' do
    it 'ゲストでも座席一覧を閲覧できること' do
      get sheets_path
      expect(response).to have_http_status(:ok)
    end

    it 'ログイン済みでも同様に閲覧できること' do
      user = create(:user)
      sign_in(user)

      get sheets_path

      expect(response).to have_http_status(:ok)
    end
  end
end
