# ============================================================================
# Reservation Reminder Rake Task - 予約前日リマインドメール送信
# ============================================================================
# 予約の前日19時(JST)にリマインドメールを送信するRakeタスクです。
# whenever gemによって定期実行されます。
# station3,4で説明
# 使用方法：
# 1. 通常実行: rake reservation:send_reminders
# 2. 特定日付指定: TARGET_DATE=2024-01-15 rake reservation:send_reminders
# 3. 定期実行: whenever gemで自動実行（毎日19時JST）　今回はこれ。config/schedule.rbで設定。
# ============================================================================

namespace :reservation do
  # タスクの説明（rake -T で表示される）
  desc 'Send reminder emails for reservations scheduled for the next day'

  # メインのタスク定義
  task send_reminders: :environment do
    # 対象日付の決定
    # ENV['TARGET_DATE']が設定されている場合はその日付を使用
    # 設定されていない場合は明日の日付を使用（定期実行時）
    target_date = if ENV['TARGET_DATE'].present?
                    # 環境変数から日付をパース（テスト時や手動実行時）
                    Date.parse(ENV['TARGET_DATE'])
                  else
                    # 明日の日付を取得（定期実行時）
                    Time.zone.tomorrow.to_date
                  end

    # 対象日付の予約を取得してリマインドメールを送信
    # Reservation.upcoming_for(target_date): 指定日付の予約を取得するスコープ
    # find_each: 大量データでもメモリ効率的に処理（バッチ処理）
    Reservation.upcoming_for(target_date).find_each do |reservation|
      # 各予約に対してリマインドメールを即時送信
      # ReservationMailer.reminder: リマインドメールの内容を準備
      # deliver_now: ジョブキューを経由せず、その場で送信（ローカル検証を優先）
      ReservationMailer.reminder(reservation).deliver_now
    end
  end
end
