FactoryBot.define do
  factory :reservation do
    date { "2025-05-22" }
    association :schedule
    association :sheet
    name { "Test User" }
    email { "test@example.com" }
  end
end
