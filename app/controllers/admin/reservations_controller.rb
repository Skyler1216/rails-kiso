module Admin
  class ReservationsController < BaseController
    include Admin::ReservationFormSupport
    include Admin::ReservationValidation
    # ============================================================================
    # 🎫 管理者用予約管理コントローラー
    # ============================================================================
    # 管理画面での予約のCRUD操作を管理します。
    #
    # 設計方針:
    # - 入力チェックと関連整合性チェック（schedule/screen/sheet）の責務を
    #   小さなメソッドに分割し、エラーメッセージを明確化
    # - データ構造: Reservation は Schedule/Screen/Sheet に紐づく
    # - Schedule は Screen（=どの劇場のスクリーンか）に紐づくため、
    #   座席の選択とスケジュールのスクリーンが一致するかを検証
    # ============================================================================

    # 予約設定の共通処理
    before_action :set_reservation, only: %i[show update destroy]

    # 過去の予約編集を防止
    before_action :ensure_reservation_upcoming, only: %i[show update]

    # ----------------------------------------------------------------------------
    # 予約一覧表示
    # ----------------------------------------------------------------------------
    def index
      # 現在時刻を取得
      now = Time.zone.now

      # 劇場一覧を取得（フィルタ用）
      @theaters = Theater.order(:name)

      # 選択された劇場を特定
      @selected_theater = locate_selected_theater(@theaters, params[:theater_id])

      # 未来の予約の基本スコープを取得
      scope = upcoming_reservation_scope(now)

      # 劇場が選択されている場合は該当劇場のみに絞り込み
      scope = scope.where(screens: { theater_id: @selected_theater.id }) if @selected_theater

      # 未来の予約のみを選別 → 表示用に並び替え
      filtered = select_upcoming_reservations(scope, now)
      @reservations = sort_reservations(filtered, now)
    end

    # ----------------------------------------------------------------------------
    # 新規予約フォーム表示
    # ----------------------------------------------------------------------------
    def new
      # 新しい予約オブジェクトを作成
      @reservation = Reservation.new

      # フォーム選択肢（スケジュール/座席/予約済み座席マップ）を事前にロード
      prepare_form_resources(@reservation.schedule_id)
    end

    # ----------------------------------------------------------------------------
    # 新規予約作成処理
    # ----------------------------------------------------------------------------
    def create
      # パラメータから予約オブジェクトを作成
      @reservation = Reservation.new(reservation_params)

      # バリデーション前に、フォーム選択肢や予約済み座席マップを用意
      prepare_form_resources(@reservation.schedule_id)

      ensure_schedule_and_sheet(@reservation.schedule_id, @reservation.sheet_id)

      # エラーがある場合はフォームを再表示
      return render_new_with_errors if @reservation.errors.any?

      # 予約を保存
      if @reservation.save
        admin_flash_success('予約を作成しました')
        redirect_to admin_reservations_path
      else
        render_new_with_errors
      end
    end

    # ----------------------------------------------------------------------------
    # 予約詳細/編集フォーム表示
    # ----------------------------------------------------------------------------
    def show
      # 編集フォーム表示時も、選択肢と予約済み座席マップを事前に用意
      prepare_form_resources(@reservation.schedule_id)
    end

    # ----------------------------------------------------------------------------
    # 予約更新処理
    # ----------------------------------------------------------------------------
    def update
      # 更新対象のスケジュールIDを取得
      schedule_id = reservation_params[:schedule_id]

      # 更新時にも同様にフォーム資材をロード
      prepare_form_resources(schedule_id)

      ensure_schedule_and_sheet(
        schedule_id,
        reservation_params[:sheet_id],
        date_fallback: @reservation.date,
        duplicate_exclude: @reservation.id
      )

      # エラーがある場合はフォームを再表示
      return render_edit_with_errors('❌ 入力内容に誤りがあります') if @reservation.errors.any?

      # 予約属性を更新（日付は再計算されたものを使用）
      @reservation.assign_attributes(reservation_params.merge(date: @reservation.date))

      # 予約を保存
      if @reservation.save
        admin_flash_success('予約を更新しました')
        redirect_to admin_reservations_path
      else
        render_edit_with_errors('❌ 入力内容に誤りがあります')
      end
    end

    # ----------------------------------------------------------------------------
    # 予約削除処理
    # ----------------------------------------------------------------------------
    def destroy
      # 予約を削除
      @reservation.destroy

      # 成功メッセージを表示して一覧に戻る
      admin_flash_success('予約を削除しました')
      redirect_to admin_reservations_path
    end

    # ----------------------------------------------------------------------------
    # プライベートメソッド
    # ----------------------------------------------------------------------------
    private

    # Strong Parameters：許可する予約パラメータの定義
    def reservation_params
      params.require(:reservation).permit(:name, :email, :schedule_id, :sheet_id)
    end

    # URLのIDから対象予約を取得（before_action用）
    def set_reservation
      @reservation = Reservation.find(params[:id])
    end

    # 過去に終了した予約を編集しないようブロックする（before_action用）
    def ensure_reservation_upcoming
      return if upcoming_reservation?(@reservation, Time.zone.now)

      admin_flash_error('終了した予約は編集できません')
      redirect_to admin_reservations_path
    end

    # 新規作成フォームの再表示（エラーメッセージ付き）
    def render_new_with_errors
      prepare_form_resources(@reservation.schedule_id)
      flash.now[:alert] = '❌ 入力内容に誤りがあります'
      render :new, status: :unprocessable_entity
    end

    # 編集フォームの再表示（指定メッセージ付き）
    def render_edit_with_errors(message)
      prepare_form_resources(@reservation.schedule_id)
      flash.now[:alert] = message
      render :show, status: :unprocessable_entity
    end
  end
end
