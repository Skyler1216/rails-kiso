class Movie < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :year, presence: true
  validates :image_url, presence: true
  has_many :schedules, dependent: :destroy
end
