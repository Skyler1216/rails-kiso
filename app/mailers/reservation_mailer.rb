# ============================================================================
# ReservationMailer - 予約関連のメール送信機能
# ============================================================================
# 予約確認や変更通知などのメール送信を担当するメーラーです。
# ApplicationMailer を継承して、共通設定やヘルパーメソッドを利用できます。
# ============================================================================

class ReservationMailer < ApplicationMailer
  # ----------------------------------------------------------------------------
  # 予約確認メール送信
  # ----------------------------------------------------------------------------
  # 予約が完了した際にユーザーに送信される確認メールです。
  # 映画情報、上映時間、座席情報などを含んだHTMLとテキスト形式で送信されます。
  #
  # @param reservation [Reservation] 予約オブジェクト
  # @return [Mail::Message] ActionMailer のメールオブジェクト
  #
  def booking_confirmation(reservation)
    # インスタンス変数を設定（ビューテンプレートで使用）
    @reservation = reservation           # 予約オブジェクト（基本情報）
    @schedule = reservation.schedule     # 上映スケジュール
    @movie = @schedule.movie             # 映画情報
    @screen = reservation.screen         # スクリーン情報
    @theater = @screen.theater           # 劇場情報
    @sheet = reservation.sheet            # 座席情報
    @screening_date = reservation.date   # 上映日

    @screening_start_time = formatted_time(@schedule.start_time)    # 開始時間（HH:MM形式）
    @screening_end_time = formatted_time(@schedule.end_time)        # 終了時間（HH:MM形式）
    @screening_time_range = build_time_range(@screening_start_time, @screening_end_time)  # 時間範囲文字列
    
    @booking_timestamp = reservation.created_at.in_time_zone('Asia/Tokyo')  # 予約日時（JST）

    # メールの送信設定、送信先、件番名を設定
    mail(
      to: reservation.email,                                                    # 送信先アドレス
      # メールの件名を設定（I18n使用）
      # I18n.t: Railsの国際化機能を使用（将来の多言語対応に備えて）
      # 'reservation_mailer.booking_confirmation.subject': 翻訳ファイル（config/locales/ja.yml）のキー
      # movie: @movie.name: 翻訳テンプレート内の変数（映画名を動的に挿入）
      # 例: "【映画予約システム】「アベンジャーズ」の予約が完了しました"
      subject: I18n.t('reservation_mailer.booking_confirmation.subject', movie: @movie.name)
    )
  end

  private

  # ----------------------------------------------------------------------------
  # 時間フォーマット変換（HH:MM形式）
  # ----------------------------------------------------------------------------
  # Time/DateTime オブジェクトを "14:30" のような形式に変換します。
  # 時刻が nil の場合も安全に処理できます。
  #
  # @param time [Time, DateTime, nil] 変換したい時刻
  # @return [String, nil] "HH:MM" 形式の文字列、または nil
  #
  def formatted_time(time)
    time&.strftime('%H:%M')  # &. で安全な呼び出し（timeがnilでもエラーにならない）
  end

  # ----------------------------------------------------------------------------
  # 時間範囲文字列の構築
  # ----------------------------------------------------------------------------
  # 開始時間と終了時間から "14:30〜16:00" のような範囲文字列を作成します。
  # 片方の時間しかない場合は、その時間のみを返します。
  #
  # @param start_time [String, nil] 開始時間（"HH:MM"形式）
  # @param end_time [String, nil] 終了時間（"HH:MM"形式）
  # @return [String] 時間範囲の文字列
  #
  def build_time_range(start_time, end_time)
    # 終了時間がない場合は開始時間のみを返す
    return start_time if end_time.blank?
    # 開始時間がない場合は終了時間のみを返す（通常は発生しない）
    return end_time if start_time.blank?

    # 両方の時間がある場合は範囲文字列を作成
    "#{start_time}〜#{end_time}"
  end
end
