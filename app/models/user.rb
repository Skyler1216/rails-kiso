class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  validates :name, presence: true
  validates :email, presence: true
  validates :password, presence: true
  validates :password_confirmation, presence: true

  # 🔐 管理者権限のバリデーション
  validates :admin, inclusion: { in: [true, false] }

  has_many :reservations

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # 🔐 管理者かどうかを判定するメソッド
  def admin?
    admin == true
  end

  # 🔐 一般ユーザーかどうかを判定するメソッド
  def regular_user?
    admin == false
  end
end
