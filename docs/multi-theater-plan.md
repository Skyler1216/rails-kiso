# 🎬 複数劇場対応 方針メモ

## 🎯 目的
- 現在は「1劇場 + 複数スクリーン」想定。これを複数劇場でも管理できるようにする。
- 座席は全劇場共通レイアウト（3 x 5）。スクリーン単位で管理する。
- 予約時には劇場をユーザーに選ばせ、スクリーンは内部管理とする。
- ダブルブッキング（同一スクリーン・座席・時間帯の重複予約）を確実に防ぐ。
- RSpec で仕様変更をカバーする。

## 📋 アクションアイテム（2025-09-22 時点）

### データベース / スキーマ
- [x] `theaters` テーブルを作成し、既存スクリーン移行用のデフォルト劇場を投入する。
  （対応ファイル: db/migrate/20250922160000_create_theaters_and_extend_screens.rb, db/schema.rb）
- [x] `screens` テーブルに `theater_id` を追加し、外部キーを設定する。
  （対応ファイル: db/migrate/20250922160000_create_theaters_and_extend_screens.rb, db/schema.rb）
- [x] `screens` テーブルから `capacity` / `is_active` を削除する。
  （対応ファイル: db/migrate/20250922160500_remove_screen_capacity_and_is_active.rb, db/schema.rb）

### モデル / バリデーション
- [x] `Theater` モデルを追加し、`has_many :screens, dependent: :destroy` を定義する。
  （対応ファイル: app/models/theater.rb）
- [x] `Screen` モデルを更新し、`belongs_to :theater` や `has_many :schedules`、バリデーション（`name` 必須）を追加する。
  （対応ファイル: app/models/screen.rb）
- [x] 予約モデルのダブルブッキング防止バリデーションを `theater` を含んだシナリオでも確認できるよう追加テストする。
  （対応ファイル: spec/models/reservation_spec.rb, spec/factories/theaters.rb, spec/factories/screens.rb, spec/factories/schedule.rb, spec/factories/sheet.rb, spec/factories/reservations.rb）

### 管理画面（Admin）
- [x] スケジュール・予約フォームでスクリーン選択時に劇場名を表示し、コントローラで `screen.theater` を eager load する。
  （対応ファイル: app/views/admin/schedules/_form.html.erb, app/controllers/admin/schedules_controller.rb, app/controllers/admin/reservations_controller.rb）
- [x] 劇場の CRUD 画面を追加し、スクリーン編集時に劇場を選択できるようにする。（対応ファイル: config/routes.rb, app/controllers/admin/theaters_controller.rb, app/views/admin/theaters/index.html.erb, app/views/admin/theaters/new.html.erb, app/views/admin/theaters/show.html.erb, app/views/admin/theaters/_form.html.erb, app/views/layouts/_header.html.erb）
- [ ] スケジュール一覧／詳細で劇場別フィルタや表示を整備する。（対応ファイル: ）

### 予約フロー（フロント）
- [ ] ユーザー向け予約フローに劇場選択ステップを導入する。（対応ファイル: ）
- [ ] 劇場によってスケジュールを絞り込んだ座席選択 UI を実装する。（対応ファイル: ）

### テスト
- [ ] 劇場・スクリーン関連のモデルスペックを追加する。（対応ファイル: ）
- [ ] 劇場選択〜予約完了までのシステムスペックを追加する。（対応ファイル: ）

## 🏗️ テーブル設計（現行スキーマを踏まえた変更）

### theaters（新規）
```ruby
create_table :theaters do |t|
  t.string  :name,    null: false, comment: '劇場名'
  t.string  :address, null: false, comment: '所在地'
  t.string  :phone,               comment: '電話番号'
  t.boolean :is_active, default: true, null: false, comment: 'ステータス'
  t.timestamps
end
```

### screens（既存に追加）
```ruby
change_table :screens do |t|
  t.references :theater, null: false, foreign_key: true, comment: '劇場ID'
end
```

> 既存スクリーンはマイグレーションで「デフォルト劇場」を作成し紐付ける。

### その他
- **schedules**: 現状の `movie_id` + `screen_id` を維持。劇場は `screen.theater` から判別できるため追加カラム無し。
- **sheets**: `screen_id` を持つため変更不要（座席配置はスクリーン単位で自動生成するか移行スクリプトで対応）。
- **reservations**: 現行の複合ユニーク `[:date, :schedule_id, :sheet_id]` がダブルブッキング防止に有効。劇場 ID 追加は不要。

## 🧩 モデル・バリデーション
- **Theater**: `has_many :screens`
- **Screen**: `belongs_to :theater`
- **Schedule**: `belongs_to :movie`, `belongs_to :screen`
- **Reservation**: `belongs_to :schedule`, `belongs_to :screen`, `belongs_to :sheet`

ダブルブッキング防止：
```ruby
class Reservation < ApplicationRecord
  validate :no_double_booking

  private

  def no_double_booking
    scope = Reservation.where(schedule_id: schedule_id,
                              screen_id: screen_id,
                              sheet_id: sheet_id,
                              date: date)
    scope = scope.where.not(id: id) if persisted?
    errors.add(:base, 'その座席はすでに予約されています') if scope.exists?
  end
end
```

> DB制約（既存ユニーク）とアプリ側バリデーションの両方でチェックする。

## 🛠️ 実装手順案
1. スキーマ拡張とデータ移行（劇場テーブル作成・スクリーンが劇場に属する状態へ移行）。
2. モデル関連付けとバリデーション整備。
3. 管理画面での劇場／スクリーン管理 UI の整備。
4. スケジュール管理に劇場コンテキストを組み込み、表示やフィルタを追加。
5. 予約フローを劇場選択から座席確定までつなげる。
6. モデル／システムテストで複数劇場シナリオを担保する。

## 🔄 既存仕様とのすり合わせ
- 作品 × 劇場の組み合わせは `screen.theater` を通じて管理可能。必要なら `theater_movies` のような中間テーブルも検討するが初期段階では不要。
- スケジュールが劇場ごとに異なる場合は、スクリーンが劇場に紐づくため自然に区別できる。
- 座席（sheets）はスクリーンに紐づくため、全劇場同じレイアウトでも各スクリーンが独自に保持する。

## 🧪 テスト観点
- 同一スクリーン・時間帯・座席の予約が複数作成されない。
- 劇場を変えると同じ作品でも別スケジュールを持てる。
- 劇場選択 UI が正しく機能し、予約フローで劇場選択 → スケジュール → 座席 → 確認が成立する。
- 既存の管理 UI で劇場・スクリーンを操作できる。

## 📌 補足
- 座席生成：スクリーン作成時に自動で 3x5 の座席を作るサービス or マイグレーションを用意しておくと運用が楽。
- データ移行：既存スクリーン／スケジュール／予約は「デフォルト劇場」に一旦割り当て、後で必要に応じて劇場を追加する。
- 既存コードでは座席選択に JS ロジックが入っているので、劇場対応後も動作するように調整する。

---
このメモをベースに、実際の変更点は段階的に PR を分けて実装していく。
