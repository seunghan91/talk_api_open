FactoryBot.define do
  factory :wallet do
    balance { 0 }
    association :user
    
    trait :with_balance do
      balance { 10000 }
    end
    
    trait :with_transactions do
      after(:create) do |wallet|
        create(:transaction, wallet: wallet, amount: 5000, transaction_type: 'deposit', description: '충전')
        create(:transaction, wallet: wallet, amount: -1000, transaction_type: 'withdraw', description: '출금')
      end
    end
  end
  
  factory :transaction do
    amount { 1000 }
    transaction_type { 'deposit' }
    description { '충전' }
    
    association :wallet
    
    trait :deposit do
      transaction_type { 'deposit' }
      amount { 5000 }
    end
    
    trait :withdraw do
      transaction_type { 'withdraw' }
      amount { -1000 }
    end
  end
end 