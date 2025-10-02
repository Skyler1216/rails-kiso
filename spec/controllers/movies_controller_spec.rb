# Railsのテストヘルパーファイルを読み込み
# これにより、Railsアプリケーションの環境やテスト用の設定が利用可能になる
require 'rails_helper'

# MoviesControllerのテストを記述するためのRSpecブロック
# type: :controller を指定することで、コントローラーのテストであることを明示
RSpec.describe MoviesController, type: :controller do
  # render_viewsを有効にすることで、実際にHTMLビューがレンダリングされる
  # これにより、response.bodyでHTMLの内容をテストできるようになる
  render_views

  # GET #indexアクション（映画一覧ページ）のテストを記述
  describe 'GET #index' do
    # テスト用のデータを事前に作成
    # let!は即座に実行されるため、各テストケースで利用可能
    # create(:movie, ...)はFactoryBotを使ってテストデータを作成
    let!(:movie1) { create(:movie, name: '映画1', is_showing: 1) }  # 上映中の映画
    let!(:movie2) { create(:movie, name: '映画2', is_showing: 0) }  # 上映予定の映画
    let!(:movie3) { create(:movie, name: 'テスト映画', is_showing: 1) }  # 上映中の映画（検索テスト用）

    # パラメータなしでアクセスした場合のテスト
    context 'パラメータなしの場合' do
      # HTTPステータスコードが200（成功）を返すことをテスト
      it '200を返すこと' do
        # GETリクエストでindexアクションを実行
        get :index
        # レスポンスのHTTPステータスが200であることを確認
        expect(response).to have_http_status(200)
      end

      # HTMLが正しく返されることをテスト
      it 'HTMLを返すこと' do
        # GETリクエストでindexアクションを実行
        get :index
        # レスポンスボディにHTMLのDOCTYPE宣言が含まれていることを確認
        expect(response.body).to include('<!DOCTYPE html>')
      end

      # 全ての映画が表示されることをテスト
      it '全映画を表示すること' do
        # GETリクエストでindexアクションを実行
        get :index
        # レスポンスボディに作成した3つの映画の名前が全て含まれていることを確認
        expect(response.body).to include(movie1.name)
        expect(response.body).to include(movie2.name)
        expect(response.body).to include(movie3.name)
      end
    end

    # is_showingパラメータで上映状況を絞り込む場合のテスト
    context 'is_showingパラメータがある場合' do
      # 上映中の映画（is_showing: 1）のみが表示されることをテスト
      it '上映中の映画のみ表示すること' do
        # is_showingパラメータに'1'（上映中）を指定してGETリクエスト
        get :index, params: { is_showing: '1' }
        # 上映中の映画（movie1, movie3）が表示されることを確認
        expect(response.body).to include(movie1.name)
        expect(response.body).to include(movie3.name)
        # 上映予定の映画（movie2）が表示されないことを確認
        expect(response.body).not_to include(movie2.name)
      end

      # 上映予定の映画（is_showing: 0）のみが表示されることをテスト
      it '上映予定の映画のみ表示すること' do
        # is_showingパラメータに'0'（上映予定）を指定してGETリクエスト
        get :index, params: { is_showing: '0' }
        # 上映予定の映画（movie2）が表示されることを確認
        expect(response.body).to include(movie2.name)
        # 上映中の映画（movie1, movie3）が表示されないことを確認
        expect(response.body).not_to include(movie1.name)
        expect(response.body).not_to include(movie3.name)
      end
    end

    # keywordパラメータで検索機能をテストする場合
    context 'keywordパラメータがある場合' do
      # 映画名での完全一致検索が動作することをテスト
      it '映画名で検索できること' do
        # keywordパラメータに'映画1'を指定してGETリクエスト
        get :index, params: { keyword: '映画1' }
        # '映画1'という名前の映画（movie1）のみが表示されることを確認
        expect(response.body).to include(movie1.name)
        # 他の映画（movie2, movie3）が表示されないことを確認
        expect(response.body).not_to include(movie2.name)
        expect(response.body).not_to include(movie3.name)
      end

      # 説明文での検索が動作することをテスト
      it '説明文で検索できること' do
        # movie1の説明文を更新（テスト用の説明文を追加）
        movie1.update!(description: 'アクション映画です')
        # keywordパラメータに'アクション'を指定してGETリクエスト
        get :index, params: { keyword: 'アクション' }
        # 説明文に'アクション'を含む映画（movie1）のみが表示されることを確認
        expect(response.body).to include(movie1.name)
        # 他の映画（movie2, movie3）が表示されないことを確認
        expect(response.body).not_to include(movie2.name)
        expect(response.body).not_to include(movie3.name)
      end

      # 部分一致検索が動作することをテスト
      it '部分一致で検索できること' do
        # keywordパラメータに'テスト'を指定してGETリクエスト
        get :index, params: { keyword: 'テスト' }
        # 名前に'テスト'を含む映画（movie3）のみが表示されることを確認
        expect(response.body).to include(movie3.name)
        # 他の映画（movie1, movie2）が表示されないことを確認
        expect(response.body).not_to include(movie1.name)
        expect(response.body).not_to include(movie2.name)
      end
    end

    # 複数のパラメータを組み合わせた絞り込み機能のテスト
    context '複数パラメータがある場合' do
      # is_showingとkeywordの両方のパラメータで絞り込みが動作することをテスト
      it 'is_showingとkeywordの両方で絞り込みできること' do
        # is_showing: '1'（上映中）とkeyword: '映画'の両方を指定してGETリクエスト
        get :index, params: { is_showing: '1', keyword: '映画' }
        # 上映中かつ名前に'映画'を含む映画（movie1, movie3）が表示されることを確認
        expect(response.body).to include(movie1.name)
        expect(response.body).to include(movie3.name)
        # 上映予定の映画（movie2）が表示されないことを確認
        expect(response.body).not_to include(movie2.name)
      end
    end
  end

  # GET #showアクション（映画詳細ページ）のテストを記述
  describe 'GET #show' do
    # テスト用の劇場データを作成
    let!(:theater1) { create(:theater, name: '劇場A') }  # 劇場A
    let!(:theater2) { create(:theater, name: '劇場B') }  # 劇場B
    
    # 各劇場のスクリーンデータを作成
    let!(:screen1) { create(:screen, theater: theater1, name: 'スクリーン1') }  # 劇場Aのスクリーン1
    let!(:screen2) { create(:screen, theater: theater2, name: 'スクリーン1') }  # 劇場Bのスクリーン1
    
    # テスト対象の映画データを作成
    let!(:movie) { create(:movie) }
    
    # 未来の日付と時間を設定（スケジュールテスト用）
    let(:future_date) { Time.zone.today + 5.days }  # 5日後の日付
    let(:future_start_time1) { future_date.in_time_zone.change(hour: 10, min: 0) }  # 10:00開始
    let(:future_start_time2) { future_date.in_time_zone.change(hour: 14, min: 0) }  # 14:00開始
    
    # 各スクリーンでの上映スケジュールを作成
    let!(:schedule1) { create(:schedule, movie: movie, screen: screen1, start_time: future_start_time1) }
    let!(:schedule2) { create(:schedule, movie: movie, screen: screen2, start_time: future_start_time2) }

    # HTTPステータスコードが200（成功）を返すことをテスト
    it '200を返すこと' do
      # 映画のIDを指定してshowアクションを実行
      get :show, params: { id: movie.id }
      # レスポンスのHTTPステータスが200であることを確認
      expect(response).to have_http_status(200)
    end

    # 映画の詳細情報が正しく表示されることをテスト
    it '映画情報を表示すること' do
      # 映画のIDを指定してshowアクションを実行
      get :show, params: { id: movie.id }
      # レスポンスボディに映画の名前が含まれていることを確認
      expect(response.body).to include(movie.name)
    end

    # 上映劇場の一覧が正しく表示されることをテスト
    it '上映劇場の一覧を表示すること' do
      # 映画のIDを指定してshowアクションを実行
      get :show, params: { id: movie.id }
      # レスポンスボディに両方の劇場名が含まれていることを確認
      expect(response.body).to include(theater1.name)
      expect(response.body).to include(theater2.name)
    end

    # theater_idパラメータで特定の劇場を指定した場合のテスト
    context 'theater_idパラメータがある場合' do
      # 指定された劇場のスケジュールのみが表示されることをテスト
      it '指定された劇場のスケジュールのみ表示すること' do
        # 映画IDと劇場IDを指定してshowアクションを実行
        get :show, params: { id: movie.id, theater_id: theater1.id }
        # コントローラーで設定されたselected_theaterが正しい劇場であることを確認
        # assigns(:selected_theater)はコントローラーで@selected_theaterに設定された値を取得
        expect(assigns(:selected_theater)).to eq(theater1)
      end
    end

    # dateパラメータで特定の日付を指定した場合のテスト
    context 'dateパラメータがある場合' do
      # 指定された日付のスケジュールのみが表示されることをテスト
      it '指定された日付のスケジュールのみ表示すること' do
        # 日付を文字列に変換
        future_date_str = future_date.to_s
        # 映画ID、劇場ID、日付を指定してshowアクションを実行
        get :show, params: { id: movie.id, theater_id: theater1.id, date: future_date_str }
        # コントローラーで設定されたselected_dateが正しい日付であることを確認
        # assigns(:selected_date)はコントローラーで@selected_dateに設定された値を取得
        expect(assigns(:selected_date)).to eq(future_date_str)
      end
    end
  end

  # GET #reservationアクション（予約画面）のテストを記述
  describe 'GET #reservation' do
    # 予約画面テスト用のデータを作成
    let!(:theater) { create(:theater) }  # 劇場
    let!(:screen) { create(:screen, theater: theater) }  # スクリーン
    let!(:movie) { create(:movie) }  # 映画
    let!(:schedule) { create(:schedule, movie: movie, screen: screen) }  # 上映スケジュール
    let!(:sheet) { create(:sheet, screen: screen) }  # 座席
    # 予約日付をスケジュールの開始時間から取得
    let(:reservation_date) { schedule.start_time.to_date.to_s }

    # 有効なパラメータで予約画面にアクセスした場合のテスト
    context '有効なパラメータの場合' do
      # HTTPステータスコードが200（成功）を返すことをテスト
      it '200を返すこと' do
        # 必要なパラメータを全て指定してreservationアクションを実行
        get :reservation, params: { 
          id: movie.id,           # 映画ID
          schedule_id: schedule.id,  # スケジュールID
          date: reservation_date,    # 予約日付
          theater_id: theater.id     # 劇場ID
        }
        # レスポンスのHTTPステータスが200であることを確認
        expect(response).to have_http_status(200)
      end

      # 予約画面に必要な情報が正しく設定されることをテスト
      it '予約画面を表示すること' do
        # 必要なパラメータを全て指定してreservationアクションを実行
        get :reservation, params: { 
          id: movie.id,           # 映画ID
          schedule_id: schedule.id,  # スケジュールID
          date: reservation_date,    # 予約日付
          theater_id: theater.id     # 劇場ID
        }
        # コントローラーで設定された各インスタンス変数が正しいオブジェクトであることを確認
        expect(assigns(:movie)).to eq(movie)        # @movieが正しい映画オブジェクト
        expect(assigns(:schedule)).to eq(schedule)  # @scheduleが正しいスケジュールオブジェクト
        expect(assigns(:screen)).to eq(screen)      # @screenが正しいスクリーンオブジェクト
        expect(assigns(:theater)).to eq(theater)    # @theaterが正しい劇場オブジェクト
      end
    end

    # 無効なschedule_idでアクセスした場合のテスト
    context 'schedule_idが無効な場合' do
      # 存在しないスケジュールIDでアクセスした場合にリダイレクトされることをテスト
      it 'リダイレクトすること' do
        # 存在しないスケジュールID（99999）を指定してreservationアクションを実行
        get :reservation, params: { 
          id: movie.id,           # 映画ID
          schedule_id: 99999,     # 存在しないスケジュールID
          date: reservation_date,    # 予約日付
          theater_id: theater.id     # 劇場ID
        }
        # 映画詳細ページにリダイレクトされることを確認
        # movie_pathは映画詳細ページのURLを生成するヘルパーメソッド
        expect(response).to redirect_to(movie_path(movie, theater_id: theater.id, date: reservation_date))
      end
    end

    # 必須パラメータが不足している場合のテスト
    context '必須パラメータが不足している場合' do
      # 必要なパラメータが不足している場合にリダイレクトされることをテスト
      it 'リダイレクトすること' do
        # 映画IDのみを指定してreservationアクションを実行（他の必須パラメータが不足）
        get :reservation, params: { id: movie.id }
        # 映画詳細ページにリダイレクトされることを確認
        # theater_idがnilの状態でリダイレクトされる
        expect(response).to redirect_to(movie_path(movie, theater_id: nil))
      end
    end
  end
end
