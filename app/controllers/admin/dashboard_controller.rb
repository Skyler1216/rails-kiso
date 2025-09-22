module Admin
  class DashboardController < BaseController
    # ========================================
    # 🎬 管理者ダッシュボード
    # ========================================
    #
    # 管理者専用のトップページ
    # - 映画管理
    # - スケジュール管理
    # - 予約管理
    # へのクイックアクセス
    #

    def index
      today = Date.current
      now = Time.zone.now

      @stats = build_dashboard_stats(today)
      @upcoming_schedules = next_schedules(now)
      @upcoming_reservations = next_reservations(today)
      @recent_movies = recent_movies
    end
  end
end

private

def build_dashboard_stats(today)
  {
    movies: {
      total: Movie.count,
      showing: Movie.where(is_showing: true).count,
      upcoming: Movie.where(is_showing: false).count
    },
    schedules: {
      total: Schedule.count,
      today: Schedule.where(start_time: today.all_day).count,
      upcoming: Schedule.where('start_time >= ?', today.beginning_of_day).count
    },
    reservations: {
      total: Reservation.count,
      today: Reservation.where(date: today).count,
      upcoming: Reservation.where('date > ?', today).count
    }
  }
end

def next_schedules(now)
  Schedule.includes(:movie, :screen)
          .where('start_time IS NOT NULL AND start_time >= ?', now)
          .order(:start_time)
          .limit(5)
end

def next_reservations(today)
  Reservation.joins(:schedule)
             .includes(schedule: %i[movie screen], sheet: :screen)
             .where('reservations.date >= ?', today)
             .order(Arel.sql('reservations.date ASC, schedules.start_time IS NULL ASC, schedules.start_time ASC'))
             .limit(5)
end

def recent_movies
  Movie.order(updated_at: :desc).limit(5)
end
