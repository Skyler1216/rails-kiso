module Admin
  class TheatersController < BaseController
    # 管理画面: 劇場（Theater）の CRUD を扱うコントローラ
    # ポイント
    # - index: 劇場の一覧を表示。関連するスクリーンもあわせて取得（N+1回避のため includes(:screens)）
    # - show : 劇場の詳細と、同ページで更新フォーム（_form 部分）も表示
    # - new  : 新規作成フォームの表示
    # - create/update/destroy: 作成・更新・削除後は一覧へリダイレクトし、フラッシュで結果を表示
    # - set_theater: URLの :id から対象の劇場を取得する before_action
    # - theater_params: Strong Parameters（受け付ける入力項目を制限）
    before_action :set_theater, only: %i[show edit update destroy]

    def index
      # 一覧表示用に ID 昇順で並べ、スクリーン数の表示に備えてスクリーンを先読み
      @theaters = Theater.order(:id).includes(:screens)
    end

    def show; end

    def new
      # 新規作成フォームに渡す空のモデル
      @theater = Theater.new
    end

    def create
      # フォームの入力値（theater_params）で劇場を作成
      @theater = Theater.new(theater_params)
      if @theater.save
        admin_flash_success('劇場を登録しました。')
        redirect_to admin_theaters_path
      else
        admin_flash_error(@theater.errors.full_messages.join('、'))
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      # このアプリでは編集は詳細ページ（show）に統合しているため、詳細へ誘導
      redirect_to admin_theater_path(@theater)
    end

    def update
      # 詳細ページ内のフォームから送信された値で更新
      if @theater.update(theater_params)
        admin_flash_success('劇場を更新しました。')
        redirect_to admin_theaters_path
      else
        admin_flash_error(@theater.errors.full_messages.join('、'))
        render :show, status: :unprocessable_entity
      end
    end

    def destroy
      # 削除後は一覧へ戻り、結果をフラッシュで通知
      if @theater.destroy
        admin_flash_success('劇場を削除しました。')
      else
        admin_flash_error(@theater.errors.full_messages.join('、'))
      end
      redirect_to admin_theaters_path
    end

    private

    def set_theater
      # URL の :id から対象劇場を取得。見つからない場合は例外（404）
      @theater = Theater.find(params[:id])
    end

    def theater_params
      # フォームから受け取る許可パラメータを定義
      params.require(:theater).permit(:name, :address, :phone, :is_active)
    end
  end
end
