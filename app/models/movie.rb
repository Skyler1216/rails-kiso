class Movie < ApplicationRecord
    validates :name, presence: true, uniqueness: true
    validates :year, presence: true
    has_many :schedules, dependent: :destroy
end
