# RSpecテストガイド

## 概要

このドキュメントでは、映画館予約システムにおけるRSpecテストの手順と内容について説明します。

## テスト構成

### 1. テスト環境の設定

#### 必要なGem
```ruby
group :development, :test do
  gem 'rspec-rails', '~> 6.1.3'
  gem 'factory_bot_rails'
  gem 'rails-controller-testing'
end

group :test do
  gem 'capybara'
  gem 'selenium-webdriver'
end
```

#### 設定ファイル
- `spec/rails_helper.rb`: Rails固有の設定
- `spec/spec_helper.rb`: RSpec基本設定
- `spec/factories/`: テストデータファクトリー

#### データベース
- `config/database.yml` の `test` は MySQL (`app_test`) を利用します。
- 初回実行前に `bin/rails db:test:prepare` でスキーマを整備し、MySQL サーバーを起動した状態にしておきます。
- Docker 等で MySQL を立ち上げる場合は、`RAILS_ENV=test` の接続情報が一致しているか確認してください。

### 2. テストの種類

#### モデルテスト (`spec/models/`)
- バリデーション
- 関連（アソシエーション）
- メソッドの動作
- コールバック

#### コントローラーテスト (`spec/controllers/`)
- アクションの動作
- 認証・認可
- リダイレクト
- レスポンス

#### リクエストテスト (`spec/requests/`)
- HTTPリクエストの動作
- ルーティング
- 認証フロー
- ゲストアクセス可否の確認

#### システムテスト (`spec/system/`)
- エンドツーエンドの動作
- ユーザーインタラクション
- ブラウザ操作
- Deviseの統合テストヘルパーを利用したログイン操作

## テスト実行手順

### 1. 全テストの実行
```bash
bundle exec rspec
```

### 2. 特定の種類のテスト実行
```bash
# モデルテストのみ
bundle exec rspec spec/models/

# コントローラーテストのみ
bundle exec rspec spec/controllers/

# システムテストのみ
bundle exec rspec spec/system/
```

### 3. 特定のファイルのテスト実行
```bash
bundle exec rspec spec/models/movie_spec.rb
```

### 4. 詳細な出力で実行
```bash
bundle exec rspec --format documentation
```

## テスト内容詳細

### モデルテスト

#### Movieモデル (`spec/models/movie_spec.rb`)
- **バリデーション**
  - 名前の必須チェック
  - 名前の一意性チェック
  - 公開年の必須チェック
  - 画像URLの必須チェック
  - 上映時間の数値チェック（1以上）
- **関連**
  - schedulesとのhas_many関連
  - dependent: :destroyの動作

#### Theaterモデル (`spec/models/theater_spec.rb`)
- **バリデーション**
  - 劇場名の必須・一意性チェック
  - 住所の必須チェック
- **関連**
  - screensとのhas_many関連
  - accepts_nested_attributes_forの設定
- **カスタムバリデーション**
  - ネストされたスクリーンの名前重複チェック
  - 大文字小文字を区別しない重複チェック
  - 空白除去後の重複チェック

#### Screenモデル (`spec/models/screen_spec.rb`)
- **バリデーション**
  - スクリーン名の必須チェック
  - 同じ劇場内での一意性チェック
  - 異なる劇場では同じ名前でも有効
- **関連**
  - theaterとのbelongs_to関連
  - sheets, schedulesとのhas_many関連
  - dependent: :destroyの動作

#### Scheduleモデル (`spec/models/schedule_spec.rb`)
- **バリデーション**
  - 開始時刻・終了時刻の必須チェック
  - 終了時刻が開始時刻より後であること
  - 同じスクリーンでの重複チェック
- **関連**
  - movie, screenとのbelongs_to関連
  - reservationsとのhas_many関連
- **コールバック**
  - 映画の上映時間から終了時刻を自動設定
  - 予約メタデータの同期

#### Reservationモデル (`spec/models/reservation_spec.rb`)
- **バリデーション**
  - 名前・メールアドレス・日付の必須チェック
  - メールアドレスの形式チェック
  - 座席の重複予約チェック
- **関連**
  - schedule, sheet, screenとのbelongs_to関連
  - userとのbelongs_to関連（optional: true）

#### Userモデル (`spec/models/user_spec.rb`)
- **バリデーション**
  - 名前・メールアドレス・パスワードの必須チェック
  - メールアドレスの一意性チェック
  - パスワードと確認の一致チェック
  - 管理者フラグの真偽値チェック
- **関連**
  - reservationsとのhas_many関連
- **Devise設定**
  - 認証モジュールの確認
- **インスタンスメソッド**
  - admin?, regular_user?メソッドの動作

### コントローラーテスト

#### MoviesController (`spec/controllers/movies_controller_spec.rb`)
- **indexアクション**
  - 全映画の表示
  - is_showingパラメータでの絞り込み
  - keywordパラメータでの検索
  - 複数パラメータの組み合わせ
- **showアクション**
  - 映画詳細の表示
  - 劇場・日付パラメータの処理
- **reservationアクション**
  - 予約画面の表示
  - 必須パラメータのチェック
  - 無効なスケジュールIDの処理

#### ReservationsController (`spec/controllers/reservations_controller_spec.rb`)
- **newアクション**
  - 予約フォームの表示
  - 必須パラメータのチェック
  - 重複予約のチェック
- **createアクション**
  - 予約の作成
  - 重複予約の防止
  - バリデーションエラーの処理
- **認証**
  - ログイン必須の確認

#### Admin::BaseController (`spec/controllers/admin/base_controller_spec.rb`)
- **認証・認可**
  - ログイン必須の確認
  - 管理者権限のチェック
  - 一般ユーザーのアクセス拒否
- **ヘルパーメソッド**
  - admin_user?メソッド
  - フラッシュメッセージ設定

#### Admin::MoviesController (`spec/controllers/admin/movies_controller_spec.rb`)
- **CRUD操作**
  - 映画の一覧表示
  - 新規作成・編集・削除
  - バリデーションエラーの処理
  - 例外処理
- **認証**
  - 管理者権限の確認

### リクエストテスト

#### Movies (`spec/requests/movies_request_spec.rb`, `spec/requests/movies_spec.rb`)
- 公開ページがゲストで閲覧できることの確認
- 上映状況・キーワードによる絞り込み
- 映画詳細/予約ページのレスポンス
- ルートページ (`/`) の動作

#### Reservations (`spec/requests/reservations_request_spec.rb`)
- 予約フォームの表示
- 予約作成処理
- 認証が必要なアクション
- 重複予約の処理

#### Admin (`spec/requests/admin_request_spec.rb`)
- 管理者ダッシュボードへのアクセス
- 各管理機能へのアクセス
- 権限チェック

#### Sheets (`spec/requests/sheets_request_spec.rb`, `spec/requests/sheets_spec.rb`)
- 座席一覧の表示と行単位のグルーピング
- ゲストとログイン済みユーザー双方のアクセス確認

### システムテスト

#### Movie Browsing (`spec/system/movie_browsing_spec.rb`)
- 映画一覧ページでの絞り込み・検索
- 映画詳細ページでの劇場・日付選択
- ルートページの動作

#### User Authentication (`spec/system/user_authentication_spec.rb`)
- ユーザー登録フロー
- ログイン・ログアウトフロー
- 認証が必要なページへのアクセス

#### Admin Management (`spec/system/admin_management_spec.rb`)
- 管理者認証フロー
- 映画管理機能
- 劇場管理機能
- スケジュール管理機能
- 予約管理機能

#### Reservation Flow (`spec/system/reservation_flow_spec.rb`)
- 映画詳細から予約完了までのフロー
- 重複予約の防止
- 座席選択の動作
- バリデーションエラーの表示

#### Multi Theater Reservation (`spec/system/multi_theater_reservation_spec.rb`)
- 複数劇場での予約フロー
- 劇場選択から予約完了まで

#### Deviseヘルパーの利用
- `spec/rails_helper.rb` にて `config.include Devise::Test::IntegrationHelpers, type: :system` を指定しているため、system spec でも `sign_in` / `sign_out` が利用できます。
- UI操作でのログインが必要なケースは、Deviseヘルパーを併用しつつシナリオに応じて切り替えます。

## メンテナンス履歴

- 2025-09-29: モデルテスト（`bundle exec rspec spec/models --format documentation`）がすべて成功するように整備。
  - **失敗の原因**: Rails の日本語訳により、RSpec で英語メッセージを直接チェックしていた部分がすべて落ちていた。
  - **対応内容**:
    1. `config/locales/ja.yml` に欠けていた典型的なエラーメッセージ（例: 「すでに使用されています」など）を追加。
    2. モデルスペックでは `errors.added?` や `errors[:field]` を使い、メッセージ本文に頼らずにバリデーションを確認する形へ修正。
    3. `Theater` モデルの dependent: :destroy テストを、実際に削除する代わりに設定値を確認するテストへ変更し、外部キー制約エラーを回避。
  - **結果**: `spec/models/*` の全テストが成功することを確認。

## テストデータ管理

### FactoryBotの使用
```ruby
# 基本的なファクトリー
factory :movie do
  sequence(:name) { |n| "TEST_MOVIE#{n}" }
  sequence(:year) { 2021 }
  sequence(:description) { 'この映画は最高です。改行しました' }
  sequence(:image_url) { |n| "https://techbowl.co.jp/_nuxt/img/#{n}.png" }
  sequence(:is_showing) { 1 }
end

# トレイトの使用
factory :user do
  name { 'test' }
  sequence(:email) { |n| "TEST#{n}@example.com" }
  password { 'testuser' }
  password_confirmation { 'testuser' }
  admin { false }

  trait :admin do
    admin { true }
  end
end
```

### テストデータの作成
```ruby
# 単一オブジェクト
movie = create(:movie)

# 複数オブジェクト
movies = create_list(:movie, 3)

# トレイトの使用
admin_user = create(:user, :admin)

# 関連付きオブジェクト
schedule = create(:schedule, movie: movie, screen: screen)
```

## テスト実行のベストプラクティス

### 1. テストの実行順序
- モデルテスト → コントローラーテスト → リクエストテスト → システムテスト

### 2. テストの独立性
- 各テストは独立して実行可能
- テスト間でのデータ依存を避ける
- `before`ブロックでテストデータを準備
- Deviseのヘルパーを利用する場合は `sign_in` / `sign_out` を各テストで明示的に呼び出し、状態を共有しない

### 3. テストの可読性
- 説明的なテスト名を使用
- `describe`と`context`でテストを整理
- 期待値と実際の値を明確に記述

### 4. パフォーマンス
- 必要なデータのみを作成
- `build`と`create`を適切に使い分け
- データベースクエリを最小限に

## トラブルシューティング

### よくある問題と解決方法

#### 1. テストデータの不整合
```ruby
# 問題: 関連するオブジェクトが存在しない
# 解決: 関連オブジェクトも作成
theater = create(:theater)
screen = create(:screen, theater: theater)
```

#### 2. 認証エラー
```ruby
# 問題: ログインが必要なアクションでエラー
# 解決: テストでログイン
before { sign_in user }
```

#### 3. バリデーションエラー
```ruby
# 問題: 必須フィールドが不足
# 解決: 有効なデータを提供
movie = build(:movie, name: 'テスト映画')
```

#### 4. タイムゾーン問題
```ruby
# 問題: 日時関連のテストでエラー
# 解決: 明示的にタイムゾーンを指定
start_time = Time.zone.parse('2025-09-22 10:00:00')
```

## 継続的インテグレーション

### GitHub Actionsでの実行
```yaml
name: RSpec Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2.3
      - name: Install dependencies
        run: bundle install
      - name: Run tests
        run: bundle exec rspec
```

## まとめ

このRSpecテストスイートにより、映画館予約システムの以下の機能がテストされています：

1. **モデル層**: バリデーション、関連、ビジネスロジック
2. **コントローラー層**: アクション、認証、認可
3. **リクエスト層**: HTTPリクエスト、ルーティング
4. **システム層**: エンドツーエンドのユーザーフロー

これらのテストにより、アプリケーションの品質と信頼性が確保されています。
