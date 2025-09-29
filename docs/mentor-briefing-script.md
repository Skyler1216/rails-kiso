# メンター共有用トーク原稿

このドキュメントは、画面共有しながら順番に読み上げることを想定しています。各トピックで参照したソースコードやマイグレーションのファイルパスも併記しているので、必要に応じて該当ファイルを開きながら説明してください。

---

## 1. イントロダクション
- 課題の目的
  - 単館前提だった映画館予約サイトを「複数劇場・複数スクリーン」でも運用できるように拡張。
  - ダブルブッキング（同じ上映・同じ座席を二重予約）が発生しない構造にする。
  - 変更内容を RSpec で網羅的に検証し、`bundle exec rspec` がグリーンになる状態を作る。
- 参考ドキュメント
  - 実装方針の詳細: `docs/multi-theater-plan.md`
  - テスト戦略: `docs/rspec-testing-guide.md`

## 2. データモデルとスキーマ変更
- 追加／変更したテーブル定義と関連ファイル
  - `theaters` テーブル（新規）
    - カラム: `name`, `address`, `phone`, `is_active`, `timestamps`
    - 実装: `db/migrate/20250922160000_create_theaters_and_extend_screens.rb`, `db/schema.rb`
    - マイグレーション内でデフォルト劇場を作成し、既存スクリーンをそこへ紐付ける移行処理を実施。
  - `screens` テーブル（既存拡張）
    - `theater_id` を追加（NOT NULL + 外部キー）
    - `capacity`, `is_active` カラムを削除
    - 実装: 同上マイグレーション、`db/schema.rb`
- 既存テーブルの扱い
  - `schedules`: `screen.theater` から劇場を特定できるためスキーマ変更なし（参照: `app/models/schedule.rb`）
  - `sheets`: スクリーンに紐づく 3×5 座席レイアウトを維持（参照: `app/models/sheet.rb`）
  - `reservations`: 複合ユニーク制約 `[:date, :schedule_id, :sheet_id]` を継続しダブルブッキング防止（参照: `app/models/reservation.rb`）
- モデル関連付けとバリデーション
  - `app/models/theater.rb`
    - `has_many :screens, dependent: :destroy`
    - ネストされたスクリーン名の重複チェックを実装
  - `app/models/screen.rb`
    - `belongs_to :theater`
    - 劇場内でスクリーン名が重複しないよう `uniqueness scope: :theater_id`
    - `after_create` で標準座席（3×5）を自動生成
  - `app/models/reservation.rb`
    - モデル側でも重複チェックを行い、DB 制約との二重防御を維持

## 3. 管理画面の主な改善
- 劇場管理
  - コントローラ: `app/controllers/admin/theaters_controller.rb`
  - ビュー: `app/views/admin/theaters/` 配下（`_form.html.erb`, `_screen_fields_row.html.erb`, `index.html.erb`, `show.html.erb`, `new.html.erb`）
  - JS: `app/javascript/theater_screen_fields.js`（スクリーン追加／削除を動的に行う）
  - 参考テスト: `spec/requests/admin/theaters_spec.rb`
- スケジュール管理
  - コントローラ: `app/controllers/admin/schedules_controller.rb`
  - ビュー: `app/views/admin/schedules/index.html.erb`, `show.html.erb`, `_form.html.erb`
  - ダッシュボード: `app/controllers/admin/dashboard_controller.rb`, `app/views/admin/dashboard/index.html.erb`
- 予約管理
  - コントローラ: `app/controllers/admin/reservations_controller.rb`
  - ビュー: `app/views/admin/reservations/index.html.erb`, `_form.html.erb`
  - 劇場フィルタのリクエストテスト: `spec/requests/admin/reservations_spec.rb`

## 4. ユーザー向け予約フロー
- 変更点
  - 映画詳細ページで「劇場 → 日付 → スケジュール → 座席」の順に選択する UI に変更。
  - 座席選択画面では劇場名と座席番号のみを表示し、スクリーン名は内部管理に留めて操作を簡略化。
- 関連ファイル
  - コントローラ: `app/controllers/movies_controller.rb`, `app/controllers/reservations_controller.rb`
  - ビュー: `app/views/movies/show.html.erb`, `app/views/movies/reservation.html.erb`, `app/views/reservations/new.html.erb`
  - システムテスト: `spec/system/multi_theater_reservation_spec.rb`, `spec/system/reservation_flow_spec.rb`

## 5. RSpec テスト戦略（docs/rspec-testing-guide.md を参照）
- テストカテゴリと主なファイル
  - **モデル**
    - `spec/models/theater_spec.rb`: 劇場名の必須／重複、ネストされたスクリーンの検証
    - `spec/models/screen_spec.rb`: 劇場内ユニーク制約
    - `spec/models/reservation_spec.rb`: ダブルブッキング防止やメール形式
  - **コントローラー**
    - `spec/controllers/movies_controller_spec.rb`: 公開ページの挙動、検索フィルタ
    - `spec/controllers/admin/*_controller_spec.rb`: 認証・認可、CRUD ステータス
  - **リクエスト**
    - `spec/requests/admin/schedules_spec.rb`: 劇場フィルタが HTML 出力に反映されるか検証
    - `spec/requests/admin/reservations_spec.rb`: 予約一覧での劇場フィルタ
  - **システム**
    - `spec/system/admin_management_spec.rb`: 管理画面の CRUD
    - `spec/system/movie_browsing_spec.rb`: 映画一覧の検索／フィルタ
    - `spec/system/reservation_flow_spec.rb`: 予約フロー全体
    - `spec/system/user_authentication_spec.rb`: Devise を使った登録・ログイン
- テスト実行前提
  - MySQL を使用するため `bin/rails db:test:prepare` とテスト DB の起動が必要。
  - `bundle exec rspec` で全カテゴリが成功することを確認済み。

## 6. 結果と今後の検討事項
- 現状の成果
  - モデル／コントローラー／リクエスト／システムの全テストがグリーン。
  - 複数劇場でもダブルブッキングせず予約できることを確認。
  - 管理・ユーザー双方の UI を劇場選択前提に整備済み。
- 今後検討したいタスク
  - 雛形のまま残っている helper／view spec の整理（不要なら削除、必要なら実装）。
