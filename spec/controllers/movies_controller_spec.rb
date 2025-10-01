require 'rails_helper'

RSpec.describe MoviesController, type: :controller do
  # render_viewsがあるとページの内容を実際につくることができる
  render_views

  describe 'GET #index' do
    let!(:movie1) { create(:movie, name: '映画1', is_showing: 1) }
    let!(:movie2) { create(:movie, name: '映画2', is_showing: 0) }
    let!(:movie3) { create(:movie, name: 'テスト映画', is_showing: 1) }

    context 'パラメータなしの場合' do
      it '200を返すこと' do
        get :index
        expect(response).to have_http_status(200)
      end

      it 'HTMLを返すこと' do
        get :index
        expect(response.body).to include('<!DOCTYPE html>')
      end

      it '全映画を表示すること' do
        get :index
        expect(response.body).to include(movie1.name)
        expect(response.body).to include(movie2.name)
        expect(response.body).to include(movie3.name)
      end
    end

    context 'is_showingパラメータがある場合' do
      it '上映中の映画のみ表示すること' do
        get :index, params: { is_showing: '1' }
        expect(response.body).to include(movie1.name)
        expect(response.body).to include(movie3.name)
        expect(response.body).not_to include(movie2.name)
      end

      it '上映予定の映画のみ表示すること' do
        get :index, params: { is_showing: '0' }
        expect(response.body).to include(movie2.name)
        expect(response.body).not_to include(movie1.name)
        expect(response.body).not_to include(movie3.name)
      end
    end

    context 'keywordパラメータがある場合' do
      it '映画名で検索できること' do
        get :index, params: { keyword: '映画1' }
        expect(response.body).to include(movie1.name)
        expect(response.body).not_to include(movie2.name)
        expect(response.body).not_to include(movie3.name)
      end

      it '説明文で検索できること' do
        movie1.update!(description: 'アクション映画です')
        get :index, params: { keyword: 'アクション' }
        expect(response.body).to include(movie1.name)
        expect(response.body).not_to include(movie2.name)
        expect(response.body).not_to include(movie3.name)
      end

      it '部分一致で検索できること' do
        get :index, params: { keyword: 'テスト' }
        expect(response.body).to include(movie3.name)
        expect(response.body).not_to include(movie1.name)
        expect(response.body).not_to include(movie2.name)
      end
    end

    context '複数パラメータがある場合' do
      it 'is_showingとkeywordの両方で絞り込みできること' do
        get :index, params: { is_showing: '1', keyword: '映画' }
        expect(response.body).to include(movie1.name)
        expect(response.body).to include(movie3.name)
        expect(response.body).not_to include(movie2.name)
      end
    end
  end

  describe 'GET #show' do
    let!(:theater1) { create(:theater, name: '劇場A') }
    let!(:theater2) { create(:theater, name: '劇場B') }
    let!(:screen1) { create(:screen, theater: theater1, name: 'スクリーン1') }
    let!(:screen2) { create(:screen, theater: theater2, name: 'スクリーン1') }
    let!(:movie) { create(:movie) }
    let(:future_date) { Time.zone.today + 5.days }
    let(:future_start_time1) { future_date.in_time_zone.change(hour: 10, min: 0) }
    let(:future_start_time2) { future_date.in_time_zone.change(hour: 14, min: 0) }
    let!(:schedule1) { create(:schedule, movie: movie, screen: screen1, start_time: future_start_time1) }
    let!(:schedule2) { create(:schedule, movie: movie, screen: screen2, start_time: future_start_time2) }

    it '200を返すこと' do
      get :show, params: { id: movie.id }
      expect(response).to have_http_status(200)
    end

    it '映画情報を表示すること' do
      get :show, params: { id: movie.id }
      expect(response.body).to include(movie.name)
    end

    it '上映劇場の一覧を表示すること' do
      get :show, params: { id: movie.id }
      expect(response.body).to include(theater1.name)
      expect(response.body).to include(theater2.name)
    end

    context 'theater_idパラメータがある場合' do
      it '指定された劇場のスケジュールのみ表示すること' do
        get :show, params: { id: movie.id, theater_id: theater1.id }
        expect(assigns(:selected_theater)).to eq(theater1)
      end
    end

    context 'dateパラメータがある場合' do
      it '指定された日付のスケジュールのみ表示すること' do
        future_date_str = future_date.to_s
        get :show, params: { id: movie.id, theater_id: theater1.id, date: future_date_str }
        expect(assigns(:selected_date)).to eq(future_date_str)
      end
    end
  end

  describe 'GET #reservation' do
    let!(:theater) { create(:theater) }
    let!(:screen) { create(:screen, theater: theater) }
    let!(:movie) { create(:movie) }
    let!(:schedule) { create(:schedule, movie: movie, screen: screen) }
    let!(:sheet) { create(:sheet, screen: screen) }
    let(:reservation_date) { schedule.start_time.to_date.to_s }

    context '有効なパラメータの場合' do
      it '200を返すこと' do
        get :reservation, params: { 
          id: movie.id, 
          schedule_id: schedule.id, 
          date: reservation_date,
          theater_id: theater.id
        }
        expect(response).to have_http_status(200)
      end

      it '予約画面を表示すること' do
        get :reservation, params: { 
          id: movie.id, 
          schedule_id: schedule.id, 
          date: reservation_date,
          theater_id: theater.id
        }
        expect(assigns(:movie)).to eq(movie)
        expect(assigns(:schedule)).to eq(schedule)
        expect(assigns(:screen)).to eq(screen)
        expect(assigns(:theater)).to eq(theater)
      end
    end

    context 'schedule_idが無効な場合' do
      it 'リダイレクトすること' do
        get :reservation, params: { 
          id: movie.id, 
          schedule_id: 99999, 
          date: reservation_date,
          theater_id: theater.id
        }
        expect(response).to redirect_to(movie_path(movie, theater_id: theater.id, date: reservation_date))
      end
    end

    context '必須パラメータが不足している場合' do
      it 'リダイレクトすること' do
        get :reservation, params: { id: movie.id }
        expect(response).to redirect_to(movie_path(movie, theater_id: nil))
      end
    end
  end
end
