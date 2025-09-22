class Schedule < ApplicationRecord
  belongs_to :movie
  belongs_to :screen

  validate :end_time_after_start_time

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?
    return if end_time > start_time

    errors.add(:end_time, 'は開始時刻より後の時刻を指定してください')
  end
end
