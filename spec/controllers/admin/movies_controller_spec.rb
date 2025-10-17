require 'rails_helper'

RSpec.describe Admin::MoviesController, type: :controller do
  let(:admin_user) { create(:user, :admin) }
  let(:movie) { create(:movie) }

  before { sign_in admin_user }

  describe 'GET #index' do
    let!(:movie1) { create(:movie, name: '映画1') }
    let!(:movie2) { create(:movie, name: '映画2') }

    it '200を返すこと' do
      get :index
      expect(response).to have_http_status(200)
    end

    it '全映画を取得すること' do
      get :index
      expect(assigns(:movies)).to include(movie1, movie2)
    end
  end

  describe 'GET #new' do
    it '200を返すこと' do
      get :new
      expect(response).to have_http_status(200)
    end

    it '新しい映画オブジェクトを作成すること' do
      get :new
      expect(assigns(:movie)).to be_a_new(Movie)
    end
  end

  describe 'POST #create' do
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

    context '有効なパラメータの場合' do
      it '映画が作成されること' do
        expect do
          post :create, params: valid_params
        end.to change(Movie, :count).by(1)
      end

      it '映画一覧にリダイレクトすること' do
        post :create, params: valid_params
        expect(response).to redirect_to(admin_movies_path)
      end

      it '成功メッセージが表示されること' do
        post :create, params: valid_params
        expect(flash[:notice]).to eq('映画を登録しました。')
      end
    end

    context '無効なパラメータの場合' do
      let(:invalid_params) do
        {
          movie: {
            name: nil, # 無効な名前
            year: 2024,
            description: 'テスト映画です',
            image_url: 'https://example.com/image.jpg',
            is_showing: 1,
            running_minutes: 120
          }
        }
      end

      it '映画が作成されないこと' do
        expect do
          post :create, params: invalid_params
        end.not_to change(Movie, :count)
      end

      it 'newテンプレートを再表示すること' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
        expect(response).to have_http_status(422)
      end

      it 'エラーメッセージが表示されること' do
        post :create, params: invalid_params
        expect(flash.now[:alert]).to include('登録に失敗しました')
      end
    end

    context '例外が発生した場合' do
      before do
        allow_any_instance_of(Movie).to receive(:save).and_raise(StandardError, 'Test error')
      end

      it 'newテンプレートを再表示すること' do
        post :create, params: valid_params
        expect(response).to render_template(:new)
        expect(response).to have_http_status(500)
      end

      it 'エラーメッセージが表示されること' do
        post :create, params: valid_params
        expect(flash.now[:alert]).to include('エラーが発生しました: Test error')
      end
    end
  end

  describe 'GET #show' do
    it '200を返すこと' do
      get :show, params: { id: movie.id }
      expect(response).to have_http_status(200)
    end

    it '指定された映画を取得すること' do
      get :show, params: { id: movie.id }
      expect(assigns(:movie)).to eq(movie)
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        id: movie.id,
        movie: {
          name: '更新された映画',
          year: movie.year,
          description: movie.description,
          image_url: movie.image_url,
          is_showing: movie.is_showing,
          running_minutes: movie.running_minutes
        }
      }
    end

    context '有効なパラメータの場合' do
      it '映画が更新されること' do
        patch :update, params: update_params
        movie.reload
        expect(movie.name).to eq('更新された映画')
      end

      it '映画一覧にリダイレクトすること' do
        patch :update, params: update_params
        expect(response).to redirect_to(admin_movies_path)
      end

      it '成功メッセージが表示されること' do
        patch :update, params: update_params
        expect(flash[:notice]).to eq('映画を更新しました。')
      end
    end

    context '無効なパラメータの場合' do
      let(:invalid_update_params) do
        {
          id: movie.id,
          movie: {
            name: nil, # 無効な名前
            year: movie.year,
            description: movie.description,
            image_url: movie.image_url,
            is_showing: movie.is_showing,
            running_minutes: movie.running_minutes
          }
        }
      end

      it '映画が更新されないこと' do
        original_name = movie.name
        patch :update, params: invalid_update_params
        movie.reload
        expect(movie.name).to eq(original_name)
      end

      it 'showテンプレートを再表示すること' do
        patch :update, params: invalid_update_params
        expect(response).to render_template(:show)
        expect(response).to have_http_status(422)
      end

      it 'エラーメッセージが表示されること' do
        patch :update, params: invalid_update_params
        expect(flash.now[:alert]).to include('更新に失敗しました')
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:movie_to_delete) { create(:movie) }

    it '映画が削除されること' do
      expect do
        delete :destroy, params: { id: movie_to_delete.id }
      end.to change(Movie, :count).by(-1)
    end

    it '映画一覧にリダイレクトすること' do
      delete :destroy, params: { id: movie_to_delete.id }
      expect(response).to redirect_to(admin_movies_path)
    end

    it '成功メッセージが表示されること' do
      delete :destroy, params: { id: movie_to_delete.id }
      expect(flash[:notice]).to eq('映画を削除しました。')
    end
  end

  describe 'GET #edit' do
    it 'showアクションにリダイレクトすること' do
      get :edit, params: { id: movie.id }
      expect(response).to redirect_to(admin_movie_path(movie.id))
    end
  end

  describe '認証' do
    context '一般ユーザーでログインしている場合' do
      let(:user) { create(:user, admin: false) }

      before { sign_in user }

      it 'トップページにリダイレクトすること' do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
