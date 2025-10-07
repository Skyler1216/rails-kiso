# ============================================================================
# Reservation Reminder Rake Task Spec - 予約リマインドRakeタスクのテスト
# ============================================================================
# station3,4で説明
# reservation:send_remindersタスクの動作をテストします。
# 明日の予約に対するリマインドメール送信と、環境変数による日付指定を検証します。
# ============================================================================

require 'rails_helper'
require 'rake'

RSpec.describe 'reservation:send_reminders' do
  # ActiveJobとTimeHelpersのテストヘルパーをインクルード
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  # テスト対象のタスク名とタスクオブジェクト
  let(:task_name) { 'reservation:send_reminders' }
  let(:task) { Rake::Task[task_name] }

  # 全テスト開始前にRakeタスクを読み込み
  before(:all) do
    Rake.application = Rake::Application.new
    Rails.application.load_tasks
  end

  # 各テスト前の準備
  before do
    # メール送信履歴をクリア
    ActionMailer::Base.deliveries.clear
    
    # ジョブキューのアダプターをテスト用に変更
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    
    # ジョブキューの状態をクリア
    clear_enqueued_jobs
    clear_performed_jobs
    
    # タスクを再実行可能にする
    task.reenable
  end

  # 各テスト後のクリーンアップ
  after do
    # ジョブキューの状態をクリア
    clear_enqueued_jobs
    clear_performed_jobs
    
    # 元のアダプターに戻す
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    
    # メール送信履歴をクリア
    ActionMailer::Base.deliveries.clear
  end

  # タイムゾーンをJSTに設定（全テストで適用）
  around do |example|
    Time.use_zone('Asia/Tokyo') { example.run }
  end

  # 基本的なリマインドメール送信のテスト
  it 'sends reminder emails for reservations scheduled for tomorrow' do
    # 2024年10月10日12:00に時間を固定
    travel_to(Time.zone.local(2024, 10, 10, 12, 0, 0)) do
      # 明日（10月11日）の日付を取得
      target_date = Time.zone.tomorrow.to_date

      # 明日上映予定のスケジュールと予約を作成
      schedule_for_target = create(
        :schedule,
        start_time: Time.zone.local(2024, 10, 11, 19, 0, 0),  # 10月11日19:00
        end_time: Time.zone.local(2024, 10, 11, 21, 0, 0)     # 10月11日21:00
      )
      target_reservation = create(
        :reservation,
        schedule: schedule_for_target,
        email: 'tomorrow@example.com',
        date: target_date  # 10月11日
      )

      # 明後日上映予定のスケジュールと予約を作成（送信対象外）
      schedule_for_other = create(
        :schedule,
        start_time: Time.zone.local(2024, 10, 12, 19, 0, 0),  # 10月12日19:00
        end_time: Time.zone.local(2024, 10, 12, 21, 0, 0)     # 10月12日21:00
      )
      create(
        :reservation,
        schedule: schedule_for_other,
        email: 'later@example.com',
        date: target_date + 1.day  # 10月12日（送信対象外）
      )

      # 非同期ジョブを実行してタスクを実行
      perform_enqueued_jobs do
        task.invoke
      end

      # 送信されたメールの宛先を確認
      delivered_to = ActionMailer::Base.deliveries.map(&:to).flatten
      expect(delivered_to).to contain_exactly('tomorrow@example.com')

      # 最後に送信されたメールの件名を確認
      last_mail = ActionMailer::Base.deliveries.last
      expect(last_mail.subject).to eq(
        I18n.t('reservation_mailer.reminder.subject', movie: target_reservation.schedule.movie.name)
      )
    end
  end

  # 環境変数による日付指定のテスト
  it 'allows overriding the target date via TARGET_DATE env var' do
    # 2024年10月10日12:00に時間を固定
    travel_to(Time.zone.local(2024, 10, 10, 12, 0, 0)) do
      # 指定日（10月15日）を設定
      override_date = Date.new(2024, 10, 15)
      
      # 指定日上映予定のスケジュールと予約を作成
      schedule_for_target = create(
        :schedule,
        start_time: Time.zone.local(2024, 10, 15, 18, 0, 0),  # 10月15日18:00
        end_time: Time.zone.local(2024, 10, 15, 20, 0, 0)     # 10月15日20:00
      )
      create(
        :reservation,
        schedule: schedule_for_target,
        email: 'override@example.com',
        date: override_date  # 10月15日
      )

      # 環境変数で対象日付を指定
      ENV['TARGET_DATE'] = override_date.to_s

      # 非同期ジョブを実行してタスクを実行
      perform_enqueued_jobs do
        task.invoke
      end

      # 送信されたメールの宛先を確認
      delivered_to = ActionMailer::Base.deliveries.map(&:to).flatten
      expect(delivered_to).to contain_exactly('override@example.com')
    ensure
      # 環境変数をクリーンアップ
      ENV.delete('TARGET_DATE')
    end
  end
end
