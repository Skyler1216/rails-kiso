require 'rails_helper'

RSpec.describe ReservationsController, type: :controller do
  let!(:user) { create(:user) }
  let!(:theater) { create(:theater) }
  let!(:screen) { create(:screen, theater: theater) }
  let!(:movie) { create(:movie) }
  let!(:schedule) { create(:schedule, movie: movie, screen: screen) }
  let!(:sheet) { create(:sheet, screen: screen) }

  before do
    sign_in user
  end

  describe 'GET #new' do
    context '有効なパラメータの場合' do
      it '200を返すこと' do
        get :new, params: {
          movie_id: movie.id,
          schedule_id: schedule.id,
          sheet_id: sheet.id,
          date: '2025-09-22'
        }
        expect(response).to have_http_status(200)
      end

      it '予約フォームを表示すること' do
        get :new, params: {
          movie_id: movie.id,
          schedule_id: schedule.id,
          sheet_id: sheet.id,
          date: '2025-09-22'
        }
        expect(assigns(:movie)).to eq(movie)
        expect(assigns(:schedule)).to eq(schedule)
        expect(assigns(:sheet)).to eq(sheet)
        expect(assigns(:reservation)).to be_a_new(Reservation)
      end
    end

    context '必須パラメータが不足している場合' do
      it '400を返すこと' do
        get :new, params: { movie_id: movie.id }
        expect(response).to have_http_status(400)
      end
    end

    context '重複予約がある場合' do
      let!(:existing_reservation) do
        create(:reservation, 
               schedule: schedule, 
               sheet: sheet, 
               date: '2025-09-22',
               screen: screen)
      end

      it 'リダイレクトすること' do
        get :new, params: {
          movie_id: movie.id,
          schedule_id: schedule.id,
          sheet_id: sheet.id,
          date: '2025-09-22'
        }
        expect(response).to redirect_to(reservation_movie_path(movie, 
                                                              schedule_id: schedule.id,
                                                              date: '2025-09-22',
                                                              theater_id: theater.id))
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        reservation: {
          schedule_id: schedule.id,
          sheet_id: sheet.id,
          date: '2025-09-22',
          screen_id: screen.id
        }
      }
    end

    context '有効なパラメータの場合' do
      it '予約が作成されること' do
        expect {
          post :create, params: valid_params
        }.to change(Reservation, :count).by(1)
      end

      it '映画詳細画面にリダイレクトすること' do
        post :create, params: valid_params
        expect(response).to redirect_to(movie_path(movie))
      end

      it '成功メッセージが表示されること' do
        post :create, params: valid_params
        expect(flash[:notice]).to eq('予約が完了しました')
      end

      it '現在のユーザー情報が設定されること' do
        post :create, params: valid_params
        reservation = Reservation.last
        expect(reservation.user).to eq(user)
        expect(reservation.name).to eq(user.name)
        expect(reservation.email).to eq(user.email)
      end
    end

    context '重複予約がある場合' do
      let!(:existing_reservation) do
        create(:reservation, 
               schedule: schedule, 
               sheet: sheet, 
               date: '2025-09-22',
               screen: screen)
      end

      it '予約が作成されないこと' do
        expect {
          post :create, params: valid_params
        }.not_to change(Reservation, :count)
      end

      it 'リダイレクトすること' do
        post :create, params: valid_params
        expect(response).to redirect_to(reservation_movie_path(movie,
                                                              schedule_id: schedule.id,
                                                              date: '2025-09-22',
                                                              theater_id: theater.id))
      end

      it 'エラーメッセージが表示されること' do
        post :create, params: valid_params
        expect(flash[:alert]).to eq('その座席はすでに予約済みです')
      end
    end

    context 'バリデーションエラーの場合' do
      let(:invalid_params) do
        {
          reservation: {
            schedule_id: schedule.id,
            sheet_id: sheet.id,
            date: nil, # 無効な日付
            screen_id: screen.id
          }
        }
      end

      it '予約が作成されないこと' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Reservation, :count)
      end

      it 'newテンプレートを再表示すること' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
        expect(response).to have_http_status(422)
      end

      it 'エラーメッセージが表示されること' do
        post :create, params: invalid_params
        expect(flash.now[:alert]).to eq('入力内容に誤りがあります')
      end
    end
  end

  describe '認証' do
    context 'ログインしていない場合' do
      before { sign_out user }

      it 'ログインページにリダイレクトすること' do
        get :new, params: {
          movie_id: movie.id,
          schedule_id: schedule.id,
          sheet_id: sheet.id,
          date: '2025-09-22'
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
