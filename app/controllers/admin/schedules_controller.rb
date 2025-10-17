module Admin
  class SchedulesController < BaseController
    # 管理画面の「上映スケジュール」を扱います。
    # 方針: 表示・集計ロジックは小さなプライベートメソッドに分割し、
    #       読みやすさとテスト容易性を高めています。
    # データ構造: Schedule は Movie と Screen に紐づく。Screen は Theater に属するため、
    #             劇場情報は Screen 経由で取得します。

    # 一覧表示
    def index
      now = Time.zone.now
      @now = now
      # 劇場フィルタ用の選択肢（プルダウン）
      @theaters = Theater.order(:id)
      # クエリパラメータ `?theater_id=...` を受け取り、選択中の劇場を特定
      @selected_theater_id = params[:theater_id].presence
      @selected_theater = @theaters.find { |theater| theater.id.to_s == @selected_theater_id } if @selected_theater_id

      # 一覧の基礎スコープ
      # - includes(:movie, screen: :theater): 一覧表示に必要な関連を先読み（N+1回避）
      # - order(:start_time): 時刻順に並べる
      base_scope = Schedule.includes(:movie, screen: :theater).order(:start_time)
      # 劇場が選ばれている場合は、該当劇場に属するスクリーンのスケジュールだけに絞り込み
      base_scope = base_scope.where(screens: { theater_id: @selected_theater_id }) if @selected_theater_id

      # 「終了済みは下、未開始/進行中は上」に並び替え（二段階ソート）
      ordered_scope = base_scope.to_a
      @all_schedules = reorder_schedules(ordered_scope, now)

      # 作品ごとのまとまりと、画面上部の集計値を用意
      @movies, @movie_schedules = build_movie_index(@all_schedules, now)
      @schedule_stats = build_schedule_stats(@all_schedules, @movies, now)
    end

    # 編集フォーム表示
    def show
      @schedule = Schedule.find(params[:id])
      @movie = @schedule.movie
      # 劇場→スクリーンの順で一覧したいので、theater を同時ロードし、劇場ID→スクリーンIDで並べる
      @screens = Screen.includes(:theater).order('theater_id ASC, screens.id ASC')
    end

    # 新規作成フォーム表示
    # - URLクエリで渡された初期値（movie_id/screen_id）を反映
    # - 作品一覧(@movies)と、劇場付きのスクリーン一覧(@screens)をフォーム選択肢として用意
    def new
      defaults = params.permit(:movie_id, :screen_id)
      @schedule = Schedule.new(defaults)
      @movies = Movie.order(:id)
      # スクリーン一覧の取得方法
      # - includes(:theater): 劇場データを一緒に取得（N+1クエリの発生を防ぐための事前読み込み）
      # - order('theater_id ASC, screens.id ASC'):
      #     劇場ごとにまとまって表示される（セレクトボックスで「劇場名 → スクリーン」の順に並ぶ）
      #     同じ劇場内ではスクリーンIDの昇順で安定ソート
      @screens = Screen.includes(:theater).order('theater_id ASC, screens.id ASC')
    end

    # 新規作成フォーム送信（作成処理）
    # - Strong Parameters（schedule_create_params）からScheduleを生成
    # - 成功時は一覧へ、失敗時は同じ候補リスト(@movies/@screens)を再表示
    def create
      @schedule = Schedule.new(schedule_create_params)
      if @schedule.save
        redirect_to admin_schedules_path, notice: 'スケジュールを作成しました'
      else
        @movies = Movie.order(:id)
        # フォーム再表示時も同じスクリーン一覧を再構築
        # - includes(:theater) で劇場名をラベルに使える
        # - 劇場→スクリーンの順でグルーピングされ、UXが一定
        @screens = Screen.includes(:theater).order('theater_id ASC, screens.id ASC')
        # バリデーション失敗時も同じ選択肢を再表示できるよう再ロード
        render :new, status: :unprocessable_entity
      end
    end

    # 編集フォームの送信（更新）
    def update
      @schedule = Schedule.find(params[:id])
      if @schedule.update(schedule_update_params)
        redirect_to admin_schedules_path, notice: 'スケジュールを更新しました'
      else
        @movie = @schedule.movie
        # 詳細画面の再表示時も、セレクトの内容と順番を統一
        # - 事前読み込みでパフォーマンス最適化
        # - 劇場→スクリーンの順で並ぶため、選択しやすい
        @screens = Screen.includes(:theater).order('theater_id ASC, screens.id ASC')
        # エラー時の再表示でも theater を含めて並び順を統一
        render :show, status: :unprocessable_entity
      end
    end

    # スケジュール削除
    def destroy
      @schedule = Schedule.find(params[:id])
      @schedule.destroy
      redirect_to admin_schedules_path, notice: 'スケジュールを削除しました'
    end

    private

    # 全スケジュールを「終了済みを下・未開始/進行中を上」に並べ替える
    # 作品ごとにスケジュールをグルーピングし、各グループ内も同じ規則で並べ替える
    def build_movie_index(all_schedules, now)
      movies = all_schedules.filter_map(&:movie).uniq.sort_by(&:id)
      movie_schedules = movies.index_with do |movie|
        schedules = all_schedules.select { |schedule| schedule.movie_id == movie.id }
        reorder_schedules(schedules, now)
      end
      [movies, movie_schedules]
    end

    # 集計値を作成（総スケジュール数、作品数、今上映中、本日、今週）
    def build_schedule_stats(all_schedules, movies, now)
      today = Time.zone.today
      {
        total_schedules: all_schedules.size,
        total_movies: movies.size,
        playing_now: count_playing_now(all_schedules, now),
        today: count_today(all_schedules, today),
        this_week: count_this_week(all_schedules, today)
      }
    end

    # ── 以下は小さな述語/集計関数（読みやすさと再利用性のため）
    def count_playing_now(schedules, now)
      schedules.count { |s| playing_now?(s, now) }
    end

    def count_today(schedules, today)
      schedules.count { |s| starts_on?(s, today) }
    end

    def count_this_week(schedules, today)
      schedules.count { |s| starts_in_week?(s, today) }
    end

    def playing_now?(schedule, now)
      schedule.start_time && schedule.end_time && schedule.start_time <= now && schedule.end_time >= now
    end

    def starts_on?(schedule, day)
      schedule.start_time && schedule.start_time.to_date == day
    end

    def starts_in_week?(schedule, day)
      schedule.start_time && (day..day + 6.days).cover?(schedule.start_time.to_date)
    end

    def reorder_schedules(schedules, now)
      schedules.sort_by do |schedule|
        [schedule_finished?(schedule, now) ? 1 : 0, schedule.start_time || Time.zone.at(0)]
      end
    end

    def schedule_finished?(schedule, now)
      schedule.end_time.present? && schedule.end_time < now
    end

    def schedule_update_params
      params.require(:schedule).permit(:start_time, :end_time, :screen_id)
    end

    def schedule_create_params
      params.require(:schedule).permit(:movie_id, :screen_id, :start_time, :end_time)
    end
  end
end
