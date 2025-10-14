class Movie < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :year, presence: true
  validates :image_url, presence: true
  validates :running_minutes, numericality: { greater_than: 0, allow_nil: true, message: 'は1以上の数値で入力してください' }
  has_many :schedules, dependent: :destroy
  has_many :daily_movie_rankings, dependent: :destroy
end
