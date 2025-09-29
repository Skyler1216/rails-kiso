require 'rails_helper'

RSpec.describe 'Admin', type: :request do
  let!(:admin_user) { create(:user, :admin) }
  let!(:regular_user) { create(:user, admin: false) }

  describe 'GET /admin' do
    context '管理者でログインしている場合' do
      before { sign_in admin_user }

      it '管理者ダッシュボードが表示されること' do
        get admin_root_path
        expect(response).to have_http_status(200)
      end
    end

    context '一般ユーザーでログインしている場合' do
      before { sign_in regular_user }

      it 'トップページにリダイレクトすること' do
        get admin_root_path
        expect(response).to redirect_to(root_path)
      end
    end

    context 'ログインしていない場合' do
      it 'ログインページにリダイレクトすること' do
        get admin_root_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET /admin/movies' do
    context '管理者でログインしている場合' do
      before { sign_in admin_user }

      it '映画管理ページが表示されること' do
        get admin_movies_path
        expect(response).to have_http_status(200)
      end
    end

    context '一般ユーザーでログインしている場合' do
      before { sign_in regular_user }

      it 'トップページにリダイレクトすること' do
        get admin_movies_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /admin/movies' do
    let(:valid_params) do
      {
        movie: {
          name: '新しい映画',
          year: 2024,
          description: 'テスト映画です',
          image_url: 'https://example.com/image.jpg',
          is_showing: 1,
          running_minutes: 120
        }
      }
    end

    context '管理者でログインしている場合' do
      before { sign_in admin_user }

      it '映画が作成されること' do
        expect {
          post admin_movies_path, params: valid_params
        }.to change(Movie, :count).by(1)
      end

      it '映画一覧にリダイレクトすること' do
        post admin_movies_path, params: valid_params
        expect(response).to redirect_to(admin_movies_path)
      end
    end

    context '一般ユーザーでログインしている場合' do
      before { sign_in regular_user }

      it 'トップページにリダイレクトすること' do
        post admin_movies_path, params: valid_params
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET /admin/theaters' do
    context '管理者でログインしている場合' do
      before { sign_in admin_user }

      it '劇場管理ページが表示されること' do
        get admin_theaters_path
        expect(response).to have_http_status(200)
      end
    end

    context '一般ユーザーでログインしている場合' do
      before { sign_in regular_user }

      it 'トップページにリダイレクトすること' do
        get admin_theaters_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET /admin/schedules' do
    context '管理者でログインしている場合' do
      before { sign_in admin_user }

      it 'スケジュール管理ページが表示されること' do
        get admin_schedules_path
        expect(response).to have_http_status(200)
      end
    end

    context '一般ユーザーでログインしている場合' do
      before { sign_in regular_user }

      it 'トップページにリダイレクトすること' do
        get admin_schedules_path
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET /admin/reservations' do
    context '管理者でログインしている場合' do
      before { sign_in admin_user }

      it '予約管理ページが表示されること' do
        get admin_reservations_path
        expect(response).to have_http_status(200)
      end
    end

    context '一般ユーザーでログインしている場合' do
      before { sign_in regular_user }

      it 'トップページにリダイレクトすること' do
        get admin_reservations_path
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
