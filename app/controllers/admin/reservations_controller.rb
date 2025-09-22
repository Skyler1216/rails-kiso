module Admin
  class ReservationsController < BaseController
    before_action :set_reservation, only: %i[show update destroy]
    before_action :ensure_reservation_upcoming, only: %i[show update]

    def index
      now = Time.zone.now
      scope = upcoming_reservation_scope(now)
      filtered = select_upcoming_reservations(scope, now)
      @reservations = sort_reservations(filtered, now)
    end

    def new
      @reservation = Reservation.new
      prepare_form_resources(@reservation.schedule_id)
    end

    def create
      @reservation = Reservation.new(reservation_params)
      prepare_form_resources(@reservation.schedule_id)

      schedule = find_schedule(@reservation.schedule_id)
      sheet = find_sheet(@reservation.sheet_id)

      validate_schedule_presence(schedule)
      validate_sheet_presence(sheet)

      if schedule && sheet
        validate_screen_match(schedule, sheet)
        assign_reservation_screen_and_date(@reservation, schedule, compute_reservation_date(schedule))
        validate_duplicate_seat(schedule, sheet, @reservation.date)
      end

      if @reservation.errors.any?
        return render_new_with_errors
      end

      if @reservation.save
        admin_flash_success('予約を作成しました')
        redirect_to admin_reservations_path
      else
        render_new_with_errors
      end
    end

    def show
      prepare_form_resources(@reservation.schedule_id)
    end

    def update
      schedule_id = reservation_params[:schedule_id]
      prepare_form_resources(schedule_id)

      schedule = find_schedule(schedule_id)
      sheet = find_sheet(reservation_params[:sheet_id])

      validate_schedule_presence(schedule)
      validate_sheet_presence(sheet)

      if schedule && sheet
        validate_screen_match(schedule, sheet)
        assign_reservation_screen_and_date(@reservation, schedule, compute_reservation_date(schedule, @reservation.date))
        validate_duplicate_seat(schedule, sheet, @reservation.date, exclude: @reservation.id)
      end

      if @reservation.errors.any?
        return render_edit_with_errors('❌ 入力内容に誤りがあります')
      end

      @reservation.assign_attributes(reservation_params.merge(date: @reservation.date))

      if @reservation.save
        admin_flash_success('予約を更新しました')
        redirect_to admin_reservations_path
      else
        render_edit_with_errors('❌ 入力内容に誤りがあります')
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

    def prepare_form_resources(schedule_id)
      now = Time.zone.now
      @schedules = Schedule.includes(:movie, :screen)
                           .where('schedules.end_time IS NULL OR schedules.end_time >= ?', now)
                           .order(:start_time)
      @sheets = Sheet.includes(:screen).order(:screen_id, :row, :column)

      selected_id = schedule_id.presence&.to_i
      @selected_schedule = selected_id && @schedules.find { |schedule| schedule.id == selected_id }

      @reserved_seat_map = build_reserved_seat_map(selected_id)

      @available_sheets =
        if @selected_schedule
          Sheet.where(screen_id: @selected_schedule.screen_id).order(:row, :column)
        else
          @sheets
        end
    end

    def build_reserved_seat_map(_selected_id)
      map = Hash.new { |h, k| h[k] = [] }

      schedule_dates = {}
      @schedules.each do |schedule|
        date = schedule.start_time&.in_time_zone&.to_date
        schedule_dates[schedule.id] = date if date
      end

      reservations = Reservation.where(schedule_id: schedule_dates.keys)

      reservations.find_each do |reservation|
        start_date = schedule_dates[reservation.schedule_id]
        next unless start_date && reservation.date == start_date

        map[reservation.schedule_id] << reservation.sheet_id
      end

      if @reservation&.persisted? && @reservation.sheet_id.present?
        map[@reservation.schedule_id] = map[@reservation.schedule_id] - [@reservation.sheet_id]
      end

      map
    end

    def upcoming_reservation_scope(now)
      Reservation
        .joins(:schedule)
        .includes(schedule: :movie, sheet: :screen)
        .where('reservations.date >= ?', now.to_date)
    end

    def select_upcoming_reservations(scope, now)
      scope.select do |reservation|
        start_at = occurrence_datetime(reservation)
        end_at = occurrence_datetime(reservation, :end_time)

        if end_at.present?
          end_at >= now
        elsif start_at.present?
          start_at >= now
        else
          true
        end
      end
    end

    def sort_reservations(reservations, now)
      reservations.sort_by do |reservation|
        sort_date = reservation.date || now.to_date
        start_at = occurrence_datetime(reservation)
        fallback_start = Time.zone.local(sort_date.year, sort_date.month, sort_date.day, 0, 0, 0)
        [sort_date, start_at || fallback_start]
      end
    end

    def find_schedule(id)
      return if id.blank?

      Schedule.find_by(id: id)
    end

    def find_sheet(id)
      return if id.blank?

      Sheet.find_by(id: id)
    end

    def validate_schedule_presence(schedule)
      return if schedule

      @reservation.errors.add(:schedule_id, '^上映スケジュールを選択してください')
    end

    def validate_sheet_presence(sheet)
      return if sheet

      @reservation.errors.add(:sheet_id, '^座席を選択してください')
    end

    def validate_screen_match(schedule, sheet)
      return if sheet.screen_id == schedule.screen_id

      @reservation.errors.add(:sheet_id, '^上映スケジュールのスクリーンから選択してください')
    end

    def validate_duplicate_seat(schedule, sheet, date, exclude: nil)
      return unless duplicate_reservation?(schedule, sheet, date, exclude: exclude)

      @reservation.errors.add(:sheet_id, '^その座席はすでに予約されています')
    end

    def compute_reservation_date(schedule, fallback = nil)
      schedule.start_time&.in_time_zone&.to_date || fallback || Time.zone.today
    end

    def assign_reservation_screen_and_date(reservation, schedule, date)
      reservation.date = date
      reservation.screen = schedule.screen
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

    def render_new_with_errors
      prepare_form_resources(@reservation.schedule_id)
      flash.now[:alert] = '❌ 入力内容に誤りがあります'
      render :new, status: :unprocessable_entity
    end

    def render_edit_with_errors(message)
      prepare_form_resources(@reservation.schedule_id)
      flash.now[:alert] = message
      render :show, status: :unprocessable_entity
    end
  end
end
