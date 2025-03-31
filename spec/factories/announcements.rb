FactoryBot.define do
  factory :announcement do
    title { "MyString" }
    content { "MyText" }
    category { nil }
    is_important { false }
    is_published { false }
    is_hidden { false }
    published_at { "2025-03-31 20:58:55" }
  end
end
