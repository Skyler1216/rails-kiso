class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  validates :name, presence: true
  validates :email, presence: true
  validates :password, presence: true
  validates :password_confirmation, presence: true

  has_many :reservations

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
end
