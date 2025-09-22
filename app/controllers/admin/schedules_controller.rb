module Admin
  class SchedulesController < BaseController
    # 一覧表示
    def index
      now = Time.zone.now
      @now = now

      @all_schedules = Schedule.includes(:movie, :screen)
                               .order(:start_time)
                               .to_a
      @all_schedules = reorder_schedules(@all_schedules, now)

      @movies = Movie.includes(schedules: :screen)
                     .where(id: @all_schedules.map(&:movie_id).uniq)
                     .order(:id)
      @movie_schedules = @movies.index_with do |movie|
        reorder_schedules(movie.schedules, now)
      end

      today = Time.zone.today
      @schedule_stats = {
        total_schedules: @all_schedules.size,
        total_movies: @movies.size,
        playing_now: @all_schedules.count do |s|
          s.start_time.present? && s.end_time.present? && s.start_time <= now && s.end_time >= now
        end,
        today: @all_schedules.count { |s| s.start_time.present? && s.start_time.to_date == today },
        this_week: @all_schedules.count do |s|
          next false unless s.start_time.present?

          (today..today + 6.days).cover?(s.start_time.to_date)
        end
      }
    end

    # 編集フォーム表示
    def show
      @schedule = Schedule.find(params[:id])
      @movie = @schedule.movie
      @screens = Screen.order(:id)
    end

    def new
      defaults = params.permit(:movie_id, :screen_id)
      @schedule = Schedule.new(defaults)
      @movies = Movie.order(:id)
      @screens = Screen.order(:id)
    end

    def create
      @schedule = Schedule.new(schedule_create_params)
      if @schedule.save
        redirect_to admin_schedules_path, notice: 'スケジュールを作成しました'
      else
        @movies = Movie.order(:id)
        @screens = Screen.order(:id)
        render :new, status: :unprocessable_entity
      end
    end

    # 編集フォームの送信（更新）
    def update
      @schedule = Schedule.find(params[:id])
      if @schedule.update(schedule_update_params)
        redirect_to admin_schedules_path, notice: 'スケジュールを更新しました'
      else
        @movie = @schedule.movie
        @screens = Screen.order(:id)
        render :show, status: :unprocessable_entity
      end
    end

    # スケジュール削除
    def destroy
      @schedule = Schedule.find(params[:id])
      @schedule.destroy
      redirect_to admin_schedules_path, notice: 'スケジュールを削除しました'
    end

    private

    def reorder_schedules(schedules, now)
      schedules.sort_by do |schedule|
        [schedule_finished?(schedule, now) ? 1 : 0, schedule.start_time || Time.zone.at(0)]
      end
    end

    def schedule_finished?(schedule, now)
      schedule.end_time.present? && schedule.end_time < now
    end

    def schedule_update_params
      params.require(:schedule).permit(:start_time, :end_time, :screen_id)
    end

    def schedule_create_params
      params.require(:schedule).permit(:movie_id, :screen_id, :start_time, :end_time)
    end
  end
end
