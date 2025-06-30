# frozen_string_literal: true

class WalletService
  def create_wallet_for_user(user)
    return if user.wallet.present?

    Wallet.create!(
      user: user,
      balance: 0
    )
  end

  def add_points(wallet, amount, reason:)
    return unless wallet && amount.positive?

    ActiveRecord::Base.transaction do
      wallet.increment!(:balance, amount)

      wallet.transactions.create!(
        amount: amount,
        transaction_type: "deposit",
        description: reason
      )
    end
  end

  def deduct_points(wallet, amount, reason:)
    return unless wallet && amount.positive?

    raise InsufficientBalanceError if wallet.balance < amount

    ActiveRecord::Base.transaction do
      wallet.decrement!(:balance, amount)

      wallet.transactions.create!(
        amount: amount,
        transaction_type: "withdrawal",
        description: reason
      )
    end
  end

  class InsufficientBalanceError < StandardError; end
end
