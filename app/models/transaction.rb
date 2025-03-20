class Transaction < ApplicationRecord
  belongs_to :wallet

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :transaction_type, presence: true, 
            inclusion: { in: %w[deposit withdrawal purchase] }
  validates :status, presence: true, 
            inclusion: { in: %w[pending completed failed] }
  
  scope :deposits, -> { where(transaction_type: 'deposit') }
  scope :withdrawals, -> { where(transaction_type: 'withdrawal') }
  scope :purchases, -> { where(transaction_type: 'purchase') }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }
  
  def user
    wallet.user
  end
end 