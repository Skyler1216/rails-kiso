class Reservation < ApplicationRecord
  belongs_to :schedule
  belongs_to :sheet
  belongs_to :screen

  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  validates :name, presence: true
  validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }
  validates :date, presence: true

  validates :sheet_id, uniqueness: {
    scope: [:schedule_id, :date, :screen_id],
    message: 'はすでに予約されています'
  }
end
