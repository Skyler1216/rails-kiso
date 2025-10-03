# ============================================================================
# ReservationMailer Spec - 予約確認メールのテスト
# ============================================================================
# ReservationMailerのbooking_confirmationメソッドの動作をテストします。
# メールの送信先、件名、本文内容が正しく生成されることを確認します。
# ============================================================================

require 'rails_helper'

RSpec.describe ReservationMailer, type: :mailer do
  describe '#booking_confirmation' do
    # テスト対象のメールオブジェクト
    subject(:mail) { described_class.booking_confirmation(reservation) }

    # テストデータの準備
    let(:start_time) { Time.utc(2024, 10, 8, 20, 0) }  # 上映開始時間（UTC）
    let(:schedule) { create(:schedule, start_time: start_time, end_time: start_time + 2.hours) }  # 2時間の上映
    let(:booking_time) { Time.utc(2024, 10, 2, 12, 30) }  # 予約作成時間（UTC）
    
    # 予約データ：作成時間を手動で設定
    let(:reservation) do
      create(:reservation, schedule: schedule).tap do |record|
        # update_columns: バリデーションをスキップして直接DBを更新
        record.update_columns(created_at: booking_time, updated_at: booking_time)
      end
    end

    # 送信先のテスト
    it 'delivers to the reservation email address' do
      expect(mail.to).to contain_exactly(reservation.email)
    end

    # 件名のテスト
    it 'builds a subject including the movie name' do
      expect(mail.subject).to eq(
        I18n.t('reservation_mailer.booking_confirmation.subject', movie: reservation.schedule.movie.name)
      )
    end

    # メール本文内容のテスト
    it 'renders reservation information in the body' do
      # テキスト形式とHTML形式の両方を取得
      text_body = mail.text_part.body.decoded
      html_body = mail.html_part.body.decoded

      # 予約者名の確認
      expect(text_body).to include(reservation.name)
      
      # 映画名の確認
      expect(html_body).to include(reservation.schedule.movie.name)
      
      # 劇場名の確認
      expect(html_body).to include(reservation.screen.theater.name)

      # 座席情報の確認（行-列の形式）
      expected_seat = "#{reservation.sheet.row}-#{reservation.sheet.column}"
      expect(html_body).to include(expected_seat)

      # 上映時間の確認（日付 + 時間範囲）
      expected_range = "#{I18n.l(reservation.date, format: :long)} #{schedule.start_time.strftime('%H:%M')}〜#{schedule.end_time.strftime('%H:%M')}"
      expect(text_body).to include(expected_range)

      # 予約日時の確認（JST変換済み）
      expected_booking_time = I18n.l(booking_time.in_time_zone('Asia/Tokyo'), format: :long)
      expect(text_body).to include(expected_booking_time)
    end
  end
end
