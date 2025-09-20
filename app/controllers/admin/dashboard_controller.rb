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
      # 📊 管理者用の統計情報を取得
      @stats = {
        total_movies: Movie.count,
        showing_movies: Movie.where(is_showing: true).count,
        upcoming_movies: Movie.where(is_showing: false).count,
        total_schedules: Schedule.count,
        total_reservations: Reservation.count,
        today_reservations: Reservation.where(date: Date.current).count
      }
      
      # 📅 最近の予約（最新5件）
      @recent_reservations = Reservation
        .includes(:schedule, :sheet)
        .order(created_at: :desc)
        .limit(5)
      
      # 🎭 上映中の映画（最新3件）
      @showing_movies = Movie
        .where(is_showing: true)
        .order(created_at: :desc)
        .limit(3)
    end
  end
end