require 'rails_helper'

RSpec.describe DailyMovieRankings::Refresher do
  include ActiveSupport::Testing::TimeHelpers

  describe '#call' do
    subject(:refresh) do
      described_class.call(target_date: target_date, lookback_days: lookback_days)
    end

    let(:target_date) { Date.new(2024, 5, 1) }
    let(:lookback_days) { described_class::LOOKBACK_DAYS }

    around do |example|
      travel_to(Time.zone.local(2024, 5, 1, 0, 0)) { example.run }
    end

    let(:screen) { create(:screen) }
    let(:movie_a) { create(:movie, name: 'Movie A') }
    let(:movie_b) { create(:movie, name: 'Movie B') }
    let(:movie_c) { create(:movie, name: 'Movie C') }

    let(:schedule_a) do
      create(:schedule,
             movie: movie_a,
             screen: screen,
             start_time: Time.zone.local(2024, 4, 20, 10, 0),
             end_time: Time.zone.local(2024, 4, 20, 12, 0))
    end

    let(:schedule_b) do
      create(:schedule,
             movie: movie_b,
             screen: screen,
             start_time: Time.zone.local(2024, 4, 22, 12, 0),
             end_time: Time.zone.local(2024, 4, 22, 14, 0))
    end

    before do
      within_window_time_a = Time.zone.local(2024, 4, 26, 12, 0, 0)
      within_window_time_b = Time.zone.local(2024, 4, 29, 9, 30, 0)
      outside_window_time = Time.zone.local(2024, 3, 1, 10, 0, 0)

      create_list(
        :reservation,
        3,
        schedule: schedule_a,
        date: target_date - 5.days,
        created_at: within_window_time_a,
        updated_at: within_window_time_a
      )

      create(
        :reservation,
        schedule: schedule_b,
        date: target_date - 2.days,
        created_at: within_window_time_b,
        updated_at: within_window_time_b
      )

      # Outside lookback window (should be ignored)
      create(
        :reservation,
        schedule: schedule_a,
        date: target_date - (lookback_days + 5).days,
        created_at: outside_window_time,
        updated_at: outside_window_time
      )

      # Pre-existing record should be replaced
      create(:daily_movie_ranking, aggregated_on: target_date, movie: movie_c, reservation_count: 99, rank_position: 1)
    end

    it 'stores rankings ordered by reservation_count and resets previous records' do
      expect { refresh }.to change(DailyMovieRanking, :count).from(1).to(2)

      rankings = DailyMovieRanking.where(aggregated_on: target_date).order(:rank_position)

      expect(rankings.map(&:movie)).to eq([movie_a, movie_b])
      expect(rankings.map(&:reservation_count)).to eq([3, 1])
      expect(rankings.map(&:rank_position)).to eq([1, 2])
    end
  end
end
