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
  # ============================================================================
  # load_popular_rankings-人気ランキングデータ読み込みメソッド
  # ============================================================================
  # 映画のランキングデータを取得して、トップページに表示するためのメソッドです。
  #
  # 【処理の流れ】
  # 1. まず今日のランキングデータを探す
  # 2. 今日のデータがない場合は、最新のデータを探す
  # 3. 見つかったデータをビューで使えるように準備する
  # ============================================================================
  def load_popular_rankings
    # ============================================================================
    # ステップ1：データ取得の準備
    # ============================================================================
    # DailyMovieRankingモデルからデータを取得する準備をします。
    # includes(:movie)により、映画の詳細情報も一緒に取得します。N+1問題を回避します。
    # これにより、ビューで映画名や画像を表示する際に、データベースに何度もアクセスする必要がなくなります。
    query = DailyMovieRanking.includes(:movie)

    # ============================================================================
    # ステップ2：今日のランキングデータを取得
    # ============================================================================
    # 今日の日付を取得（例：2024-01-15）
    ranking_date = Time.zone.today

    # 今日の日付でランキングデータを検索します。
    # where(aggregated_on: ranking_date)：今日の日付のデータのみを取得
    # order(:rank_position)：順位順でソート（1位、2位、3位...の順）
    # limit(RANKING_LIMIT)：表示する件数を制限（例：上位10件のみ）
    rankings = query.where(aggregated_on: ranking_date).order(:rank_position).limit(RANKING_LIMIT)

    # ============================================================================
    # ステップ3：今日のデータがない場合の代替処理
    # ============================================================================
    # 今日のランキングデータが存在しない場合（例：まだ集計が完了していない）の処理です。
    if rankings.empty?
      # データベースに保存されている最新のランキング日付を取得
      # maximum(:aggregated_on)：aggregated_onカラムの最大値（最新の日付）を取得
      latest_date = DailyMovieRanking.maximum(:aggregated_on)

      # 最新データが存在し、かつ今日の日付と異なる場合の処理
      # 例：今日が1月15日だが、最新データが1月14日の場合
      if latest_date.present? && latest_date != ranking_date
        # 最新の日付のランキングデータを取得
        rankings = query.where(aggregated_on: latest_date).order(:rank_position).limit(RANKING_LIMIT)

        # データが取得できた場合のみ、ランキング日付を更新
        ranking_date = latest_date if rankings.present?
      end
    end

    # ============================================================================
    # ステップ4：ビューで使用するデータの準備
    # ============================================================================
    # 取得したランキングデータをビュー（画面）で使用できるように設定します。
    # @マークが付いた変数は「インスタンス変数」と呼ばれ、コントローラーからビューにデータを渡すために使用します。

    # ランキングデータをビューに渡す
    @movie_rankings = rankings

    # ランキングの日付をビューに渡す（データが存在する場合のみ）
    # present?：データが存在するかどうかをチェックするメソッド
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
