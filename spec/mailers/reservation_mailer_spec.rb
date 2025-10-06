# ============================================================================
# ReservationMailer Spec - 予約関連メールのテスト
# ============================================================================
# ReservationMailerのbooking_confirmationとreminderメソッドの動作をテストします。
# 共通のテストパターンをshared_examplesで定義し、重複を避けています。
# ============================================================================

require 'rails_helper'

RSpec.describe ReservationMailer, type: :mailer do
  # --- テストデータの準備 ------------------------------------------------------
  # ここで作る値は、メール本文の表示内容（上映時間や予約日時）を
  # 予測しやすく・再現性高く検証できるように、固定の時刻にしています。
  let(:start_time) { Time.utc(2024, 10, 8, 20, 0) }  # 上映開始時間（UTC）
  let(:schedule) { create(:schedule, start_time: start_time, end_time: start_time + 2.hours) }  # 2時間の上映
  let(:booking_time) { Time.utc(2024, 10, 2, 12, 30) }  # 予約作成時間（UTC）
  
  # 予約データ：作成時間(created_at)を手動で固定
  # → メール本文に出る「予約日時」の期待値を正確に比較するため
  let(:reservation) do
    create(:reservation, schedule: schedule).tap do |record|
      # update_columns: バリデーションをスキップして直接DBを更新
      record.update_columns(created_at: booking_time, updated_at: booking_time)
    end
  end

  # --- 共通テスト（2種類のメールで共有） --------------------------------------
  # booking_confirmation / reminder のどちらのメールでも満たすべき
  # 共通仕様（宛先/件名/本文の主要情報）を一箇所にまとめてテストします。
  shared_examples 'reservation mailer' do |mailer_method, translation_key|
    # テスト対象のメールオブジェクト（指定メソッドを動的に呼び出し）
    subject(:mail) { described_class.public_send(mailer_method, reservation) }

    # 宛先: 予約者のメールアドレスに送られること
    it 'delivers to the reservation email address' do
      expect(mail.to).to contain_exactly(reservation.email)
    end

    # 件名: I18nのテンプレートに作品名が差し込まれていること
    it 'builds a subject including the movie name' do
      expect(mail.subject).to eq(
        I18n.t(translation_key, movie: reservation.schedule.movie.name)
      )
    end

    # 本文: マルチパート(テキスト/HTML)の両方を検証
    it 'renders reservation information in the body' do
      # それぞれの本文を取り出し、期待する文字列が含まれるか確認
      text_body = mail.text_part.body.decoded
      html_body = mail.html_part.body.decoded

      # 予約者名
      expect(text_body).to include(reservation.name)
      
      # 映画名（HTML側で確認）
      expect(html_body).to include(reservation.schedule.movie.name)
      
      # 劇場名（HTML側で確認）
      expect(html_body).to include(reservation.screen.theater.name)

      # 座席（行-列の形式で表示される想定）
      expected_seat = "#{reservation.sheet.row}-#{reservation.sheet.column}"
      expect(html_body).to include(expected_seat)

      # 上映日(ロングフォーマット) + 時間帯(HH:MM〜HH:MM) がテキスト側に出力されること
      expected_range = "#{I18n.l(reservation.date, format: :long)} #{schedule.start_time.strftime('%H:%M')}〜#{schedule.end_time.strftime('%H:%M')}"
      expect(text_body).to include(expected_range)

      # 予約日時（JSTに変換し、ロングフォーマットで出力）
      expected_booking_time = I18n.l(booking_time.in_time_zone('Asia/Tokyo'), format: :long)
      expect(text_body).to include(expected_booking_time)
    end
  end

  # 予約確認メールのテスト
  describe '#booking_confirmation' do
    # 上記の共通仕様を、このメールにも適用
    it_behaves_like 'reservation mailer', :booking_confirmation, 'reservation_mailer.booking_confirmation.subject'
  end

  # 予約リマインドメールのテスト
  describe '#reminder' do
    # 上記の共通仕様を、このメールにも適用
    it_behaves_like 'reservation mailer', :reminder, 'reservation_mailer.reminder.subject'
  end
end
