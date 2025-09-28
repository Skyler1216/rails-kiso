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
  # - 劇場作成・更新時にスクリーン情報も同時に処理可能
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

  # ネストされたスクリーンで同じ名称が重複しないようチェック
  # 
  # 処理の流れ:
  # 1. スクリーンが存在しない場合は処理を終了
  # 2. 各スクリーンの名前を正規化（空白除去・小文字化）
  # 3. 同じ名前のスクリーンをグループ化
  # 4. 重複がある場合、各スクリーンにエラーを追加
  def screens_have_unique_names
    # スクリーンが存在しない場合は処理を終了
    return if screens.blank?

    # 名前ごとにスクリーンをグループ化するためのハッシュ
    # 例: {"screen1" => [screen1_obj, screen1_obj2], "screen2" => [screen2_obj]}
    buckets = Hash.new { |hash, key| hash[key] = [] }

    # 各スクリーンをチェック
    screens.each do |screen|
      # 削除予定のスクリーンはスキップ
      next if screen.marked_for_destruction?

      # スクリーン名を正規化（空白除去・小文字化）
      # 例: " スクリーン1 " → "スクリーン1"
      normalized = screen.name.to_s.strip.downcase
      # 正規化後の名前が空の場合はスキップ
      next if normalized.blank?

      # 正規化された名前でグループ化
      buckets[normalized] << screen
    end

    # 重複があるスクリーン名を抽出
    # 例: {"screen1" => [screen1_obj, screen1_obj2]} → 重複あり
    duplicates = buckets.select { |_name, list| list.size > 1 }
    # 重複がない場合は処理を終了
    return if duplicates.empty?

    # エラーメッセージ
    message = 'は同じ劇場内で一意になるよう設定してください'

    # 重複している各スクリーンにエラーを追加
    duplicates.each_value do |screens_with_same_name|
      screens_with_same_name.each do |screen|
        # 既に同じエラーメッセージが追加されている場合はスキップ
        next if screen.errors[:name].include?(message)

        # スクリーン名にエラーを追加
        screen.errors.add(:name, message)
      end
    end
  end
end
