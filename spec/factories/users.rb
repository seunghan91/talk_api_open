FactoryBot.define do
  factory :user do
    phone_number { "010#{rand(1000..9999)}#{rand(1000..9999)}" }
    password { 'test1234' }
    nickname { '테스트유저' }
    gender { 'male' }
    verified { true }
    blocked { false }
  end
end
