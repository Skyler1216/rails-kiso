module Admin
  class ReservationsController < BaseController
    before_action :set_reservation, only: %i[show update destroy]
    before_action :ensure_reservation_upcoming, only: %i[show update]
    before_action :prepare_form_resources, only: %i[new show]

    def index
      now = Time.zone.now
      scope = upcoming_reservation_scope(now)
      filtered = select_upcoming_reservations(scope, now)
      @reservations = sort_reservations(filtered, now)
    end

    def new
      @reservation = Reservation.new
    end

    def create
      @reservation = Reservation.new(reservation_params)
      schedule, sheet = find_schedule_and_sheet(@reservation.schedule_id, @reservation.sheet_id)
      return redirect_to(admin_reservations_path) unless validate_schedule_and_sheet(schedule, sheet)

      date = compute_reservation_date(schedule, Time.zone.today)
      assign_reservation_screen_and_date(@reservation, schedule, date)
      return redirect_to(admin_reservations_path) if duplicate_and_alert?(schedule, sheet, date)

      failure_msg = @reservation.errors.full_messages.to_sentence.presence || '入力内容に誤りがあります'
      save_with_flash(@reservation, '予約を作成しました', failure_msg)
      redirect_to admin_reservations_path
    end

    def show; end

    def update
      schedule, sheet = find_schedule_and_sheet(reservation_params[:schedule_id], reservation_params[:sheet_id])
      return render_invalid(:show) unless validate_schedule_and_sheet(schedule, sheet, now: true)

      date = compute_reservation_date(schedule, @reservation.date)
      if duplicate_reservation?(schedule, sheet, date, exclude: @reservation.id)
        return render_with_alert(:show, '❌ その座席はすでに予約済みです')
      end

      assign_reservation_screen_and_date(@reservation, schedule, date)
      @reservation.assign_attributes(reservation_params.merge(date: date))

      if @reservation.save
        admin_flash_success('予約を更新しました')
        redirect_to admin_reservations_path
      else
        render_with_alert(:show, '❌ 入力内容に誤りがあります')
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

      @available_sheets = if action_name == 'show'
                            Sheet.where(screen_id: @reservation.screen_id)
                                 .order(:row, :column)
                          else
                            @sheets
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

      finished =
        if end_at.present?
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

private

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

def find_schedule_and_sheet(schedule_id, sheet_id)
  [Schedule.find_by(id: schedule_id), Sheet.find_by(id: sheet_id)]
end

def validate_schedule_and_sheet(schedule, sheet, now: false)
  unless schedule && sheet
    return render_with_alert(:show, '❌ 入力内容に誤りがあります') if now

    admin_flash_error('入力内容に誤りがあります')
    return false
  end

  if sheet.screen_id != schedule.screen_id
    return render_with_alert(:show, '❌ 選択した座席は上映スクリーンと一致しません') if now

    admin_flash_error('選択した座席は上映スクリーンと一致しません')
    return false
  end
  true
end

def render_invalid(view)
  prepare_form_resources
  flash.now[:alert] = '❌ 入力内容に誤りがあります'
  render view, status: :unprocessable_entity
end

def render_with_alert(view, message)
  prepare_form_resources
  flash.now[:alert] = message
  render view, status: :unprocessable_entity
end

def compute_reservation_date(schedule, fallback)
  schedule.start_time&.in_time_zone&.to_date || fallback
end

def assign_reservation_screen_and_date(reservation, schedule, date)
  reservation.date = date
  reservation.screen = schedule.screen
end

def duplicate_and_alert?(schedule, sheet, date)
  if duplicate_reservation?(schedule, sheet, date)
    admin_flash_error('その座席はすでに予約済みです')
    return true
  end
  false
end

def save_with_flash(record, success_message, failure_message)
  if record.save
    admin_flash_success(success_message)
  else
    admin_flash_error(failure_message)
  end
end
