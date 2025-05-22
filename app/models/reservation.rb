class Reservation < ApplicationRecord
  belongs_to :schedule
  belongs_to :sheet

  validates :name, presence: true
  # validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :date, presence: true
  # app/models/reservation.rb

VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

validates :email, presence: true, format: { with: VALID_EMAIL_REGEX }

end
