require 'rails_helper'

RSpec.describe DailyMovieRanking, type: :model do
  describe 'validations' do
    it 'is invalid without aggregated_on' do
      ranking = build(:daily_movie_ranking, aggregated_on: nil)

      expect(ranking).not_to be_valid
      expect(ranking.errors.details[:aggregated_on]).to include(error: :blank)
    end

    it 'is invalid with negative reservation_count' do
      ranking = build(:daily_movie_ranking, reservation_count: -1)

      expect(ranking).not_to be_valid
      expect(ranking.errors.details[:reservation_count]).to include(hash_including(error: :greater_than_or_equal_to))
    end

    it 'is invalid with rank_position less than 1' do
      ranking = build(:daily_movie_ranking, rank_position: 0)

      expect(ranking).not_to be_valid
      expect(ranking.errors.details[:rank_position]).to include(hash_including(error: :greater_than))
    end
  end

  describe '.for_date' do
    it 'returns rankings for the specific date only' do
      target_date = Date.current
      ranking_today = create(:daily_movie_ranking, aggregated_on: target_date, rank_position: 1)
      create(:daily_movie_ranking, aggregated_on: target_date - 1.day, rank_position: 1)

      expect(described_class.for_date(target_date)).to contain_exactly(ranking_today)
    end
  end

  describe '.top' do
    it 'orders by rank_position and limits the result' do
      first = create(:daily_movie_ranking, rank_position: 1)
      second = create(:daily_movie_ranking, rank_position: 2)

      result = described_class.top(1)

      expect(result).to eq([first])
      expect(result).not_to include(second)
    end
  end
end
