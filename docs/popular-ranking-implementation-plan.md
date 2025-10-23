人気作品ランキング実装方針
============================

ゴール
----
- ルートパス(`/`)で映画一覧に加えて人気作品ランキングを表示する。
- ランキングは過去30日分の予約データ（予約を行った日時ベース）を集計した結果を使う。
- 予約件数の集計は毎日0時にバッチで再算出し、各日のスナップショットを保存する。

データモデル案
-------------
- 新テーブル: `daily_movie_rankings`
  - `id`: 主キー
  - `aggregated_on`: `date` 型。集計日 (例: 2024-06-01 分のランキング)。
  - `movie_id`: 作品ID。`movies` テーブルを参照。
  - `reservation_count`: 過去30日分の予約件数合計。
  - `rank_position`: 集計日の順位 (1 始まり)。日付と作品だけで要件は満たせるが、「トップ10」表示を高速化するために保持。
  - `created_at` / `updated_at`
- 制約・インデックス
  - `aggregated_on` と `movie_id` のユニーク制約。
  - `aggregated_on` と `rank_position` の複合インデックスで日付別の並び取得を高速化。
- モデル `DailyMovieRanking`
  - `belongs_to :movie`
  - スコープ例: `top(limit)`。

集計ロジック
-----------
- 対象期間: 集計日から遡って30日間 (`target_date.prev_day(29)` 〜 `target_date`) の予約データを対象。
- 予約データは `Reservation` を起点に `schedule` → `movie` を辿って劇場に依存せず集計する。
- 方針:
  1. 既存レコードを (`aggregated_on = target_date`) で削除。
  2. 期間内（集計日を含む過去30日間）に予約されたレコードを `movie_id` 単位でグルーピングし件数を取得。基準は `created_at`（予約を受け付けた日時）。
  3. 件数順にソートして順位を割り当て、`DailyMovieRanking` に `insert_all` もしくはトランザクションで保存。
  4. 予約がゼロ件の作品はランキングに含めない。表示時には必要に応じて空欄表示。

バッチ実行
---------
- 新しい rake タスク `ranking:refresh_daily` を作成。
  - デフォルト `target_date = Time.zone.today`。
  - `ENV['TARGET_DATE']` 指定で任意日付を再集計できるようにする。
  - トランザクション内で upsert。
- `config/schedule.rb` に「毎日0時」にタスクを登録 (JST 前提)。

表示更新
-------
- `MoviesController#index` でランキング用データを読み込む。
  - 画面表示は `DailyMovieRanking.where(aggregated_on: Time.zone.today)` を取得し、データが無い場合は最新日付をフォールバック。
  - 取得時には `includes(:movie)` で N+1 を避ける。
- ビューにランキングセクションを追加。
  - 作品名クリックで詳細ページ (`movie_path(movie)`) へ遷移できるようリンク化。
  - 予約ページへの導線は既存の「予約する」導線を利用。

テスト方針
--------
- モデルスペック: `DailyMovieRanking` のバリデーション／スコープ動作確認。
- サービス／タスクスペック: 集計ロジックが想定通りの件数・順位を出すことを検証。
- リクエストまたはシステムスペック: ルートページでランキングが表示され、リンクが機能することを確認。






## 🧭 cron定時処理自動化の実装概要

### 目的
Railsアプリケーションで定時処理（バッチ）を自動化するため、`whenever` gemを使用して開発環境でもcronによるタスク実行を設定しました。

### 実装内容
- **予約リマインドメール送信**：毎日19:00（JST）
- **人気ランキング更新**：毎日0:00（JST）

---

## 🧩 実装手順

### 1. cronサービスの動作確認

WSL（Ubuntu）環境でcronサービスが稼働していることを確認：

```bash
sudo service cron status
```

**結果：**
```
Active: active (running)
```

✅ cronがバックグラウンドで常駐しており、定時実行が可能な状態であることを確認

### 2. wheneverの設定

`config/schedule.rb`に以下の設定を追加：

```ruby
set :output, 'log/whenever.log'
set :environment, 'development'
env :TZ, 'Asia/Tokyo'

# 毎日19:00（JST）に予約リマインドメールを送信
every 1.day, at: '7:00 pm' do
  rake 'reservation:send_reminders'
end

# 毎日0:00（JST）に人気ランキングを更新
every 1.day, at: '0:00 am' do
  rake 'ranking:refresh_daily'
end
```

### 3. cronへの登録

プロジェクトルートで以下のコマンドを実行：
config/schedule.rbに書いたWheneverのスケジュール設定からcron形式のエントリを生成し、それを現在のユーザーの
crontabに書き込むコマンドです。Railsアプリ側で定義した定期実行タスクを、本番のcronに反映させるために使います。

```bash
bundle exec whenever --update-crontab
```

**出力：**
```
[write] crontab file updated
```

✅ cronにスケジュールが書き込まれたことを確認

### 4. 現状のcron登録内容の確認

```bash
crontab -l
```

**出力例：**
```
# Begin Whenever generated tasks for: development
0 0 * * * /bin/bash -l -c 'cd /home/shirota/projects/rails-kiso && RAILS_ENV=development bundle exec rake ranking:refresh_daily --silent >> log/whenever.log 2>&1'
0 19 * * * /bin/bash -l -c 'cd /home/shirota/projects/rails-kiso && RAILS_ENV=development bundle exec rake reservation:send_reminders --silent >> log/whenever.log 2>&1'
# End Whenever generated tasks for: development
```

✅ `ranking:refresh_daily`と`reservation:send_reminders`の2つのタスクが登録されていることを確認

### 5. 動作確認（手動実行）

```bash
bundle exec rake ranking:refresh_daily

```
日付を指定したい場合は
```bash
TARGET_DATE=2025-10-13 bundle exec rake ranking:refresh_daily

```

✅ エラーなく実行されることを確認

cron経由ではRakeに`--silent`が付与されるため標準出力は抑制されます。想定どおりに完了したかは`log/development.log`（Railsのログ）を確認するか、タスク内で明示的にログ出力するよう変更してください。

### 6. cronの永続化

- cronはOS常駐サービスのため、**OS/WSLが稼働しcronデーモンが起動している間はターミナルを閉じても動作継続**（PCやWSLを終了するとジョブは実行されません）
- タスクの時刻・内容を変更した際は以下で再登録：

```bash
bundle exec whenever --update-crontab --set environment=development
```

- 停止したい場合：

```bash
bundle exec whenever --clear-crontab --set environment=development
```

---

## ✅ 実装結果

| 項目 | 内容 |
|------|------|
| **環境** | 開発PC（WSL / Ubuntu） |
| **定時実行機構** | cron + whenever |
| **登録環境** | development |
| **実行内容** | リマインドメール送信・人気ランキング更新 |
| **ログ出力** | cron経由は標準出力なし（Railsログで確認） |
| **永続性** | OS/WSLとcronデーモンが稼働中なら維持 |
| **検証** | 手動実行・crontab内容確認済み |

---

## 💡 重要なポイント

### 環境の独立性
- Railsの「開発環境」と「本番環境」は独立しており、`whenever`登録時の`--set environment`によって動作先が変わります
### wheneverの仕組み
- `whenever`は`config/schedule.rb`をもとにcronエントリを自動生成し、OSのスケジューラに登録します
### cronの独立性
- cronはRailsとは独立して動作しますが、OS自体が稼働しcronデーモンが起動している必要があります（PC/WSLを終了するとジョブは実行されません）
