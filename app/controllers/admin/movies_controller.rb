module Admin
  class MoviesController < ApplicationController
    def index
      @movies = Movie.all
    end

    def new
      @movie = Movie.new
    end

    def create
      @movie = Movie.new(movie_params)
      if @movie.save
        flash[:notice] = '映画を登録しました。'
        redirect_to admin_movies_path
      else
        flash.now[:alert] = "登録に失敗しました（#{@movie.errors.full_messages.join('、')}）"
        render :new, status: :unprocessable_entity
      end
    rescue StandardError => e
      flash.now[:alert] = "エラーが発生しました: #{e.message}"
      render :new, status: :internal_server_error
    end

    def edit
      @movie = Movie.find(params[:id])
    end

    def update
      @movie = Movie.find(params[:id])
      if @movie.update(movie_params)
        flash[:notice] = '映画を更新しました。'
        redirect_to admin_movies_path
      else
        flash.now[:alert] = "更新に失敗しました（#{@movie.errors.full_messages.join('、')}）"
        render :edit, status: :unprocessable_entity
      end
    rescue StandardError => e
      flash.now[:alert] = "エラーが発生しました: #{e.message}"
      render :edit, status: :internal_server_error
    end

    def destroy
      @movie = Movie.find(params[:id])
      @movie.destroy
      flash[:notice] = '映画を削除しました。'
      redirect_to admin_movies_path
    end

    def show
      @movie = Movie.find(params[:id])
    end

    private

    def movie_params
      params.require(:movie).permit(:name, :year, :description, :image_url, :is_showing)
    end
  end
end
