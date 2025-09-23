# 🎬 複数劇場対応 方針メモ

## 🎯 目的
- 現在は「1劇場 + 複数スクリーン」想定。これを複数劇場でも管理できるようにする。
- 座席は全劇場共通レイアウト（3 x 5）。スクリーン単位で管理する。
- 予約時には劇場をユーザーに選ばせ、スクリーンは内部管理とする。
- ダブルブッキング（同一スクリーン・座席・時間帯の重複予約）を確実に防ぐ。
- RSpec で仕様変更をカバーする。

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
  t.integer :capacity, null: false, default: 15, comment: '座席数(3x5)'
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
1. マイグレーション作成：`theaters` 新規、`screens` に `theater_id` 追加、既存スクリーンをデフォルト劇場に紐付け。
2. モデル更新：`Theater` モデル作成、`Screen` に関連付けとバリデーション追加。
3. 管理画面拡張：劇場一覧・作成・編集 UI、スクリーン管理で劇場を選択可能に。
4. スケジュール管理：劇場フィルタ／表示を追加し、UI 上でスクリーン→劇場を辿れるようにする。
5. 予約フロー：
   - ユーザーに劇場選択 → 作品の上映スケジュールを劇場単位で表示。
   - スクリーンは内部で座席と紐付ける。
   - 既存の座席選択 UI を劇場対応に改修。
6. RSpec テスト追加：
   - モデル：劇場・スクリーン関連、予約の重複防止。
   - システム：劇場選択から予約完了までのフロー、重複予約警告。

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
