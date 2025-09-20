# 🔐 管理者認証機能実装方針

## 📋 概要

映画館サイトの管理者機能にセキュリティを強化するため、管理者認証機能を実装します。
現在は誰でも管理者ページにアクセス可能な状態のため、早急な対応が必要です。

## 🚨 現在の問題点

### **セキュリティリスク**
- ❌ 管理者ページに認証チェックが無い
- ❌ 誰でも `/admin/*` にアクセス可能
- ❌ 管理者権限の区別がない
- ❌ ログインしていなくても管理機能が使える

### **影響範囲**
```bash
# 現在誰でもアクセス可能な管理者ページ
GET    /admin/movies           # 映画一覧・編集・削除
GET    /admin/schedules        # スケジュール管理
GET    /admin/reservations      # 予約管理
```

## 🎯 実装目標

### **Phase 1: 基本的な管理者認証**
1. **ログイン必須化**: 管理者ページへのアクセスにはログインが必要
2. **管理者権限チェック**: ログインユーザーが管理者かどうかを判定
3. **アクセス制御**: 一般ユーザーは管理者ページにアクセス不可

### **Phase 2: 管理者機能の拡張**
1. **管理者ダッシュボード**: 管理者専用のトップページ
2. **管理者専用ナビゲーション**: 管理者メニューの追加
3. **権限の細分化**: 管理者レベルによる機能制限

## 🛠️ 技術実装方針

### **1. データベース設計**

#### **Userモデルの拡張**
```ruby
# app/models/user.rb
class User < ApplicationRecord
  # 既存のDevise設定
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable
  
  # 管理者フラグの追加
  validates :admin, inclusion: { in: [true, false] }
  
  # 管理者かどうかを判定するメソッド
  def admin?
    admin == true
  end
  
  # 既存の関連
  has_many :reservations
end
```

#### **マイグレーション**
```ruby
# db/migrate/xxx_add_admin_to_users.rb
class AddAdminToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_index :users, :admin
  end
end
```

### **2. コントローラー認証**

#### **管理者コントローラーの基底クラス**
```ruby
# app/controllers/admin/base_controller.rb
module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!      # ログイン必須
    before_action :check_admin_permission  # 管理者権限チェック
    
    private
    
    def check_admin_permission
      unless current_user&.admin?
        flash[:alert] = '管理者権限が必要です。'
        redirect_to root_path
      end
    end
  end
end
```

#### **既存コントローラーの修正**
```ruby
# app/controllers/admin/movies_controller.rb
module Admin
  class MoviesController < BaseController  # ApplicationController → BaseController
    # 既存のメソッドはそのまま
    # 認証は BaseController で自動処理
  end
end
```

### **3. ルーティング保護**

#### **管理者ルートの保護**
```ruby
# config/routes.rb
Rails.application.routes.draw do
  # 既存のルート...
  
  # 管理者機能（認証必須）
  namespace :admin do
    # 管理者ダッシュボード
    root 'dashboard#index'
    
    # 既存の管理者機能
    resources :movies, only: %i[index new create edit update destroy show]
    resources :schedules, only: %i[index show edit update destroy]
    resources :reservations, only: %i[index new create show update destroy]
  end
end
```

### **4. ビューの更新**

#### **管理者専用ナビゲーション**
```erb
<!-- app/views/layouts/_admin_header.html.erb -->
<% if user_signed_in? && current_user.admin? %>
  <div class="admin-nav bg-red-900/20 border-b border-red-500/30">
    <div class="mx-auto max-w-6xl px-4 py-2">
      <nav class="flex items-center gap-4 text-sm">
        <%= link_to '管理者ダッシュボード', admin_root_path, class: "text-red-300 hover:text-red-100" %>
        <%= link_to '映画管理', admin_movies_path, class: "text-red-300 hover:text-red-100" %>
        <%= link_to 'スケジュール管理', admin_schedules_path, class: "text-red-300 hover:text-red-100" %>
        <%= link_to '予約管理', admin_reservations_path, class: "text-red-300 hover:text-red-100" %>
      </nav>
    </div>
  </div>
<% end %>
```

#### **管理者ダッシュボード**
```erb
<!-- app/views/admin/dashboard/index.html.erb -->
<div class="admin-dashboard">
  <h1 class="text-3xl font-bold text-brand-gold mb-8">🎬 管理者ダッシュボード</h1>
  
  <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
    <!-- 映画管理 -->
    <div class="card-surface">
      <h2 class="text-xl font-semibold text-brand-gold mb-4">🎭 映画管理</h2>
      <p class="text-gray-300 mb-4">映画の登録・編集・削除</p>
      <%= link_to '映画一覧', admin_movies_path, class: "btn-primary" %>
    </div>
    
    <!-- スケジュール管理 -->
    <div class="card-surface">
      <h2 class="text-xl font-semibold text-brand-gold mb-4">📅 スケジュール管理</h2>
      <p class="text-gray-300 mb-4">上映スケジュールの管理</p>
      <%= link_to 'スケジュール一覧', admin_schedules_path, class: "btn-primary" %>
    </div>
    
    <!-- 予約管理 -->
    <div class="card-surface">
      <h2 class="text-xl font-semibold text-brand-gold mb-4">🎫 予約管理</h2>
      <p class="text-gray-300 mb-4">予約の確認・管理</p>
      <%= link_to '予約一覧', admin_reservations_path, class: "btn-primary" %>
    </div>
  </div>
</div>
```

## 📅 実装スケジュール

### **Phase 1: 基本認証（優先度: 高）**
- [x] **Day 1**: データベースマイグレーション（adminカラム追加）
- [x] **Day 1**: Userモデルの更新（admin?メソッド追加）
- [x] **Day 2**: Admin::BaseControllerの作成
- [x] **Day 2**: 既存管理者コントローラーの修正
- [x] **Day 3**: テスト・動作確認

### **Phase 2: UI改善（優先度: 中）**
- [x] **Day 4**: 管理者ダッシュボードの作成
- [x] **Day 4**: 管理者専用ナビゲーションの追加
- [x] **Day 5**: 管理者ページのスタイリング改善
- [x] **Day 5**: レスポンシブ対応

### **Phase 3: 機能拡張（優先度: 低）**
- [ ] **Day 6**: 管理者権限の細分化
- [ ] **Day 6**: 管理者専用の統計機能
- [ ] **Day 7**: 管理者ログ機能
- [ ] **Day 7**: 管理者設定ページ

## 🔧 実装手順

### **Step 1: データベース準備**
```bash
# マイグレーションファイルの生成
rails generate migration AddAdminToUsers admin:boolean

# マイグレーション実行
rails db:migrate

# 既存ユーザーに管理者権限を付与（必要に応じて）
rails console
User.first.update(admin: true)
```

### **Step 2: コントローラー認証**
```bash
# Admin::BaseControllerの作成
touch app/controllers/admin/base_controller.rb

# 既存コントローラーの修正
# app/controllers/admin/movies_controller.rb
# app/controllers/admin/schedules_controller.rb
# app/controllers/admin/reservations_controller.rb
```

### **Step 3: ルーティング更新**
```bash
# config/routes.rbの更新
# 管理者ダッシュボードのルート追加
```

### **Step 4: ビュー作成**
```bash
# 管理者ダッシュボードの作成
mkdir -p app/views/admin/dashboard
touch app/views/admin/dashboard/index.html.erb

# 管理者専用ヘッダーの作成
touch app/views/layouts/_admin_header.html.erb
```

## 🧪 テスト方針

### **認証テスト**
```ruby
# spec/controllers/admin/movies_controller_spec.rb
RSpec.describe Admin::MoviesController, type: :controller do
  describe '認証チェック' do
    context '未ログインユーザー' do
      it 'ログインページにリダイレクトされる' do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end
    
    context '一般ユーザー' do
      before { sign_in create(:user, admin: false) }
      
      it 'トップページにリダイレクトされる' do
        get :index
        expect(response).to redirect_to(root_path)
      end
    end
    
    context '管理者ユーザー' do
      before { sign_in create(:user, admin: true) }
      
      it '管理者ページにアクセスできる' do
        get :index
        expect(response).to have_http_status(:success)
      end
    end
  end
end
```

## 🚀 デプロイ時の注意点

### **本番環境での管理者設定**
```bash
# 本番環境で管理者ユーザーを作成
rails console -e production
User.create!(
  name: '管理者',
  email: 'admin@example.com',
  password: 'secure_password',
  admin: true
)
```

### **セキュリティ設定**
- 管理者パスワードの強度設定
- 管理者アクセスのログ監視
- 定期的な管理者権限の見直し

## 📊 成功指標

### **Phase 1完了時**
- ✅ 未ログインユーザーは管理者ページにアクセス不可
- ✅ 一般ユーザーは管理者ページにアクセス不可
- ✅ 管理者ユーザーのみ管理者ページにアクセス可能

### **Phase 2完了時**
- ✅ 管理者ダッシュボードが正常に表示される
- ✅ 管理者専用ナビゲーションが機能する
- ✅ 管理者ページのUIが統一されている

### **Phase 3完了時**
- ✅ 管理者権限の細分化が実装されている
- ✅ 管理者専用機能が追加されている
- ✅ セキュリティが強化されている

---

## 📝 備考

- **緊急度**: 高（セキュリティリスクのため）
- **工数**: 約1週間（Phase 1-2）
- **影響範囲**: 管理者機能全体
- **テスト**: 必須（認証機能のため）

この実装により、映画館サイトの管理者機能が安全に利用できるようになります。
