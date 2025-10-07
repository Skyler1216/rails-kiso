# 予約メール通知機能 対応方針

## 概要
- ユーザが座席予約を完了したタイミングと、予約前日19時(JST)に通知メールを送る仕組みを整備する。
- ActionMailerを用いたメール送信と、ローカル開発環境での検証方法を確立する。
- 定期実行には`whenever`で作成したCrontab設定を使い、Rakeタスクを介してバッチ処理を実行する。

## 最新進捗
- **課題1 (予約完了メール)**: ✅ 実装完了
  - `ReservationMailer#booking_confirmation`を新設し、HTML/テキスト両方のテンプレートで作品・劇場・上映時刻・座席・予約者名を表示。
  - 予約完了時に`ReservationsController#create`から`deliver_later`で送信。テスト環境は`config/environments/test.rb`で`ActiveJob::Base.queue_adapter = :test`指定済み。
- 開発環境は`config/environments/development.rb`で`letter_opener_web`を利用してローカル確認。`bundle install`済み。
  - メール本文では上映日と「開始〜終了時刻」の範囲、さらに予約日時（作成日時）を表示するよう調整済み。
  - RSpecでリクエスト/メール/システムテストを追加し、`bundle exec rspec`で全テスト成功。
- **課題2 (前日リマインド)**: ✅ 実装完了
  - `reservation:send_reminders` Rakeタスクを作成し、翌日上映予定の予約に対して`ReservationMailer#reminder`を送信。（※ローカル検証中は一時的に`deliver_now`で即時送信）
  - `TARGET_DATE`環境変数で対象日を上書きでき、検証用途で任意日を指定可能。
  - `config/schedule.rb`でwheneverを用いた19:00 JST実行のCron設定を定義。
  - `spec/tasks/reservation_reminder_rake_spec.rb`を追加し、タスク挙動と環境変数上書きを検証。

## 課題1: 予約完了メール送信
1. **メールインフラ整備**
   - `Gemfile`に`gem 'actionmailer'`が含まれていることを確認し、未追加の場合は追記して`bundle install`でActionMailer関連コンポーネントを導入する。APIモードのアプリでは`config/application.rb`の`require "rails/all"`または`require "active_job/railtie"`等に加えて`require "action_mailer/railtie"`が有効化されていることも確認する。
   - `config/environments/*.rb`で`config.action_mailer`を適切に設定し、開発環境では`config.action_mailer.delivery_method = :letter_opener_web`のように指定してローカル確認できるようにする。
   - 環境変数にSMTP接続情報を保持し、Credentialsや`.env`で安全に管理する。
2. **Mailer作成**
   - `rails g mailer ReservationMailer`で雛形を作成。
   - `ReservationMailer#booking_confirmation(reservation)`を定義し、予約情報(映画館・作品・上映時刻・座席・予約者氏名)をビューへ渡す。
   - ビュー(`app/views/reservation_mailer/booking_confirmation.(html|text).erb`)で文字化け防止のためUTF-8・マルチパート構成にする。
3. **送信トリガー**
   - 予約作成処理(`ReservationsController#create`や`Reservation`モデルのコールバック)で`ReservationMailer.booking_confirmation(reservation).deliver_later`を呼び出す。
   - ActiveJobバックエンドは`async`で開始し、必要に応じてSidekiq等に差し替え可能な設計にする。
4. **テスト**
   - RSpecでMailerスペック(`spec/mailers/reservation_mailer_spec.rb`)とリクエストスペック(`spec/requests/reservations_spec.rb`)を整備し、件名・宛先・本文の主要情報を検証。
   - 既存のシステムスペックからも予約データを介してメール挙動が崩れないことを確認済み。

## 課題2: 予約前日リマインドメール
### 仕様
- 予約をしているユーザは予約の前日19時(日本時間)にメールが届く
- メールには予約に紐づく情報が見れる（映画館・作品・上映時刻・座席・名前等）
- ユーザからのリクエストがないため、Rakeタスクとしてバッチ処理を実装
- wheneverというGemを利用して定時実行（内部的にはcrontabを設定）

### 実装内容
1. **Rakeタスク実装**
   - `lib/tasks/reservation_reminder.rake`に`reservation:send_reminders`タスクを作成
   - `Reservation.upcoming_for(date)`で翌日上映予定の予約を抽出し、`ReservationMailer.reminder(reservation)`を呼び出す（検証期間は`deliver_now`で即時送信する暫定運用）
   - `TARGET_DATE`環境変数を指定すると任意の日付向けに送信対象を切り替えられる
2. **Mailer/ビュー拡張**
   - `ReservationMailer#reminder(reservation)`を追加し、予約情報を本文に表示
   - `app/views/reservation_mailer/_reservation_summary.(html|text).erb`に予約情報表示を集約して重複を解消
3. **ジョブスケジュール**
   - `whenever`を追加し、`config/schedule.rb`で`every 1.day, at: '7:00 pm'` (cron_timezoneは`Asia/Tokyo`) にRakeタスクを登録
  - デプロイ環境のタイムゾーン設定(`config.time_zone = 'Tokyo'`)を確認
4. **テストと検証**
   - `spec/tasks/reservation_reminder_rake_spec.rb`でタスクのユニットテストを実装し、対象予約のみ通知されること・環境変数上書きが効くことを確認
   - wheneverは`whenever --update-crontab`で生成されるエントリを`whenever --clear-crontab`でロールバック可能なことをドキュメント化
   - テストする際は任意の時間にセットして起動することを確認

## 運用・注意点
- 本番SMTP情報はCredentialsに格納し、開発者環境ではダミー環境変数を用意。
- 送信先メールアドレスは`User#email`を信頼する一方、NULLや無効アドレスのハンドリングを追加。
- `deliver_later`の失敗時通知をログ/監視基盤で検知できるようActiveJobのエラー報告を整備。
- GDPR等の観点で、ユーザが通知停止できるUIの要否をプロダクトオーナーと確認。



## メンター説明用メモ

### 導入 (雑談から仕様確認まで)
- 『予約時と前日』にメールがほしいという要求を、 ActionMailer によって実現しました。
- 予約完了メールで、作品・劇場・スクリーン・上映時刻・予約日時・座席を伝えるようにしました。
   - また、前日19時にもう一度同じ内容で、リマインドが飛ぶようにしています。

### 技術的な押さえどころ
- ActionMailerはRailsに標準で含まれています。
- メール確認のため、Gemに`letter_opener_web`を導入。ブラウザで送信メールの確認が可能。
   - `config/environments/development.rb` の delivery method を `:letter_opener_web` に変更した。
- `ReservationMailer` に `booking_confirmation` と `reminder` を定義した。
   - メールの共通部分は、 `_reservation_summary.(html|text).erb`  という部品にまとめています。これを使って、HTML版とテキスト版の両方のメールを送ります。
   - 受信側の環境でHTMLが表示できないことがあるため、テキスト版も用意して、どちらでも読めるようにしています。

### 予約完了メールの実装ポイント
- 「`ReservationsController#create` の成功時に `deliver_later` で非同期送信し、メール本文には上映日・時間帯・座席などの詳細を詰め込みました。」
- 「テストは mailer / request / system の各スペックを追加し、`bundle exec rspec` で一通り通っています。」

### 前日リマインドの実装ポイント
- 「前日リマインドは `reservation:send_reminders` Rake タスクとして実行し、`Reservation.upcoming_for` の結果に対してメールを送ります（現在はローカル検証のため `deliver_now` を使用中）。」
- 「本番での定時実行は `whenever` の `config/schedule.rb` で 19 時 JST に設定し、`TARGET_DATE` 環境変数で検証用に日付 override できるようにしました。」
- 「タスク用の RSpec も書いていて、正しい予約だけ拾えるか・環境変数で日付を変えられるかを確認しています。」

### 動作確認方法
- 「ローカルでは予約を作って `/letter_opener` にアクセスするとメール内容が確認できます。」
- 「Cron 実行は `whenever --update-crontab` で反映、検証後は `whenever --clear-crontab` で戻せる手順を書き残しています。」

### 次の検討事項 (質問が来た時用)
- 「本番 SMTP の資格情報は Credentials 管理していて、万一 `deliver_later` が失敗したときの通知をどうするかは監視チームと詰める想定です。」
- 「ユーザが通知をオプトアウトしたい場合の UI 追加は別途プロダクトオーナーと要件調整中です。」


🚀 本番環境での設定変更
1. config/environments/production.rbの設定

# config/environments/production.rb
Rails.application.configure do
  # メール送信の設定
  config.action_mailer.default_url_options = { 
    host: ENV['APP_HOST'],           # 例: 'your-app.com'
    protocol: ENV['APP_PROTOCOL']    # 例: 'https'
  }
  
  # 本番環境ではSMTPを使用
  config.action_mailer.delivery_method = :smtp
  
  # メール送信を有効化
  config.action_mailer.perform_deliveries = true
  
  # メール送信エラーをログに記録
  config.action_mailer.raise_delivery_errors = true
  
  # SMTP設定
  config.action_mailer.smtp_settings = {
    address: ENV['SMTP_ADDRESS'],           # 例: 'smtp.gmail.com'
    port: ENV['SMTP_PORT'],                 # 例: 587
    domain: ENV['SMTP_DOMAIN'],             # 例: 'your-app.com'
    user_name: ENV['SMTP_USERNAME'],        # 例: 'your-email@gmail.com'
    password: ENV['SMTP_PASSWORD'],          # 例: 'your-app-password'
    authentication: ENV['SMTP_AUTHENTICATION'], # 例: 'plain'
    enable_starttls_auto: ENV['SMTP_ENABLE_STARTTLS_AUTO'] == 'true'
  }
end

🔐 環境変数の設定
本番サーバーでの環境変数

# アプリケーション設定
APP_HOST=your-app.com
APP_PROTOCOL=https

# SMTP設定（Gmailの例）
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=your-app.com
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
