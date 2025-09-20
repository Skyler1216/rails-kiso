# ========================================
# 🎬 映画館サイト ルーティング設定
# ========================================
# 
# このファイルは映画館サイトのURLルーティングを定義します。
# 一般ユーザー向けの公開機能と管理者向けの管理機能を分離しています。
# 
# ルート確認方法: rails routes
# 特定ルート確認: rails routes | grep movies
#

Rails.application.routes.draw do
  # ========================================
  # 👤 ユーザー認証（Devise）
  # ========================================
  # ログイン・ログアウト・新規登録機能を自動生成
  devise_for :users
  # 生成されるルート例:
  # GET    /users/sign_in     (ログインページ)
  # POST   /users/sign_in     (ログイン処理)
  # DELETE /users/sign_out    (ログアウト)
  # GET    /users/sign_up     (新規登録ページ)
  # POST   /users             (新規登録処理)

  # ========================================
  # 🏥 ヘルスチェック
  # ========================================
  # アプリケーションの稼働状況を確認するエンドポイント
  get 'up' => 'rails/health#show', as: :rails_health_check
  # アクセス: GET /up

  # ========================================
  # 🎬 映画関連（一般ユーザー向け）
  # ========================================
  
  # 映画一覧・詳細表示（個別定義）
  get '/movies', to: 'movies#index'        # GET /movies → 映画一覧ページ
  get '/movies/:id', to: 'movies#show'     # GET /movies/1 → 映画詳細ページ

  # 映画予約機能（ネストしたルート）
  resources :movies, only: %i[index show] do
    # 映画の予約ページ
    get 'reservation', on: :member          # GET /movies/:id/reservation → 予約ページ

    # スケジュール経由での予約作成
    resources :schedules, only: [] do
      # 座席選択・予約作成ページ
      resources :reservations, only: [:new]  # GET /movies/:movie_id/schedules/:schedule_id/reservations/new
    end
  end

  # 予約作成処理
  resources :reservations, only: [:create]  # POST /reservations → 予約作成処理

  # ========================================
  # 🪑 座席関連
  # ========================================
  # 座席一覧表示
  resources :sheets, only: [:index]        # GET /sheets → 座席一覧ページ

  # ========================================
  # ⚙️ 管理画面（admin名前空間）
  # ========================================
  # 管理者専用の機能を分離
  namespace :admin do
    # 映画管理
    resources :movies, only: %i[index new create edit update destroy show] do
      # 映画に紐づくスケジュール作成
      resources :schedules, only: %i[new create]
    end
    # 生成されるルート例:
    # GET    /admin/movies           (映画一覧)
    # GET    /admin/movies/new       (映画新規作成)
    # POST   /admin/movies           (映画作成処理)
    # GET    /admin/movies/:id/edit  (映画編集)
    # PATCH  /admin/movies/:id       (映画更新)
    # DELETE /admin/movies/:id       (映画削除)
    # GET    /admin/movies/:id       (映画詳細)

    # スケジュール管理（独立）
    resources :schedules, only: %i[index show edit update destroy]
    # 生成されるルート例:
    # GET    /admin/schedules        (スケジュール一覧)
    # GET    /admin/schedules/:id    (スケジュール詳細)
    # GET    /admin/schedules/:id/edit (スケジュール編集)
    # PATCH  /admin/schedules/:id   (スケジュール更新)
    # DELETE /admin/schedules/:id   (スケジュール削除)

    # 予約管理
    resources :reservations, only: %i[index new create show update destroy]
    # 生成されるルート例:
    # GET    /admin/reservations     (予約一覧)
    # GET    /admin/reservations/new (予約新規作成)
    # POST   /admin/reservations     (予約作成処理)
    # GET    /admin/reservations/:id (予約詳細)
    # PATCH  /admin/reservations/:id (予約更新)
    # DELETE /admin/reservations/:id (予約削除)
  end

  # ========================================
  # 🏠 ルートページ
  # ========================================
  # サイトのトップページ（映画一覧）
  root 'movies#index'                      # GET / → 映画一覧ページ
end
