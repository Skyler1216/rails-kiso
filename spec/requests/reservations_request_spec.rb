require 'rails_helper'

RSpec.describe 'Reservations', type: :request do
  let!(:user) { create(:user) }
  let!(:theater) { create(:theater) }
  let!(:screen) { create(:screen, theater: theater) }
  let!(:movie) { create(:movie) }
  let!(:schedule) { create(:schedule, movie: movie, screen: screen) }
  let!(:sheet) { create(:sheet, screen: screen) }

  describe 'GET /movies/:movie_id/schedules/:schedule_id/reservations/new' do
    context 'ログインしている場合' do
      before { sign_in user }

      it '予約フォームが表示されること' do
        get new_movie_schedule_reservation_path(movie, schedule), params: {
          sheet_id: sheet.id,
          date: '2025-09-22'
        }
        expect(response).to have_http_status(200)
      end

      it '必須パラメータが不足している場合は400を返すこと' do
        get new_movie_schedule_reservation_path(movie, schedule)
        expect(response).to have_http_status(400)
      end

      it '重複予約がある場合はリダイレクトすること' do
        create(:reservation, 
               schedule: schedule, 
               sheet: sheet, 
               date: '2025-09-22',
               screen: screen)

        get new_movie_schedule_reservation_path(movie, schedule), params: {
          sheet_id: sheet.id,
          date: '2025-09-22'
        }
        expect(response).to have_http_status(302)
      end
    end

    context 'ログインしていない場合' do
      it 'ログインページにリダイレクトすること' do
        get new_movie_schedule_reservation_path(movie, schedule), params: {
          sheet_id: sheet.id,
          date: '2025-09-22'
        }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'POST /reservations' do
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

    context 'ログインしている場合' do
      before { sign_in user }

      it '予約が作成されること' do
        expect {
          post reservations_path, params: valid_params
        }.to change(Reservation, :count).by(1)
      end

      it '映画詳細ページにリダイレクトすること' do
        post reservations_path, params: valid_params
        expect(response).to redirect_to(movie_path(movie))
      end

      it '重複予約がある場合はリダイレクトすること' do
        create(:reservation, 
               schedule: schedule, 
               sheet: sheet, 
               date: '2025-09-22',
               screen: screen)

        post reservations_path, params: valid_params
        expect(response).to have_http_status(302)
      end
    end

    context 'ログインしていない場合' do
      it 'ログインページにリダイレクトすること' do
        post reservations_path, params: valid_params
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
