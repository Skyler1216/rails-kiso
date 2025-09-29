FactoryBot.define do
  factory :schedule do
    association :movie
    association :screen
    start_time { 5.days.from_now.change(hour: 10, min: 0) }
    end_time { start_time + 2.hours }
  end
end
