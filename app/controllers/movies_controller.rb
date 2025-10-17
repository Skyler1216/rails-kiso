class MoviesController < ApplicationController
  RANKING_LIMIT = 10

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
    # station 5,6の変更箇所
    # 人気ランキングデータを読み込み（トップページ表示用）
    load_popular_rankings

    # 全映画を取得
    @movies = Movie.all

    # 上映中/上映予定の絞り込み
    # params[:is_showing] が "true" または "false" の場合のみ絞り込み
    @movies = @movies.where(is_showing: params[:is_showing]) if params[:is_showing].present?

    # キーワード検索（映画名または説明文に部分一致）
    # パラメータが存在しない場合はここで処理終了
    return unless params[:keyword].present?

    # 検索キーワードを取得
    keyword = params[:keyword]
    # SQLのLIKE演算子を使用して部分一致検索を実行
    # %ワイルドカードで前後の文字列も含めて検索
    @movies = @movies.where('name LIKE :q OR description LIKE :q', q: "%#{keyword}%")
  end

  # ----------------------------------------------------------------------------
  # 映画詳細表示
  # ----------------------------------------------------------------------------
  def show
    @movie = Movie.find(params[:id])
    @schedules = movie_schedules(@movie)
    @theaters = extract_theaters(@schedules)
    @selected_theater = resolve_selected_theater(@theaters, params[:theater_id])
    @selected_theater_id = @selected_theater&.id&.to_s

    theater_schedules = schedules_for_theater(@schedules, @selected_theater)
    @available_dates = available_dates_for(theater_schedules)
    @selected_date, @filtered_schedules = select_schedules_for_date(
      theater_schedules,
      params[:date],
      @available_dates
    )
  end

  # ----------------------------------------------------------------------------
  # 予約画面への遷移
  # ----------------------------------------------------------------------------
  def reservation
    @movie = Movie.find(params[:id])
    return redirect_missing_selection unless reservation_params_present?

    @schedule = Schedule.includes(screen: :theater).find_by(id: params[:schedule_id])
    return redirect_unknown_schedule unless @schedule

    @screen = @schedule.screen
    @theater = @screen.theater
    return redirect_mismatched_theater if theater_mismatch?(@theater, params[:theater_id])

    assign_reservation_resources(@schedule, params[:date])
  end

  private

  # station 5,6の変更箇所
  def load_popular_rankings
    # 人気ランキングデータのスコープを設定（映画情報も事前読み込み）
    scope = DailyMovieRanking.includes(:movie)
    today = Time.zone.today

    # 今日のランキングデータを取得
    rankings = scope.for_date(today).ordered.limit(RANKING_LIMIT).to_a
    ranking_date = today

    # 今日のデータが存在しない場合の処理
    if rankings.empty?
      # 最新のランキングデータの日付を取得
      latest_date = DailyMovieRanking.maximum(:aggregated_on)

      # 最新データが存在し、今日と異なる日付の場合
      if latest_date.present? && latest_date != today
        # 最新のランキングデータを使用
        rankings = scope.for_date(latest_date).ordered.limit(RANKING_LIMIT).to_a
        ranking_date = latest_date if rankings.present?
      end
    end

    # ビューで使用するインスタンス変数に設定
    @movie_rankings = rankings
    @ranking_date = rankings.present? ? ranking_date : nil
  end
  # station 5,6の変更箇所　ここまで

  def movie_schedules(movie)
    movie.schedules.includes(screen: :theater).order(:start_time)
  end

  def extract_theaters(schedules)
    schedules.map { |schedule| schedule.screen.theater }
             .compact
             .uniq(&:id)
             .sort_by(&:name)
  end

  def resolve_selected_theater(theaters, requested_id)
    theaters.find { |theater| theater.id.to_s == requested_id.to_s } || theaters.first
  end

  def schedules_for_theater(schedules, selected_theater)
    return [] unless selected_theater

    schedules.select { |schedule| schedule.screen.theater_id == selected_theater.id }
  end

  def available_dates_for(schedules)
    today = Time.zone.today

    schedules
      .filter_map { |schedule| schedule.start_time&.to_date }
      .select { |date| date >= today }
      .map(&:to_s)
      .uniq
      .sort
  end

  def select_schedules_for_date(schedules, requested_date, available_dates)
    requested = requested_date.presence
    return [nil, []] unless requested && available_dates.include?(requested)

    filtered = schedules.select do |schedule|
      schedule.start_time&.to_date&.to_s == requested
    end

    [requested, filtered]
  end

  def reservation_params_present?
    params[:schedule_id].present? && params[:date].present?
  end

  def theater_mismatch?(theater, requested_id)
    requested_id.present? && requested_id.to_i != theater.id
  end

  def assign_reservation_resources(schedule, date)
    @date = date
    @sheets = Sheet.where(screen_id: schedule.screen_id)
    @reserved_sheets = reserved_sheet_ids(schedule, date)
  end

  def reserved_sheet_ids(schedule, date)
    Reservation.where(
      schedule_id: schedule.id,
      date: date,
      screen_id: schedule.screen_id
    ).pluck(:sheet_id)
  end

  def redirect_missing_selection
    redirect_to movie_path(@movie, theater_id: params[:theater_id]),
                alert: 'スケジュールと日付を選択してください'
  end

  def redirect_unknown_schedule
    redirect_to movie_path(@movie, theater_id: params[:theater_id], date: params[:date]),
                alert: 'スケジュールが見つかりません'
  end

  def redirect_mismatched_theater
    redirect_to movie_path(@movie, theater_id: @theater.id, date: params[:date]),
                alert: '劇場の選択を確認してください'
  end
end
