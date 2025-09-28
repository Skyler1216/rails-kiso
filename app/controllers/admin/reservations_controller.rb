module Admin
  class ReservationsController < BaseController
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

      # 関連オブジェクトを取得
      schedule = find_schedule(@reservation.schedule_id)
      sheet = find_sheet(@reservation.sheet_id)

      # 以下の検証を段階的に行い、失敗理由を個別にエラーメッセージ化
      validate_schedule_presence(schedule)
      validate_sheet_presence(sheet)

      if schedule && sheet
        # スクリーン整合性: 選んだ座席がそのスケジュールのスクリーンに属しているか
        validate_screen_match(schedule, sheet)
        
        # 予約日付: スケジュール開始日に合わせ、スクリーンを紐付け
        assign_reservation_screen_and_date(@reservation, schedule, compute_reservation_date(schedule))
        
        # 重複防止: 同じ座席・同じ日・同じスケジュールの重複を拒否
        validate_duplicate_seat(schedule, sheet, @reservation.date)
      end

      # エラーがある場合はフォームを再表示
      if @reservation.errors.any?
        return render_new_with_errors
      end

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

      # 関連オブジェクトを取得
      schedule = find_schedule(schedule_id)
      sheet = find_sheet(reservation_params[:sheet_id])

      # バリデーション実行
      validate_schedule_presence(schedule)
      validate_sheet_presence(sheet)

      if schedule && sheet
        # スクリーン整合性 → 予約日付の再計算 → 重複チェック（自分自身は除外）
        validate_screen_match(schedule, sheet)
        assign_reservation_screen_and_date(@reservation, schedule, compute_reservation_date(schedule, @reservation.date))
        validate_duplicate_seat(schedule, sheet, @reservation.date, exclude: @reservation.id)
      end

      # エラーがある場合はフォームを再表示
      if @reservation.errors.any?
        return render_edit_with_errors('❌ 入力内容に誤りがあります')
      end

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

    # 予約フォームの表示に必要なデータを用意する
    # 引数: schedule_id（選択中のスケジュールID/任意）
    # 用意するもの:
    #   @schedules         … 映画・劇場込みの候補（終了済み除外、開始時刻順）
    #   @sheets            … 全座席（screen, row, column順）
    #   @selected_schedule … 選択中のスケジュール
    #   @reserved_seat_map … { schedule_id => [予約済みsheet_id] }
    #   @available_sheets  … 表示する座席候補（選択中ならそのスクリーンのみ）
    def prepare_form_resources(schedule_id)
      now = Time.zone.now
      
      # 映画・劇場を事前読み込み（N+1回避）、終了済みを除外、開始時刻順で並べる
      @schedules = Schedule.includes(:movie, screen: :theater)
                           .where('schedules.end_time IS NULL OR schedules.end_time >= ?', now)
                           .order(:start_time)
      
      # 全座席を取得（スクリーン、行、列順）
      @sheets = Sheet.includes(screen: :theater).order(:screen_id, :row, :column)

      # 選択中スケジュールを特定
      selected_id = schedule_id.presence&.to_i
      @selected_schedule = selected_id && @schedules.find { |schedule| schedule.id == selected_id }

      # スケジュールごとの予約済み座席ID一覧を構築
      @reserved_seat_map = build_reserved_seat_map(selected_id)

      # 座席候補（選択中ならそのスクリーンのみ、未選択なら全座席）
      @available_sheets =
        if @selected_schedule
          Sheet.includes(screen: :theater).where(screen_id: @selected_schedule.screen_id).order(:row, :column)
        else
          @sheets
        end
    end

    # 指定されたスケジュール群に対して「予約済み座席IDの一覧」を構築する
    def build_reserved_seat_map(_selected_id)
      # スケジュール毎に予約済み座席IDの配列を持つハッシュを構築
      map = Hash.new { |h, k| h[k] = [] }

      # スケジュールの開始日を取得
      schedule_dates = {}
      @schedules.each do |schedule|
        date = schedule.start_time&.in_time_zone&.to_date
        schedule_dates[schedule.id] = date if date
      end

      # 該当スケジュールの予約を取得
      reservations = Reservation.where(schedule_id: schedule_dates.keys)

      # 各予約の座席IDをマップに追加
      reservations.find_each do |reservation|
        start_date = schedule_dates[reservation.schedule_id]
        next unless start_date && reservation.date == start_date

        map[reservation.schedule_id] << reservation.sheet_id
      end

      # 編集時は現在の予約の座席を除外（自分自身の重複チェック回避）
      if @reservation&.persisted? && @reservation.sheet_id.present?
        map[@reservation.schedule_id] = map[@reservation.schedule_id] - [@reservation.sheet_id]
      end

      map
    end

    # 未来（今日以降）に関係する予約を、関連（映画/スクリーン）ごと取得する基点スコープ
    def upcoming_reservation_scope(now)
      Reservation
        .joins(schedule: :screen)
        .includes(schedule: [:movie, { screen: :theater }], sheet: { screen: :theater })
        .where('reservations.date >= ?', now.to_date)
    end

    # 予約の開始/終了時刻から「今以降に有効な予約」のみを選別する
    def select_upcoming_reservations(scope, now)
      scope.select do |reservation|
        start_at = occurrence_datetime(reservation)
        end_at = occurrence_datetime(reservation, :end_time)

        if end_at.present?
          end_at >= now
        elsif start_at.present?
          start_at >= now
        else
          true
        end
      end
    end

    # 選択された劇場を特定する
    def locate_selected_theater(theaters, theater_id_param)
      theater_id = theater_id_param.to_s.strip
      return nil if theater_id.blank?

      theaters.find { |theater| theater.id.to_s == theater_id }
    end

    # 予約の表示順を決定する（予約日→開始時刻の順）
    def sort_reservations(reservations, now)
      reservations.sort_by do |reservation|
        sort_date = reservation.date || now.to_date
        start_at = occurrence_datetime(reservation)
        fallback_start = Time.zone.local(sort_date.year, sort_date.month, sort_date.day, 0, 0, 0)
        [sort_date, start_at || fallback_start]
      end
    end

    # IDからスケジュールを探す（空ならnilを返す）
    def find_schedule(id)
      return if id.blank?

      Schedule.find_by(id: id)
    end

    # IDから座席を探す（空ならnilを返す）
    def find_sheet(id)
      return if id.blank?

      Sheet.find_by(id: id)
    end

    # スケジュールが未選択/存在しない場合にエラーを追加する
    def validate_schedule_presence(schedule)
      return if schedule

      @reservation.errors.add(:schedule_id, '^上映スケジュールを選択してください')
    end

    # 座席が未選択/存在しない場合にエラーを追加する
    def validate_sheet_presence(sheet)
      return if sheet

      @reservation.errors.add(:sheet_id, '^座席を選択してください')
    end

    # 選択した座席のスクリーンが、選択したスケジュールのスクリーンと一致するか検証する
    def validate_screen_match(schedule, sheet)
      return if sheet.screen_id == schedule.screen_id

      @reservation.errors.add(:sheet_id, '^上映スケジュールのスクリーンから選択してください')
    end

    # 同一（スケジュール/座席/日付/スクリーン）の重複予約を検出しエラーにする
    def validate_duplicate_seat(schedule, sheet, date, exclude: nil)
      return unless duplicate_reservation?(schedule, sheet, date, exclude: exclude)

      @reservation.errors.add(:sheet_id, '^その座席はすでに予約されています')
    end

    # 予約日に使う日付を決定（スケジュールの開始日 or 既存日付 or 今日）
    def compute_reservation_date(schedule, fallback = nil)
      schedule.start_time&.in_time_zone&.to_date || fallback || Time.zone.today
    end

    # 予約にスクリーンと予約日を反映する（スケジュール由来）
    def assign_reservation_screen_and_date(reservation, schedule, date)
      reservation.date = date
      reservation.screen = schedule.screen
    end

    # 同一条件の予約が既に存在するかを問い合わせる（自レコード除外可）
    def duplicate_reservation?(schedule, sheet, date, exclude: nil)
      scope = Reservation.where(
        schedule_id: schedule.id,
        sheet_id: sheet.id,
        date: date,
        screen_id: schedule.screen_id
      )
      scope = scope.where.not(id: exclude) if exclude
      scope.exists?
    end

    # 予約の「日付 + スケジュール時刻」から、特定の日時（開始/終了）を組み立てる
    def occurrence_datetime(reservation, attribute = :start_time)
      schedule = reservation.schedule
      time_value = schedule&.public_send(attribute)
      return unless time_value.present? && reservation.date.present?

      time = time_value.in_time_zone
      Time.zone.local(
        reservation.date.year,
        reservation.date.month,
        reservation.date.day,
        time.hour,
        time.min,
        time.sec
      )
    end

    # 過去に終了した予約を編集しないようブロックする（before_action用）
    def ensure_reservation_upcoming
      now = Time.zone.now
      start_at = occurrence_datetime(@reservation)
      end_at = occurrence_datetime(@reservation, :end_time)

      finished = if end_at.present?
                   end_at < now
                 elsif start_at.present?
                   start_at < now
                 else
                   false
                 end

      return unless finished

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
