module Admin
  module ReservationValidation
    def ensure_schedule_and_sheet(schedule_id, sheet_id, date_fallback: nil, duplicate_exclude: nil)
      schedule = find_schedule(schedule_id)
      sheet = find_sheet(sheet_id)

      validate_schedule_presence(schedule)
      validate_sheet_presence(sheet)
      return unless schedule && sheet

      validate_screen_match(schedule, sheet)
      assign_reservation_screen_and_date(@reservation, schedule,
                                         compute_reservation_date(schedule, date_fallback))
      validate_duplicate_seat(schedule, sheet, @reservation.date, exclude: duplicate_exclude)
    end

    private

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
  end
end
