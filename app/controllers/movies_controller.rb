class MoviesController < ApplicationController
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
    @theaters = @schedules.map { |schedule| schedule.screen.theater }
                         .compact
                         .uniq { |theater| theater.id }
                         .sort_by(&:name)

    # 選択された劇場の処理
    @selected_theater_id = params[:theater_id].presence || @theaters.first&.id&.to_s
    @selected_theater = @theaters.find { |theater| theater.id.to_s == @selected_theater_id } if @selected_theater_id.present?
    
    # 劇場が選択されていない場合は最初の劇場を選択
    if @selected_theater.nil? && @theaters.any?
      @selected_theater = @theaters.first
      @selected_theater_id = @selected_theater.id.to_s
    end

    # 選択された劇場のスケジュールのみを抽出
    theater_schedules = if @selected_theater
                          @schedules.select { |schedule| schedule.screen.theater_id == @selected_theater.id }
                        else
                          []
                        end

    # 利用可能な日付の一覧を作成（今日以降のみ）
    @available_dates = theater_schedules
                       .map { |schedule| schedule.start_time.to_date }
                       .select { |date| date >= Date.today }
                       .uniq
                       .sort
                       .map(&:to_s)

    # 選択された日付の処理
    if @available_dates.any?
      requested_date = params[:date].presence
      @selected_date = if requested_date && @available_dates.include?(requested_date)
                         requested_date
                       else
                         @available_dates.first
                       end

      # 選択された日付のスケジュールのみを抽出
      @filtered_schedules = theater_schedules.select { |schedule| schedule.start_time.to_date.to_s == @selected_date }
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
