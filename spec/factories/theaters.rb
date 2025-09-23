FactoryBot.define do
  factory :theater do
    sequence(:name) { |n| "劇場#{n}" }
    sequence(:address) { |n| "住所#{n}" }
    phone { '000-0000-0000' }
    is_active { true }
  end
end
