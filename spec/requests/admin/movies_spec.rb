require 'rails_helper'

RSpec.describe 'Admin::Movies', type: :request do
  let(:admin) { create(:user, :admin) }

  describe 'GET /index' do
    it '管理者ログイン時は映画管理ページを閲覧できること' do
      sign_in admin

      get admin_movies_path

      expect(response).to have_http_status(:success)
    end
  end
end
