class Theater < ApplicationRecord
  # ============================================================================
  # Theater（劇場）モデル
  # ============================================================================
  # 映画館そのものを表すモデルです。
  # 1つの劇場は複数のスクリーン（上映室）を持ち、各スクリーンで異なる映画を上映できます。
  #
  # 例: 「シネマシティ渋谷」→ スクリーン1, スクリーン2, スクリーン3...
  # ============================================================================

  # ----------------------------------------------------------------------------
  # 関連（Association）
  # ----------------------------------------------------------------------------

  # スクリーンとの関連
  # - 1つの劇場は複数のスクリーンを持つ（1:Nの関係）
  # - 劇場削除時に関連するスクリーンも自動削除される
  has_many :screens, dependent: :destroy

  # ネストした属性の受け入れ設定
  # - 劇場作成・更新時にスクリーン情報も同時に処理（作成・更新・削除）可能
  # - allow_destroy: true → スクリーンの削除も許可
  # - reject_if → スクリーン名が空の場合は無視
  accepts_nested_attributes_for :screens,
                                allow_destroy: true,
                                reject_if: ->(attrs) { attrs['name'].blank? }

  # ----------------------------------------------------------------------------
  # バリデーション（Validation）
  # ----------------------------------------------------------------------------

  # 劇場名のバリデーション
  # - 必須チェック: 劇場名は空ではいけない
  # - 一意性チェック: システム全体で劇場名の重複を防ぐ
  # - 大文字小文字を区別しない（"TOHO" と "toho" は同じとみなす）
  validates :name, presence: true, uniqueness: { case_sensitive: false }

  # 住所のバリデーション
  # - 必須チェック: 住所は空ではいけない
  # - 空文字やnilは許可しない
  validates :address, presence: true

  # カスタムバリデーション: ネストされたスクリーンの名前重複チェック
  # - 同じ劇場内でスクリーン名が重複しないようチェック
  # - フォームから複数のスクリーンを同時に作成・更新する際に使用
  validate :screens_have_unique_names

  private

  # 以下は作り込み中

  # ネストされたスクリーンで同じ名称が重複しないようチェック
  #
  # 処理の流れ:
  # 1. スクリーンが存在しない場合は処理を終了
  # 2. 各スクリーンの名前を正規化（空白除去・小文字化）
  # 3. 同じ名前のスクリーンをグループ化
  # 4. 重複がある場合、各スクリーンにエラーを追加
  def screens_have_unique_names
    duplicates = grouped_duplicate_screens
    return if duplicates.empty?

    duplicates.each_value { |screens_with_same_name| add_screen_name_errors(screens_with_same_name) }
    add_theater_screen_error
  end

  def grouped_duplicate_screens
    buckets = screens.reject(&:marked_for_destruction?)
                     .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |screen, memo|
      name = normalized_screen_name(screen)
      next if name.blank?

      memo[name] << screen
    end

    buckets.select { |_name, list| list.size > 1 }
  end

  def normalized_screen_name(screen)
    screen.name.to_s.strip.downcase
  end

  def add_screen_name_errors(screens_with_same_name)
    message = 'は同じ劇場内で一意になるよう設定してください'
    screens_with_same_name.each do |screen|
      next if screen.errors[:name].include?(message)

      screen.errors.add(:name, message)
    end
  end

  def add_theater_screen_error
    message = 'に重複するスクリーン名が含まれています'
    errors.add(:screens, message) unless errors[:screens].include?(message)
  end
end
