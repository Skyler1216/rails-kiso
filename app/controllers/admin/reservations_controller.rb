# app/controllers/admin/reservations_controller.rb

class Admin::ReservationsController < ApplicationController
    # def index
    #   @reservations = Reservation
    #                     .includes(:schedule, :sheet)
    #                     .where("schedules.start_time >= ?", Time.current)
    #                     .references(:schedule)
    #                     .order("schedules.start_time ASC")
    # end
    def index
        @reservations = Reservation.includes(:schedule, :sheet).order("schedules.start_time ASC")
    end

    def new
      @reservation = Reservation.new
    end

    # def create
    #   @reservation = Reservation.new(reservation_params)

    #   if Reservation.exists?(
    #        schedule_id: @reservation.schedule_id,
    #        date: @reservation.date,
    #        sheet_id: @reservation.sheet_id
    #      )
    #     redirect_to admin_reservations_path, alert: "その座席はすでに予約済みです"
    #   elsif @reservation.save
    #     redirect_to admin_reservations_path, notice: "予約を登録しました"
    #   else
    #     redirect_to admin_reservations_path, alert: "入力内容に誤りがあります"
    #   end
    # end
    def create
        @reservation = Reservation.new(reservation_params)

        if Reservation.exists?(
            date: @reservation.date,
            schedule_id: @reservation.schedule_id,
            sheet_id: @reservation.sheet_id
          )
          flash[:alert] = "その座席はすでに予約済みです"
          render :new, status: :bad_request
        elsif @reservation.save
          redirect_to admin_reservations_path
        else
          flash[:alert] = "入力内容に誤りがあります"
          render :new, status: :bad_request
        end
    end

    def show
      @reservation = Reservation.find(params[:id])
    end

    def update
      @reservation = Reservation.find(params[:id])

      if Reservation.where.not(id: @reservation.id).exists?(
           schedule_id: reservation_params[:schedule_id],
           date: reservation_params[:date],
           sheet_id: reservation_params[:sheet_id]
         )
        redirect_to admin_reservation_path(@reservation), alert: "その座席はすでに予約済みです"
      elsif @reservation.update(reservation_params)
        redirect_to admin_reservations_path, notice: "予約を更新しました"
      else
        redirect_to admin_reservations_path, alert: "入力内容に誤りがあります"
      end
    end

    def destroy
      @reservation = Reservation.find(params[:id])
      @reservation.destroy
      redirect_to admin_reservations_path, notice: "予約を削除しました"
    end

    private

    def reservation_params
      params.require(:reservation).permit(:schedule_id, :sheet_id, :date, :name, :email)
    end
  end
