# ============================================================================
# 映画ランキング関連のRakeタスク
# station 5,6の変更箇所
# ============================================================================
# 日次映画ランキングの更新処理を実行するためのタスクです。
# cron jobや手動実行で使用され、過去N日間の予約数に基づいてランキングを生成します。
# ============================================================================

namespace :ranking do
  # 日次映画ランキングの更新タスク
  # @description 指定した日付の映画ランキングを集計・更新します
  # @param TARGET_DATE [String] 集計対象日（YYYY-MM-DD形式、デフォルト: 今日）
  # @param LOOKBACK_DAYS [Integer] 集計期間（デフォルト: 30日）
  desc 'Refresh daily movie rankings snapshot (TARGET_DATE defaults to today)'
  task refresh_daily: :environment do
    # 集計対象日の決定
    # 環境変数TARGET_DATEが指定されている場合はその日付を使用
    # 未指定の場合は今日の日付を使用
    target_date = if ENV['TARGET_DATE'].present?
                    Date.parse(ENV['TARGET_DATE'])
                  else
                    Time.zone.today
                  end

    # 集計期間の決定
    # 環境変数LOOKBACK_DAYSが指定されている場合はその値を使用
    # 未指定の場合はサービスクラスのデフォルト値（30日）を使用
    lookback_days = ENV.fetch('LOOKBACK_DAYS', DailyMovieRankings::Refresher::LOOKBACK_DAYS).to_i

    # ランキング更新サービスの実行
    # 指定した日付と集計期間でランキングを更新
    DailyMovieRankings::Refresher.call(
      target_date: target_date,
      lookback_days: lookback_days
    )
  end
end
