# ============================================================================
# Reservations Request Spec - 予約APIの統合テスト
# ============================================================================
# 予約作成API（POST /reservations）の動作をテストします。
# 認証状態、メール送信、リダイレクト処理などを含む統合テストです。
# ============================================================================

require 'rails_helper'

RSpec.describe 'Reservations', type: :request do
  # ActiveJobのテストヘルパーをインクルード（非同期処理のテスト用）
  include ActiveJob::TestHelper

  describe 'POST /reservations' do
    # 未認証ユーザーのテスト
    context 'when unauthenticated' do
      it 'redirects to the login page' do
        post reservations_path

        # ログインページにリダイレクトされることを確認
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    # 認証済みユーザーのテスト
    context 'when authenticated' do
      # テスト前の準備：メール送信とジョブキューの設定
      before do
        # メール送信履歴をクリア
        ActionMailer::Base.deliveries.clear

        # ジョブキューのアダプターをテスト用に変更
        @original_queue_adapter = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = :test
      end

      # テスト後のクリーンアップ
      after do
        # ジョブキューの状態をクリア
        clear_enqueued_jobs
        clear_performed_jobs

        # 元のアダプターに戻す
        ActiveJob::Base.queue_adapter = @original_queue_adapter
      end

      # 基本的な予約処理のテスト
      it 'processes the reservation request' do
        # テストデータの準備
        user = create(:user)
        sign_in(user)

        movie = create(:movie)
        screen = create(:screen)
        sheet = create(:sheet, screen: screen)
        schedule = create(:schedule, movie: movie, screen: screen)

        # 予約リクエストの送信
        post reservations_path, params: {
          reservation: {
            name: user.name,
            email: user.email,
            schedule_id: schedule.id,
            sheet_id: sheet.id,
            screen_id: screen.id,
            date: Date.today
          }
        }

        # 映画詳細ページにリダイレクトされることを確認
        expect(response).to redirect_to(movie_path(movie))
      end

      # メール送信機能のテスト
      it 'sends a confirmation email with reservation details' do
        # テストデータの準備
        user = create(:user)
        sign_in(user)

        movie = create(:movie)
        screen = create(:screen)
        sheet = create(:sheet, screen: screen)
        schedule = create(:schedule, movie: movie, screen: screen)

        # メール送信の確認（非同期ジョブを実行）
        expect do
          perform_enqueued_jobs do
            post reservations_path, params: {
              reservation: {
                name: user.name,
                email: user.email,
                schedule_id: schedule.id,
                sheet_id: sheet.id,
                screen_id: screen.id,
                date: Date.today
              }
            }
          end
        end.to change(ActionMailer::Base.deliveries, :count).by(1)

        # 送信されたメールの内容確認
        mail = ActionMailer::Base.deliveries.last

        # 送信先の確認
        expect(mail.to).to contain_exactly(user.email)

        # 件名に映画名が含まれることを確認
        expect(mail.subject).to include(movie.name)

        # メール本文の内容確認
        reservation = Reservation.last
        text_body = mail.text_part.body.decoded
        html_body = mail.html_part.body.decoded

        # 予約者名の確認
        expect(text_body).to include(user.name)

        # 劇場名の確認
        expect(html_body).to include(screen.theater.name)

        # 上映時間の確認（日付 + 時間範囲）
        expected_range = "#{I18n.l(reservation.date, format: :long)} #{schedule.start_time.strftime('%H:%M')}〜#{schedule.end_time.strftime('%H:%M')}"
        expect(text_body).to include(expected_range)

        # 予約日時の確認（JST変換済み）
        expected_booking_time = I18n.l(reservation.created_at.in_time_zone('Asia/Tokyo'), format: :long)
        expect(text_body).to include(expected_booking_time)
      end
    end
  end
end
