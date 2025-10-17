module Admin
  class TheatersController < BaseController
    # ============================================================================
    # 🎭 管理者用劇場管理コントローラー
    # ============================================================================
    # 劇場のCRUD操作を管理します。
    # 劇場の作成・編集・削除と、関連するスクリーンの管理を行います。
    # ============================================================================

    # 劇場設定の共通処理
    before_action :set_theater, only: %i[show edit update destroy]

    # ----------------------------------------------------------------------------
    # 劇場一覧表示
    # ----------------------------------------------------------------------------
    def index
      # 全劇場をID順で取得（スクリーン情報も含めて）
      @theaters = Theater.order(:id).includes(:screens)
    end

    # ----------------------------------------------------------------------------
    # 劇場詳細表示
    # ----------------------------------------------------------------------------
    def show
      # 表示用のスクリーンフィールドを確保
      ensure_screen_field_for_display
    end

    # ----------------------------------------------------------------------------
    # 新規劇場作成フォーム
    # ----------------------------------------------------------------------------
    def new
      # 新しい劇場オブジェクトを作成
      @theater = Theater.new

      # 最初からスクリーン入力欄を1つ追加しておく
      @theater.screens.build
    end

    # ----------------------------------------------------------------------------
    # 劇場作成処理
    # ----------------------------------------------------------------------------
    def create
      # パラメータから劇場オブジェクトを作成
      @theater = Theater.new(theater_params)

      if @theater.save
        # 成功時: 成功メッセージを表示して一覧画面へリダイレクト
        admin_flash_success('劇場を登録しました。')
        redirect_to admin_theaters_path
      else
        # 失敗時: スクリーン重複以外のエラーだけフラッシュに表示
        assign_filtered_flash(@theater)
        rebuild_blank_screen_field
        render :new, status: :unprocessable_entity
      end
    end

    # ----------------------------------------------------------------------------
    # 劇場編集フォーム（リダイレクト）
    # ----------------------------------------------------------------------------
    def edit
      # 編集フォームではなく詳細画面にリダイレクト
      redirect_to admin_theater_path(@theater)
      # @theater が ID=1 の劇場の場合
      # → "/admin/theaters/1"
      # つまり、以下のURLにリダイレクトされる
      # GET /admin/theaters/1
      # GET /admin/theaters/:id → showアクション
      # GET /admin/theaters/:id/edit → editアクション
    end

    # ----------------------------------------------------------------------------
    # 劇場更新処理
    # ----------------------------------------------------------------------------
    def update
      if @theater.update(theater_params)
        # 成功時: 成功メッセージを表示して一覧画面へリダイレクト
        admin_flash_success('劇場を更新しました。')
        redirect_to admin_theaters_path
      else
        # 失敗時: スクリーン重複以外のエラーだけフラッシュに表示
        assign_filtered_flash(@theater)
        ensure_screen_field_for_display
        render :show, status: :unprocessable_entity
      end
    end

    # ----------------------------------------------------------------------------
    # 劇場削除処理
    # ----------------------------------------------------------------------------
    def destroy
      if @theater.destroy
        # 成功時: 成功メッセージを表示
        admin_flash_success('劇場を削除しました。')
      else
        # 失敗時: エラーメッセージを表示
        admin_flash_error(@theater.errors.full_messages.join('、'))
      end

      # 一覧画面へリダイレクト
      redirect_to admin_theaters_path
    end

    # ----------------------------------------------------------------------------
    # プライベートメソッド
    # ----------------------------------------------------------------------------
    private

    # 劇場オブジェクトの設定
    def set_theater
      @theater = Theater.includes(:screens).find(params[:id])
    end

    # 劇場パラメータの許可設定
    def theater_params
      params.require(:theater).permit(:name, :address, :phone, :is_active,
                                      screens_attributes: %i[id name _destroy])
    end

    # 表示用のスクリーンフィールドを確保
    def ensure_screen_field_for_display
      # 削除予定でないスクリーンのみを取得
      visible_screens = @theater.screens.reject(&:marked_for_destruction?)

      # 表示可能なスクリーンがない場合は新しいフィールドを追加
      @theater.screens.build if visible_screens.empty?
    end

    # 空のスクリーンフィールドを再構築
    def rebuild_blank_screen_field
      # スクリーンが存在しない場合のみ実行
      return unless @theater.screens.empty?

      # 新しいスクリーンフィールドを追加
      @theater.screens.build
    end

    def assign_filtered_flash(record)
      messages = record.errors.full_messages.reject do |message|
        message.include?('同じ劇場内で一意になるよう設定してください') ||
          message.include?('スクリーン名が重複しています')
      end

      if messages.any?
        admin_flash_error(messages.join('、'))
      else
        flash.delete(:alert)
      end
    end
  end
end
