module Admin
  module ReservationFormSupport
    def prepare_form_resources(schedule_id)
      now = Time.zone.now
      @schedule_start_dates = nil

      @schedules = Schedule.includes(:movie, screen: :theater)
                           .where('schedules.end_time IS NULL OR schedules.end_time >= ?', now)
                           .order(:start_time)

      @sheets = Sheet.includes(screen: :theater).order(:screen_id, :row, :column)

      selected_id = schedule_id.presence&.to_i
      @selected_schedule = selected_id && @schedules.find { |schedule| schedule.id == selected_id }

      @reserved_seat_map = build_reserved_seat_map(selected_id)

      @available_sheets =
        if @selected_schedule
          Sheet.includes(screen: :theater).where(screen_id: @selected_schedule.screen_id).order(:row, :column)
        else
          @sheets
        end
    end

    def build_reserved_seat_map(_selected_id)
      map = reservations_grouped_by_schedule
      remove_current_reservation_sheet(map)
    end

    def upcoming_reservation_scope(now)
      Reservation
        .joins(schedule: :screen)
        .includes(schedule: [:movie, { screen: :theater }], sheet: { screen: :theater })
        .where('reservations.date >= ?', now.to_date)
    end

    def select_upcoming_reservations(scope, now)
      scope.select { |reservation| upcoming_reservation?(reservation, now) }
    end

    def locate_selected_theater(theaters, theater_id_param)
      theater_id = theater_id_param.to_s.strip
      return nil if theater_id.blank?

      theaters.find { |theater| theater.id.to_s == theater_id }
    end

    def sort_reservations(reservations, now)
      reservations.sort_by do |reservation|
        sort_date = reservation.date || now.to_date
        start_at = occurrence_datetime(reservation)
        fallback_start = Time.zone.local(sort_date.year, sort_date.month, sort_date.day, 0, 0, 0)
        [sort_date, start_at || fallback_start]
      end
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

    def upcoming_reservation?(reservation, now)
      end_at = occurrence_datetime(reservation, :end_time)
      return end_at >= now if end_at.present?

      start_at = occurrence_datetime(reservation)
      return start_at >= now if start_at.present?

      true
    end

    private

    def reservations_grouped_by_schedule
      schedule_dates = schedule_start_dates

      Reservation.where(schedule_id: schedule_dates.keys)
                 .find_each
                 .with_object(Hash.new { |h, k| h[k] = [] }) do |reservation, map|
        start_date = schedule_dates[reservation.schedule_id]
        next unless start_date && reservation.date == start_date

        map[reservation.schedule_id] << reservation.sheet_id
      end
    end

    def schedule_start_dates
      @schedule_start_dates ||= @schedules.each_with_object({}) do |schedule, hash|
        date = reservation_start_date(schedule)
        hash[schedule.id] = date if date
      end
    end

    def reservation_start_date(schedule)
      schedule.start_time&.in_time_zone&.to_date
    end

    def remove_current_reservation_sheet(map)
      return map unless @reservation&.persisted? && @reservation.sheet_id.present?

      map[@reservation.schedule_id] = map[@reservation.schedule_id] - [@reservation.sheet_id]
      map
    end
  end
end
