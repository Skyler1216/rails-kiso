require 'rails_helper'

RSpec.describe Movie, type: :model do
  describe 'バリデーション' do
    let(:movie) { build(:movie) }

    it '有効な属性で作成できること' do
      expect(movie).to be_valid
    end

    describe 'name' do
      it '必須であること' do
        movie.name = nil
        expect(movie).not_to be_valid
        expect(movie.errors[:name]).to include("can't be blank")
      end

      it '一意であること' do
        create(:movie, name: 'テスト映画')
        movie.name = 'テスト映画'
        expect(movie).not_to be_valid
        expect(movie.errors[:name]).to include('has already been taken')
      end
    end

    describe 'year' do
      it '必須であること' do
        movie.year = nil
        expect(movie).not_to be_valid
        expect(movie.errors[:year]).to include("can't be blank")
      end
    end

    describe 'image_url' do
      it '必須であること' do
        movie.image_url = nil
        expect(movie).not_to be_valid
        expect(movie.errors[:image_url]).to include("can't be blank")
      end
    end

    describe 'running_minutes' do
      it '1以上の数値であること' do
        movie.running_minutes = 0
        expect(movie).not_to be_valid
        expect(movie.errors[:running_minutes]).to include('は1以上の数値で入力してください')
      end

      it '負の数値は無効であること' do
        movie.running_minutes = -1
        expect(movie).not_to be_valid
        expect(movie.errors[:running_minutes]).to include('は1以上の数値で入力してください')
      end

      it 'nilは有効であること' do
        movie.running_minutes = nil
        expect(movie).to be_valid
      end

      it '正の数値は有効であること' do
        movie.running_minutes = 120
        expect(movie).to be_valid
      end
    end
  end

  describe '関連' do
    it 'schedulesとの関連が正しく設定されていること' do
      expect(Movie.reflect_on_association(:schedules).macro).to eq :has_many
    end

    it 'dependent: :destroyが設定されていること' do
      movie = create(:movie)
      schedule = create(:schedule, movie: movie)
      
      expect { movie.destroy }.to change { Schedule.count }.by(-1)
    end
  end
end
