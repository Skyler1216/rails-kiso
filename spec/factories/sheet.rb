FactoryBot.define do
  factory :sheet do
    association :screen
    sequence(:row) { |n| ('A'..'Z').to_a[n % 26] }
    sequence(:column) { |n| (n % 10) + 1 }
  end
end
