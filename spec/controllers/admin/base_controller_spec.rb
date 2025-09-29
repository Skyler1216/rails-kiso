require 'rails_helper'

RSpec.describe Admin::BaseController, type: :controller do
  # テスト用のダミーコントローラーを作成
  controller(Admin::BaseController) do
    def index
      render plain: 'Admin page'
    end
  end

  describe '認証' do
    context 'ログインしていない場合' do
      it 'ログインページにリダイレクトすること' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context '一般ユーザーでログインしている場合' do
      let(:user) { create(:user, admin: false) }

      before { sign_in user }

      it 'トップページにリダイレクトすること' do
        get :index
        expect(response).to redirect_to(root_path)
      end

      it 'エラーメッセージが表示されること' do
        get :index
        expect(flash[:alert]).to include('管理者権限が必要です')
      end
    end

    context '管理者でログインしている場合' do
      let(:admin_user) { create(:user, :admin) }

      before { sign_in admin_user }

      it '200を返すこと' do
        get :index
        expect(response).to have_http_status(200)
      end

      it '管理者ページが表示されること' do
        get :index
        expect(response.body).to include('Admin page')
      end
    end
  end

  describe 'ヘルパーメソッド' do
    let(:admin_user) { create(:user, :admin) }

    before { sign_in admin_user }

    describe '#admin_user?' do
      it '管理者の場合trueを返すこと' do
        expect(controller.send(:admin_user?)).to be true
      end
    end

    describe '#admin_flash_success' do
      it '成功メッセージを設定すること' do
        controller.send(:admin_flash_success, 'テストメッセージ')
        expect(flash[:notice]).to eq('✅ テストメッセージ')
      end
    end

    describe '#admin_flash_error' do
      it 'エラーメッセージを設定すること' do
        controller.send(:admin_flash_error, 'エラーメッセージ')
        expect(flash[:alert]).to eq('❌ エラーメッセージ')
      end
    end
  end
end
