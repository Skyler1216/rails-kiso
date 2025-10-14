FactoryBot.define do
  factory :daily_movie_ranking do
    aggregated_on { Date.current }
    reservation_count { 1 }
    rank_position { 1 }
    association :movie
  end
end
