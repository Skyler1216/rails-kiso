FactoryBot.define do
  factory :reservation do
    date { Date.current }
    association :schedule
    name { 'Test User' }
    email { 'test@example.com' }

    screen { schedule.screen }
    sheet { association :sheet, screen: screen }
  end
end
