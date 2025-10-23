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
  # 集計期間は常に過去30日間です
  desc '日次映画ランキングを更新します（TARGET_DATEのデフォルトは今日です）'
  task refresh_daily: :environment do
    # 集計対象日の決定
    # 環境変数TARGET_DATEが指定されている場合はその日付を使用
    # 未指定の場合は今日の日付を使用
    target_date = if ENV['TARGET_DATE'].present?
                    Date.parse(ENV['TARGET_DATE'])
                  else
                    Time.zone.today
                  end

    # ランキング更新サービスの実行
    # 指定した日付(target_date)を引数として渡して、ランキングを更新
    # 集計期間はサービス側のデフォルト値（LOOKBACK_DAYS）を使用
    DailyMovieRankings::Refresher.call(target_date:)
  end
end
