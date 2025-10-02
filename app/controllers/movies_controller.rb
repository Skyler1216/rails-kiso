class MoviesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[index show reservation]
  # ============================================================================
  # MoviesController - 映画関連のコントローラー
  # ============================================================================
  # 映画の一覧表示、詳細表示、予約画面への遷移を管理します。
  # 一般ユーザー向けの映画情報表示機能を提供します。
  # ============================================================================

  # ----------------------------------------------------------------------------
  # 映画一覧表示
  # ----------------------------------------------------------------------------
  def index
    # 全映画を取得
    @movies = Movie.all

    # 上映中/上映予定の絞り込み
    # params[:is_showing] が "true" または "false" の場合のみ絞り込み
    @movies = @movies.where(is_showing: params[:is_showing]) if params[:is_showing].present?

    # キーワード検索（映画名または説明文に部分一致）
    return unless params[:keyword].present?

    keyword = params[:keyword]
    @movies = @movies.where('name LIKE :q OR description LIKE :q', q: "%#{keyword}%")
  end

  # ----------------------------------------------------------------------------
  # 映画詳細表示
  # ----------------------------------------------------------------------------
  def show
    # 映画情報を取得
    @movie = Movie.find(params[:id])
    
    # 映画の全スケジュールを取得（劇場情報も含めて）
    @schedules = @movie.schedules.includes(screen: :theater).order(:start_time)

    # 上映劇場の一覧を作成（重複除去、名前順ソート）
    # 1. 各スケジュールから劇場情報を抽出
    #    - @schedulesは映画の全スケジュール（複数のスクリーン・劇場で上映される可能性）
    #    - schedule.screen.theater で各スケジュールの劇場を取得
    @theaters = @schedules.map { |schedule| schedule.screen.theater }
                         # 2. nil値を除去（スクリーンや劇場が存在しない場合の安全対策）
                         .compact
                         # 3. 劇場IDで重複を除去（同じ劇場が複数回登場する場合があるため）
                         #    - 例：劇場Aでスクリーン1とスクリーン2の両方で上映 → 劇場Aが2回登場
                         .uniq { |theater| theater.id }
                         # 4. 劇場名でアルファベット順にソート（ユーザビリティ向上）
                         .sort_by(&:name)

    # 選択された劇場の処理
    # 1. 劇場オブジェクトの決定（URLパラメータ優先、なければ最初の劇場をデフォルト選択）
    #    - @theaters.find: URLパラメータの劇場IDに一致する劇場を検索
    #    - || @theaters.first: 見つからない場合は最初の劇場をデフォルト選択
    #    - to_s: パラメータは文字列のため、IDを文字列に変換して比較
    @selected_theater =
      @theaters.find { |theater| theater.id.to_s == params[:theater_id].to_s } ||
      @theaters.first
    # 2. 選択された劇場のIDを文字列として保存（ビューでの使用のため）
    @selected_theater_id = @selected_theater&.id&.to_s

    # 3. 選択された劇場のスケジュールのみを抽出
    #    - 条件分岐：選択された劇場がある場合とない場合で処理を分ける
    #    - select: 条件に一致する要素のみを抽出
    #    - schedule.screen.theater_id: スケジュールのスクリーンが属する劇場ID
    #    - @selected_theater.id: 選択された劇場のID
    #    - 空配列[]: 劇場が選択されていない場合は空の配列を返す
    theater_schedules = if @selected_theater
                          @schedules.select { |schedule| schedule.screen.theater_id == @selected_theater.id }
                        else
                          []
                        end

    # 利用可能な日付の一覧を作成（今日以降のみ）
    today = Time.zone.today
    @available_dates = theater_schedules
                       .filter_map do |schedule|
                         start_date = schedule.start_time&.to_date
                         next unless start_date&.>= today

                         start_date.to_s
                       end
                       .uniq
                       .sort

    requested_date = params[:date].presence

    if requested_date.present? && @available_dates.include?(requested_date)
      @selected_date = requested_date
      @filtered_schedules = theater_schedules.select do |schedule|
        schedule.start_time&.to_date&.to_s == @selected_date
      end
    else
      @selected_date = nil
      @filtered_schedules = []
    end
  end

  # ----------------------------------------------------------------------------
  # 予約画面への遷移
  # ----------------------------------------------------------------------------
  def reservation
    # 映画情報を取得
    @movie = Movie.find(params[:id])

    # 必須パラメータのチェック
    unless params[:schedule_id].present? && params[:date].present?
      return redirect_to movie_path(@movie, theater_id: params[:theater_id]), 
             alert: 'スケジュールと日付を選択してください'
    end

    # スケジュール情報を取得
    @schedule = Schedule.includes(screen: :theater).find_by(id: params[:schedule_id])
    unless @schedule
      return redirect_to movie_path(@movie, theater_id: params[:theater_id], date: params[:date]), 
             alert: 'スケジュールが見つかりません'
    end

    # スクリーンと劇場情報を取得
    @screen = @schedule.screen
    @theater = @screen.theater

    # 劇場IDの整合性チェック
    if params[:theater_id].present? && params[:theater_id].to_i != @theater.id
      return redirect_to movie_path(@movie, theater_id: @theater.id, date: params[:date]), 
             alert: '劇場の選択を確認してください'
    end

    # 予約日を設定
    @date = params[:date]

    # スクリーンの全座席を取得
    @sheets = Sheet.where(screen_id: @schedule.screen_id)

    # 既に予約済みの座席IDを取得
    @reserved_sheets = Reservation.where(
      schedule_id: @schedule.id,
      date: @date,
      screen_id: @schedule.screen_id
    ).pluck(:sheet_id)
  end
end
