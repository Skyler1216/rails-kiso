class Schedule < ApplicationRecord
  belongs_to :movie
  belongs_to :screen
  has_many :reservations, dependent: :destroy

  validates :start_time, presence: { message: :blank }
  validates :end_time, presence: { message: :blank }
  validate :end_time_after_start_time
  validate :no_overlapping_schedule

  after_update :sync_reservation_metadata!

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, 'は開始時刻より後の時刻を指定してください')
  end

  def sync_reservation_metadata!
    return unless saved_change_to_start_time? || saved_change_to_screen_id?

    reservations.find_each do |reservation|
      updates = {}

      updates[:date] = start_time.in_time_zone.to_date if saved_change_to_start_time? && start_time.present?

      updates[:screen_id] = screen_id if saved_change_to_screen_id?

      next if updates.empty?

      updates[:updated_at] = Time.current
      reservation.update_columns(updates)
    end
  end

  def no_overlapping_schedule
    return if start_time.blank? || end_time.blank? || screen_id.blank?

    overlap_exists = Schedule
                      .where(screen_id: screen_id)
                      .where.not(id: id)
                      .where('start_time < ? AND end_time > ?', end_time, start_time)
                      .exists?

    return unless overlap_exists

    errors.add(:base, '同じスクリーンで日程が重複しています')
  end
end
