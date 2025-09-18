module Admin
  class SchedulesController < ApplicationController
    # 一覧表示
    def index
      # スケジュールを1件以上持つ映画だけを取得
      @movies = Movie.includes(:schedules).where.not(schedules: { id: nil })
    end

    # 編集フォーム表示
    def show
      @schedule = Schedule.find(params[:id])
    end

    # 編集フォームの送信（更新）
    def update
      @schedule = Schedule.find(params[:id])
      if @schedule.update(schedule_params)
        redirect_to admin_schedules_path, notice: 'スケジュールを更新しました'
      else
        render :show, status: :unprocessable_entity
      end
    end

    # スケジュール削除
    def destroy
      @schedule = Schedule.find(params[:id])
      @schedule.destroy
      redirect_to admin_schedules_path, notice: 'スケジュールを削除しました'
    end

    def new
      @movie = Movie.find(params[:movie_id])
      @schedule = @movie.schedules.build
    end

    def create
      @movie = Movie.find(params[:movie_id])
      @schedule = @movie.schedules.build(schedule_params)
      if @schedule.save
        redirect_to admin_schedules_path, notice: 'スケジュールを作成しました'
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @schedule = Schedule.find(params[:id])
    end

    private

    # 更新可能なパラメータを制限
    def schedule_params
      params.require(:schedule).permit(:start_time, :end_time)
    end
  end
end
