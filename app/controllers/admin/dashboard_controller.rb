module Admin
  class DashboardController < BaseController
    # ============================================================================
    # 🎬 管理者ダッシュボード
    # ============================================================================
    # 管理者専用のトップページです。
    # システム全体の統計情報と最近の活動を一覧表示します。
    #
    # 表示内容:
    # - 映画・スケジュール・予約・劇場の統計情報
    # - 今後の上映スケジュール
    # - 今後の予約一覧
    # - 最近更新された映画・劇場
    # ============================================================================

    # ----------------------------------------------------------------------------
    # ダッシュボード表示
    # ----------------------------------------------------------------------------
    def index
      # 現在の日時を取得
      today = Date.current
      now = Time.zone.now

      # ダッシュボードに表示する各種データを構築
      @stats = build_dashboard_stats(today)
      @upcoming_schedules = next_schedules(now)
      @upcoming_reservations = next_reservations(today)
      @recent_movies = recent_movies
      @recent_theaters = recent_theaters
    end

    # ----------------------------------------------------------------------------
    # プライベートメソッド
    # ----------------------------------------------------------------------------
    private

    # ダッシュボード統計情報の構築
    def build_dashboard_stats(today)
      {
        # 映画の統計
        movies: {
          total: Movie.count,                                    # 全映画数
          showing: Movie.where(is_showing: true).count,         # 上映中
          upcoming: Movie.where(is_showing: false).count        # 上映予定
        },
        # スケジュールの統計
        schedules: {
          total: Schedule.count,                                 # 全スケジュール数
          today: Schedule.where(start_time: today.all_day).count, # 今日の上映
          upcoming: Schedule.where('start_time >= ?', today.beginning_of_day).count # 今後の上映
        },
        # 予約の統計
        reservations: {
          total: Reservation.count,                              # 全予約数
          today: Reservation.where(date: today).count,          # 今日の予約
          upcoming: Reservation.where('date > ?', today).count  # 今後の予約
        },
        # 劇場の統計
        theaters: {
          total: Theater.count,                                  # 全劇場数
          active: Theater.where(is_active: true).count,         # アクティブ
          inactive: Theater.where(is_active: false).count       # 非アクティブ
        }
      }
    end

    # 今後の上映スケジュールを取得
    def next_schedules(now)
      Schedule.includes(:movie, screen: :theater)
              .where('start_time IS NOT NULL AND start_time >= ?', now)
              .order(:start_time)
              .limit(5)
    end

    # 今後の予約一覧を取得
    def next_reservations(today)
      Reservation.joins(:schedule)
                 .includes(:user, :sheet, schedule: [:movie, { screen: :theater }])
                 .where('reservations.date >= ?', today)
                 .order(Arel.sql('reservations.date ASC, schedules.start_time IS NULL ASC, schedules.start_time ASC'))
                 .limit(5)
    end

    # 最近更新された映画を取得
    def recent_movies
      Movie.order(updated_at: :desc).limit(5)
    end

    # 最近更新された劇場を取得
    def recent_theaters
      Theater.order(updated_at: :desc).limit(5)
    end
  end
end
