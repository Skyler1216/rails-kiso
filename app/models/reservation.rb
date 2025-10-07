class Reservation < ApplicationRecord
  belongs_to :schedule
  belongs_to :sheet
  belongs_to :screen
  belongs_to :user, optional: true

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  validates :name, presence: true
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }
  validates :date, presence: true

  validates :sheet_id, uniqueness: {
    scope: %i[schedule_id date screen_id],
    message: 'はすでに予約されています'
  }

  scope :on_date, ->(target_date) { where(date: target_date) }

  # 指定した上映日に紐づく予約をリマインダー送信用に取得する
  def self.upcoming_for(target_date)
    includes(:sheet, { screen: :theater }, { schedule: :movie })
      .on_date(target_date.to_date)
  end
end
