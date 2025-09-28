class ReservationsController < ApplicationController
  # ============================================================================
  # ReservationsController - 予約関連のコントローラー
  # ============================================================================
  # 映画の座席予約機能を管理します。
  # ログイン済みユーザーのみが利用可能です。
  # ============================================================================

  # ログイン必須のアクション
  before_action :authenticate_user!

  # ----------------------------------------------------------------------------
  # 予約フォーム表示
  # ----------------------------------------------------------------------------
  def new
    # 必須パラメータのチェック
    if params[:date].blank? || params[:sheet_id].blank?
      head :bad_request
      return
    end

    # 関連情報を取得
    @movie = Movie.find(params[:movie_id])
    @schedule = Schedule.includes(screen: :theater).find(params[:schedule_id])
    @screen = @schedule.screen
    @theater = @screen.theater
    @sheet = Sheet.find(params[:sheet_id])
    @date = params[:date]

    # 重複予約のチェック
    if Reservation.exists?(
      schedule_id: @schedule.id,
      date: @date,
      sheet_id: @sheet.id,
      screen_id: @screen.id
    )
      redirect_to reservation_movie_path(@movie,
                                         schedule_id: @schedule.id,
                                         date: @date,
                                         theater_id: @theater.id), 
                  alert: 'その座席はすでに予約済みです'
      return
    end

    # 新しい予約オブジェクトを作成
    @reservation = Reservation.new
  end

  # ----------------------------------------------------------------------------
  # 予約作成処理
  # ----------------------------------------------------------------------------
  def create
    # 予約オブジェクトを作成
    @reservation = Reservation.new(reservation_params)
    
    # 現在のユーザー情報を設定
    assign_user_info

    # 予約処理の分岐
    if duplicate_reservation_exists?
      # 重複予約の場合はエラー画面へリダイレクト
      redirect_to_duplicate_reservation_path
    elsif @reservation.save
      # 予約成功時は映画詳細画面へリダイレクト
      redirect_to movie_path(@reservation.schedule.movie_id), 
                  notice: '予約が完了しました'
    else
      # バリデーションエラーの場合はエラーハンドリング
      handle_reservation_error
    end
  end

  # ----------------------------------------------------------------------------
  # プライベートメソッド
  # ----------------------------------------------------------------------------
  private

  # 予約パラメータの許可設定
  def reservation_params
    params.require(:reservation).permit(:name, :email, :schedule_id, :sheet_id, :date, :screen_id)
  end

  # 現在のユーザー情報を予約に設定
  def assign_user_info
    @reservation.name = current_user.name
    @reservation.email = current_user.email
    @reservation.user = current_user
  end

  # 重複予約の存在チェック
  def duplicate_reservation_exists?
    Reservation.exists?(
      date: @reservation.date,
      schedule_id: @reservation.schedule_id,
      sheet_id: @reservation.sheet_id,
      screen_id: @reservation.screen_id
    )
  end

  # 重複予約エラー時のリダイレクト処理
  def redirect_to_duplicate_reservation_path
    redirect_to reservation_movie_path(
      @reservation.schedule.movie_id,
      schedule_id: @reservation.schedule_id,
      date: @reservation.date,
      theater_id: @reservation.schedule.screen.theater_id
    ), alert: 'その座席はすでに予約済みです'
  end

  # 予約エラー時の処理
  def handle_reservation_error
    # エラーメッセージをコンソールに出力（デバッグ用）
    puts @reservation.errors.full_messages

    # エラー表示に必要な情報を再取得
    @schedule = Schedule.includes(screen: :theater).find(@reservation.schedule_id)
    @movie = @schedule.movie
    @screen = @schedule.screen
    @theater = @screen.theater
    @sheet = Sheet.find(@reservation.sheet_id)
    @date = @reservation.date

    # エラーメッセージを設定してフォームを再表示
    flash.now[:alert] = '入力内容に誤りがあります'
    render :new, status: :unprocessable_entity
  end
end
