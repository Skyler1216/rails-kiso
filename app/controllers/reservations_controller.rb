class ReservationsController < ApplicationController
  before_action :authenticate_user!

  def new
    if params[:date].blank? || params[:sheet_id].blank?
      head :bad_request
      return
    end

    @movie = Movie.find(params[:movie_id])
    @schedule = Schedule.find(params[:schedule_id])
    @sheet = Sheet.find(params[:sheet_id])
    @date = params[:date]

    if Reservation.exists?(
      schedule_id: @schedule.id,
      date: @date,
      sheet_id: @sheet.id,
      screen_id: @schedule.screen_id
    )
      redirect_to reservation_movie_path(@movie, schedule_id: @schedule.id, date: @date), alert: "その座席はすでに予約済みです"
      return
    end

    @reservation = Reservation.new
  end

  def create
    @reservation = Reservation.new(reservation_params)
    
    # 🔽 current_user から情報を上書き
    @reservation.name = current_user.name
    @reservation.email = current_user.email
    @reservation.user = current_user  # ← user_id を紐づける

    if Reservation.exists?(
      date: @reservation.date,
      schedule_id: @reservation.schedule_id,
      sheet_id: @reservation.sheet_id,
      screen_id: @reservation.screen_id
    )
      redirect_to reservation_movie_path(
        @reservation.schedule.movie_id,
        schedule_id: @reservation.schedule_id,
        date: @reservation.date
      ), alert: "その座席はすでに予約済みです"
    elsif @reservation.save
      redirect_to movie_path(@reservation.schedule.movie_id), notice: "予約が完了しました"
    else
      puts @reservation.errors.full_messages

      @schedule = Schedule.find(@reservation.schedule_id)
      @movie = @schedule.movie
      @sheet = Sheet.find(@reservation.sheet_id)
      @date = @reservation.date

      flash.now[:alert] = "入力内容に誤りがあります"
      render :new, status: :unprocessable_entity
    end
  end

  private

  def reservation_params
    params.require(:reservation).permit(:name, :email, :schedule_id, :sheet_id, :date, :screen_id)
  end
end
