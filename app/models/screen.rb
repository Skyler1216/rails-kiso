class Screen < ApplicationRecord
  # Screen（スクリーン）モデル
  # - 劇場内の「上映室」を表します
  # - 1つのスクリーンは複数の座席（sheets）と複数の上映スケジュール（schedules）を持ちます

  # 関連（Association）
  # belongs_to :theater
  # - このスクリーンがどの劇場に属するかを表します（theater_id が必須）
  belongs_to :theater

  # has_many :sheets
  # - このスクリーンに紐づく座席（行・列）の集合
  # - dependent: :destroy により、スクリーン削除時に座席も一緒に削除されます
  has_many :sheets, dependent: :destroy

  # has_many :schedules
  # - このスクリーンで行われる上映スケジュール
  has_many :schedules

  # バリデーション（Validation）
  # - name（スクリーン名）は必須
  validates :name, presence: true
end
