class Wallet < ApplicationRecord
  belongs_to :user
  has_many :transactions, dependent: :destroy

  # 초기 생성 시 기본 잔액 설정
  before_create :set_default_values

  validates :balance, numericality: { greater_than_or_equal_to: 0 }
  validates :user_id, presence: true, uniqueness: true

  # 입금 처리
  def deposit(amount, description: nil, payment_method: nil, metadata: {})
    return false if amount <= 0

    transaction do
      self.balance += amount
      self.transaction_count += 1

      tx = transactions.create!(
        transaction_type: "deposit",
        amount: amount,
        description: description,
        payment_method: payment_method,
        metadata: metadata
      )

      save!
      tx
    end
  end

  # 출금 처리
  def withdraw(amount, description: nil, metadata: {})
    return false if amount <= 0 || amount > balance

    transaction do
      self.balance -= amount
      self.transaction_count += 1

      tx = transactions.create!(
        transaction_type: "withdrawal",
        amount: amount,
        description: description,
        metadata: metadata
      )

      save!
      tx
    end
  end

  private

  def set_default_values
    self.balance ||= 0 # 초기 잔액 0원 (seed에서 별도 충전)
    self.transaction_count ||= 0
  end
end
