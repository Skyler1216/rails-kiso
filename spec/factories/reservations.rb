# ============================================================================
# Reservation Factory - 予約テストデータの生成
# ============================================================================
# FactoryBotを使用して予約（Reservation）のテストデータを生成します。
# 関連するモデル（schedule, screen, sheet）も自動で作成されます。
# ============================================================================

FactoryBot.define do
  factory :reservation do
    # 上映スケジュールとの関連（必須）
    association :schedule

    # 上映日：スケジュールの開始時間から自動計算、なければ今日の日付
    date { schedule&.start_time&.in_time_zone&.to_date || Date.current }

    # 予約者情報（テスト用の固定値）
    name { 'Test User' }
    email { 'test@example.com' }

    # スクリーン：スケジュールから自動取得
    screen { schedule.screen }

    # 座席：スクリーンに関連付けられた座席を自動生成
    sheet { association :sheet, screen: screen }
  end
end
