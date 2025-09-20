require 'rails_helper'

RSpec.describe Admin::MoviesController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    @request.env['devise.mapping'] = Devise.mappings[:user]
  end

  describe '認証チェック' do
    context '未ログインユーザー' do
      it 'ログインページにリダイレクトされる' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context '一般ユーザー' do
      before { sign_in create(:user, admin: false) }

      it 'トップページにリダイレクトされる' do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end

    context '管理者ユーザー' do
      before { sign_in create(:user, :admin) }

      it '管理者ページにアクセスできる' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end
  end
end
