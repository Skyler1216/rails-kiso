class Theater < ApplicationRecord
  # Theater（劇場）モデル
  # - 映画館そのものを表します
  # - 1つの劇場は複数のスクリーン（上映室）を持ちます

  # 関連（Association）
  # has_many :screens
  # - この劇場に紐づく Screen レコードが複数あることを表します
  # - dependent: :destroy により、劇場を削除したときに関連するスクリーンも一緒に削除されます
  has_many :screens, dependent: :destroy

  # バリデーション（Validation）
  # - name（劇場名）は必須
  # - address（住所）も必須
  validates :name, presence: true
  validates :address, presence: true
end
