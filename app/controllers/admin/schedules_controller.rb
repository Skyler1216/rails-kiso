module Admin
  class SchedulesController < BaseController
    # 一覧表示
    def index
      now = Time.zone.now
      @now = now

      @all_schedules = sorted_schedules(now)
      @movies, @movie_schedules = build_movie_index(@all_schedules, now)
      @schedule_stats = build_schedule_stats(@all_schedules, @movies, now)
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

    def sorted_schedules(now)
      Schedule.includes(:movie, :screen)
              .order(:start_time)
              .to_a
              .then { |list| reorder_schedules(list, now) }
    end

    def build_movie_index(all_schedules, now)
      movies = Movie.includes(schedules: :screen)
                    .where(id: all_schedules.map(&:movie_id).uniq)
                    .order(:id)
      movie_schedules = movies.index_with { |movie| reorder_schedules(movie.schedules, now) }
      [movies, movie_schedules]
    end

    def build_schedule_stats(all_schedules, movies, now)
      today = Time.zone.today
      {
        total_schedules: all_schedules.size,
        total_movies: movies.size,
        playing_now: count_playing_now(all_schedules, now),
        today: count_today(all_schedules, today),
        this_week: count_this_week(all_schedules, today)
      }
    end

    def count_playing_now(schedules, now)
      schedules.count { |s| playing_now?(s, now) }
    end

    def count_today(schedules, today)
      schedules.count { |s| starts_on?(s, today) }
    end

    def count_this_week(schedules, today)
      schedules.count { |s| starts_in_week?(s, today) }
    end

    def playing_now?(schedule, now)
      schedule.start_time && schedule.end_time && schedule.start_time <= now && schedule.end_time >= now
    end

    def starts_on?(schedule, day)
      schedule.start_time && schedule.start_time.to_date == day
    end

    def starts_in_week?(schedule, day)
      schedule.start_time && (day..day + 6.days).cover?(schedule.start_time.to_date)
    end

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
