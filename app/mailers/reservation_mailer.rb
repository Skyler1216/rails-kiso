# ============================================================================
# ReservationMailer - 予約関連のメール送信機能
# station3,4で説明
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
  # 送信タイミング: 予約作成成功時（ReservationsController#create）
  # 送信方法: deliver_later（非同期送信）
  # テンプレート: booking_confirmation.(html|text).erb
  #
  # @param reservation [Reservation] 予約オブジェクト
  # @return [Mail::Message] ActionMailer のメールオブジェクト
  #
  def booking_confirmation(reservation)
    # 予約情報をビューテンプレートで使用できる形に整理
    assign_reservation_context(reservation)

    # メール送信設定
    mail(
      to: reservation.email,                                                    # 送信先：予約者のメールアドレス
      # 件名：I18nを使用して映画名を動的に挿入
      # 例: "【鬼滅の刃】ご予約が完了しました"
      subject: I18n.t('reservation_mailer.booking_confirmation.subject', movie: @movie.name)
    )
  end

  # ----------------------------------------------------------------------------
  # 前日リマインダーメール送信
  # ----------------------------------------------------------------------------
  # 上映日前日に送信し、来場忘れを防止します。
  # 予約確認メールと同じ内容で、リマインド専用の件名を使用します。
  #
  # 送信タイミング: 上映前日19時JST（whenever + Rakeタスク）
  # 送信方法: deliver_now（同期送信）
  # テンプレート: reminder.(html|text).erb
  #
  # @param reservation [Reservation] 予約オブジェクト
  # @return [Mail::Message] ActionMailer のメールオブジェクト
  #
  def reminder(reservation)
    # 予約情報をビューテンプレートで使用できる形に整理
    assign_reservation_context(reservation)

    # メール送信設定
    mail(
      to: reservation.email,                                                    # 送信先：予約者のメールアドレス
      # 件名：I18nを使用して映画名を動的に挿入
      # 例: "【鬼滅の刃】上映リマインド"
      subject: I18n.t('reservation_mailer.reminder.subject', movie: @movie.name)
    )
  end

  private

  # ----------------------------------------------------------------------------
  # 予約情報の整理・設定
  # ----------------------------------------------------------------------------
  # 予約オブジェクトから必要な情報を抽出し、ビューテンプレートで使用できる形に整理します。
  # 各インスタンス変数は、メールテンプレート内で直接参照できます。
  #
  # @param reservation [Reservation] 予約オブジェクト
  # @return [void]
  #
  def assign_reservation_context(reservation)
    # 基本情報
    @reservation = reservation           # 予約オブジェクト（基本情報）
    @schedule = reservation.schedule     # 上映スケジュール
    @movie = @schedule.movie             # 映画情報
    @screen = reservation.screen         # スクリーン情報
    @theater = @screen.theater           # 劇場情報
    @sheet = reservation.sheet           # 座席情報
    @screening_date = reservation.date   # 上映日
    
    # 時間情報（フォーマット済み）
    @screening_start_time = formatted_time(@schedule.start_time)    # 開始時間（HH:MM形式）
    @screening_end_time = formatted_time(@schedule.end_time)        # 終了時間（HH:MM形式）
    @screening_time_range = build_time_range(@screening_start_time, @screening_end_time)  # 時間範囲文字列
    
    # 予約日時（JST変換済み）
    @booking_timestamp = reservation.created_at.in_time_zone('Asia/Tokyo')
  end

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
    # &. で安全な呼び出し（timeがnilでもエラーにならない）
    # 例: Time.current → "14:30", nil → nil
    time&.strftime('%H:%M')
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
    # 例: "14:30" → "14:30"
    return start_time if end_time.blank?
    
    # 開始時間がない場合は終了時間のみを返す（通常は発生しない）
    # 例: nil, "16:00" → "16:00"
    return end_time if start_time.blank?

    # 両方の時間がある場合は範囲文字列を作成
    # 例: "14:30", "16:00" → "14:30〜16:00"
    "#{start_time}〜#{end_time}"
  end
end
