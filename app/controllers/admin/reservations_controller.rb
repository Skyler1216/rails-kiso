module Admin
  class ReservationsController < BaseController
    before_action :set_reservation, only: %i[show update destroy]
    before_action :ensure_reservation_upcoming, only: %i[show update]
    before_action :prepare_form_resources, only: %i[new show]

    def index
      now = Time.zone.now
      scope = Reservation
              .joins(:schedule)
              .includes(schedule: :movie, sheet: :screen)
              .where('reservations.date >= ?', now.to_date)

      @reservations = scope.select do |reservation|
        start_at = occurrence_datetime(reservation)
        end_at = occurrence_datetime(reservation, :end_time)

        if end_at.present?
          end_at >= now
        elsif start_at.present?
          start_at >= now
        else
          true
        end
      end.sort_by do |reservation|
        sort_date = reservation.date || now.to_date
        start_at = occurrence_datetime(reservation)
        fallback_start = Time.zone.local(sort_date.year, sort_date.month, sort_date.day, 0, 0, 0)
        [sort_date, start_at || fallback_start]
      end
    end

    def new
      @reservation = Reservation.new
    end

    def create
      @reservation = Reservation.new(reservation_params)
      schedule = Schedule.find_by(id: @reservation.schedule_id)
      sheet = Sheet.find_by(id: @reservation.sheet_id)

      unless schedule && sheet
        admin_flash_error('入力内容に誤りがあります')
        redirect_to admin_reservations_path and return
      end

      if sheet.screen_id != schedule.screen_id
        admin_flash_error('選択した座席は上映スクリーンと一致しません')
        redirect_to admin_reservations_path and return
      end

      reservation_date = schedule.start_time&.in_time_zone&.to_date || Time.zone.today
      @reservation.date = reservation_date
      @reservation.screen = schedule.screen

      if duplicate_reservation?(schedule, sheet, reservation_date)
        admin_flash_error('その座席はすでに予約済みです')
        redirect_to admin_reservations_path and return
      end

      if @reservation.save
        admin_flash_success('予約を作成しました')
        redirect_to admin_reservations_path
      else
        admin_flash_error(@reservation.errors.full_messages.to_sentence.presence || '入力内容に誤りがあります')
        redirect_to admin_reservations_path
      end
    end

    def show; end

    def update
      schedule = Schedule.find_by(id: reservation_params[:schedule_id])
      sheet = Sheet.find_by(id: reservation_params[:sheet_id])

      unless schedule && sheet
        prepare_form_resources
        flash.now[:alert] = '❌ 入力内容に誤りがあります'
        render :show, status: :unprocessable_entity and return
      end

      if sheet.screen_id != schedule.screen_id
        prepare_form_resources
        flash.now[:alert] = '❌ 選択した座席は上映スクリーンと一致しません'
        render :show, status: :unprocessable_entity and return
      end

      reservation_date = schedule.start_time&.in_time_zone&.to_date || @reservation.date

      if duplicate_reservation?(schedule, sheet, reservation_date, exclude: @reservation.id)
        prepare_form_resources
        flash.now[:alert] = '❌ その座席はすでに予約済みです'
        render :show, status: :unprocessable_entity and return
      end

      @reservation.assign_attributes(reservation_params.merge(date: reservation_date))
      @reservation.screen = schedule.screen

      if @reservation.save
        admin_flash_success('予約を更新しました')
        redirect_to admin_reservations_path
      else
        prepare_form_resources
        flash.now[:alert] = '❌ 入力内容に誤りがあります'
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      @reservation.destroy
      admin_flash_success('予約を削除しました')
      redirect_to admin_reservations_path
    end

    private

    def reservation_params
      params.require(:reservation).permit(:name, :email, :schedule_id, :sheet_id)
    end

    def set_reservation
      @reservation = Reservation.find(params[:id])
    end

    def prepare_form_resources
      @movies = Movie.order(:name)
      now = Time.zone.now
      @schedules = Schedule.includes(:movie, :screen)
                           .where('schedules.end_time IS NULL OR schedules.end_time >= ?', now)
                           .order(:start_time)
      @sheets = Sheet.includes(:screen).order(:screen_id, :row, :column)

      if action_name == 'show'
        @available_sheets = Sheet.where(screen_id: @reservation.screen_id)
                                  .order(:row, :column)
      else
        @available_sheets = @sheets
      end
    end

    def duplicate_reservation?(schedule, sheet, date, exclude: nil)
      scope = Reservation.where(
        schedule_id: schedule.id,
        sheet_id: sheet.id,
        date: date,
        screen_id: schedule.screen_id
      )
      scope = scope.where.not(id: exclude) if exclude
      scope.exists?
    end

    def occurrence_datetime(reservation, attribute = :start_time)
      schedule = reservation.schedule
      time_value = schedule&.public_send(attribute)
      return unless time_value.present? && reservation.date.present?

      time = time_value.in_time_zone
      Time.zone.local(
        reservation.date.year,
        reservation.date.month,
        reservation.date.day,
        time.hour,
        time.min,
        time.sec
      )
    end

    def ensure_reservation_upcoming
      now = Time.zone.now
      start_at = occurrence_datetime(@reservation)
      end_at = occurrence_datetime(@reservation, :end_time)

      finished = if end_at.present?
                   end_at < now
                 elsif start_at.present?
                   start_at < now
                 else
                   false
                 end

      return unless finished

      admin_flash_error('終了した予約は編集できません')
      redirect_to admin_reservations_path
    end
  end
end
