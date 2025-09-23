FactoryBot.define do
  factory :screen do
    association :theater
    sequence(:name) { |n| "スクリーン#{n}" }
  end
end
