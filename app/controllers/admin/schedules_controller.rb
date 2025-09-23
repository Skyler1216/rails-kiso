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

      # 一覧用データの用意
      # 1) 全スケジュールを「終了済みを下・未開始/進行中を上」に並び替え
      @all_schedules = sorted_schedules(now)
      # 2) 作品ごとのまとまり（movie => schedules[]）を構築
      @movies, @movie_schedules = build_movie_index(@all_schedules, now)
      # 3) 集計（総件数/本日/今週/上映中）
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
      # スクリーン選択のプルダウンで劇場名も表示できるよう、theater を同時ロード
      @screens = Screen.includes(:theater).order('theater_id ASC, screens.id ASC')
    end

    # フォーム送信（作成処理）
    # - Strong Parameters（schedule_create_params）からScheduleを生成
    # - 成功時は一覧へ、失敗時は同じ候補リスト(@movies/@screens)を再表示
    def create
      @schedule = Schedule.new(schedule_create_params)
      if @schedule.save
        redirect_to admin_schedules_path, notice: 'スケジュールを作成しました'
      else
        @movies = Movie.order(:id)
        # バリデーション失敗時も同じ選択肢を再表示できるよう再ロード
        @screens = Screen.includes(:theater).order('theater_id ASC, screens.id ASC')
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
        # エラー時の再表示でも theater を含めて並び順を統一
        @screens = Screen.includes(:theater).order('theater_id ASC, screens.id ASC')
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
    def sorted_schedules(now)
      Schedule.includes(:movie, :screen)
              .order(:start_time)
              .to_a
              .then { |list| reorder_schedules(list, now) }
    end

    # 作品ごとにスケジュールをグルーピングし、各グループ内も同じ規則で並べ替える
    def build_movie_index(all_schedules, now)
      movies = Movie.includes(schedules: :screen)
                    .where(id: all_schedules.map(&:movie_id).uniq)
                    .order(:id)
      movie_schedules = movies.index_with { |movie| reorder_schedules(movie.schedules, now) }
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
      schedules.sort_by { |schedule| [schedule_finished?(schedule, now) ? 1 : 0, schedule.start_time || Time.zone.at(0)] }
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
