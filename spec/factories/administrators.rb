FactoryBot.define do
  factory :administrator do
    sequence(:email) { |n| "operateur#{n}@example.com" }
    password { 'Administration-2026' }
  end
end
