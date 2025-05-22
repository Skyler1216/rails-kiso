class MoviesController < ApplicationController
  def index
    @movies = Movie.all
  
    if params[:is_showing].present?
      @movies = @movies.where(is_showing: params[:is_showing])
    end
  
    if params[:keyword].present?
      keyword = params[:keyword]
      @movies = @movies.where("name LIKE :q OR description LIKE :q", q: "%#{keyword}%")
    end
  end
  
  def show
    @movie = Movie.find(params[:id])
    @schedules = @movie.schedules.order(:start_time)
  
    available_dates = @schedules
                        .map { |s| s.start_time.to_date }
                        .select { |d| d >= Date.today && d <= Date.today + 6 }
                        .uniq
  
    selected_date = params[:date].presence || available_dates.first
    @filtered_schedules = @schedules.select { |s| s.start_time.to_date.to_s == selected_date.to_s }
    @selected_date = selected_date
  end
  

  def reservation
    @movie = Movie.find(params[:id])
  
    # クエリが不足していたらリダイレクト
    unless params[:schedule_id].present? && params[:date].present?
      return redirect_to movie_path(@movie), alert: "スケジュールと日付を選択してください"
    end
  
    @schedule = Schedule.find_by(id: params[:schedule_id])
    unless @schedule
      return redirect_to movie_path(@movie), alert: "スケジュールが見つかりません"
    end
  
    @date = params[:date]
  
    # 座席一覧（全件）
    @sheets = Sheet.all
  
    # 予約済み座席のid一覧（この日付・スケジュールに対して）
    @reserved_sheets = Reservation.where(
      schedule_id: @schedule.id,
      date: @date
    ).pluck(:sheet_id)
  end
  

end
