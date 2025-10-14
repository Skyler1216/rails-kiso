# ============================================================================
# DailyMovieRanking - 日次映画ランキングモデル
# station 5,6の変更箇所
# ============================================================================
# 映画の人気度を日次で集計・保存するためのモデルです。
# 予約数に基づいて映画のランキングを管理し、トップページでの表示に使用します。
# ============================================================================
class DailyMovieRanking < ApplicationRecord
  # 映画との関連付け（1つのランキングは1つの映画に属する）
  belongs_to :movie

  # ============================================================================
  # バリデーション（データの整合性チェック）
  # ============================================================================
  
  # 集計対象日は必須
  validates :aggregated_on, presence: true
  
  # 予約数は必須かつ0以上の整数
  # greater_than_or_equal_to: 0 で負の値を防ぐ
  validates :reservation_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  # ランキング順位は必須かつ1以上の整数
  # greater_than: 0 で0位や負の順位を防ぐ
  validates :rank_position, presence: true, numericality: { greater_than: 0 }

  # ============================================================================
  # スコープ（よく使う検索条件を定義）
  # ============================================================================
  
  # 指定した日付のランキングを取得
  # 使用例: DailyMovieRanking.for_date(Date.current)
  scope :for_date, ->(date) { where(aggregated_on: date) }
  
  # ランキング順位でソート（1位、2位、3位...の順）
  # 使用例: DailyMovieRanking.ordered
  scope :ordered, -> { order(:rank_position) }
  
  # 上位N位までのランキングを取得
  # 使用例: DailyMovieRanking.top(10) → 上位10位まで
  scope :top, ->(limit_value) { ordered.limit(limit_value) }
end
