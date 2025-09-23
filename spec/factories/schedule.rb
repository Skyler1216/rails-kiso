FactoryBot.define do
  factory :schedule do
    association :movie
    association :screen
    start_time { Time.zone.parse('2025-09-22 10:00:00') }
    end_time { start_time + 2.hours }
  end
end
