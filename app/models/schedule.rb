class Schedule < ApplicationRecord
  belongs_to :movie
  belongs_to :screen
  has_many :reservations, dependent: :destroy

  validate :end_time_after_start_time

  after_update :sync_reservation_dates!, if: :saved_change_to_start_time?

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, 'は開始時刻より後の時刻を指定してください')
  end

  def sync_reservation_dates!
    return if start_time.blank?

    new_date = start_time.in_time_zone.to_date
    reservations.find_each do |reservation|
      reservation.update_columns(date: new_date, updated_at: Time.current)
    end
  end
end
