module Admin
  class BaseController < ApplicationController
    # ========================================
    # 🔐 管理者認証の基底コントローラー
    # ========================================
    #
    # 全ての管理者コントローラーが継承する基底クラス
    # - ログイン必須チェック
    # - 管理者権限チェック
    # - 共通の認証処理
    #
    
    # 🔐 認証チェック: ログイン必須
    before_action :authenticate_user!
    
    # 🔐 権限チェック: 管理者権限必須
    before_action :check_admin_permission
    
    private
    
    # ========================================
    # 🔐 管理者権限チェック
    # ========================================
    #
    # 現在のユーザーが管理者権限を持っているかチェック
    # 管理者でない場合はトップページにリダイレクト
    #
    def check_admin_permission
      unless current_user&.admin?
        flash[:alert] = '🔐 管理者権限が必要です。このページにアクセスするには管理者権限が必要です。'
        redirect_to root_path
      end
    end
    
    # ========================================
    # 🔐 管理者専用のヘルパーメソッド
    # ========================================
    
    # 現在のユーザーが管理者かどうかを確認
    def admin_user?
      current_user&.admin?
    end
    
    # 管理者専用のフラッシュメッセージ
    def admin_flash_success(message)
      flash[:notice] = "✅ #{message}"
    end
    
    def admin_flash_error(message)
      flash[:alert] = "❌ #{message}"
    end
  end
end