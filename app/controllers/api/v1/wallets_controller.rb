module Api
  module V1
    class WalletsController < ApplicationController
      before_action :authorize_request
      
      # 지갑 정보 조회
      def show
        wallet = current_user.wallet || current_user.create_wallet
        
        render json: {
          balance: wallet.balance,
          transaction_count: wallet.transaction_count,
          formatted_balance: number_to_currency(wallet.balance, unit: '₩', precision: 0)
        }
      end
      
      # 최근 거래 내역 조회
      def transactions
        wallet = current_user.wallet || current_user.create_wallet
        transactions = wallet.transactions.recent.limit(20)
        
        render json: transactions.map { |tx| format_transaction(tx) }
      end
      
      # 충전 요청 처리
      def deposit
        wallet = current_user.wallet || current_user.create_wallet
        amount = params[:amount].to_f
        
        if amount <= 0
          return render json: { error: '유효하지 않은 금액입니다.' }, status: :unprocessable_entity
        end
        
        # 테스트/개발 환경에서는 결제 과정 없이 바로 충전
        # 실제 서비스에서는 결제 시스템 연동 필요
        tx = wallet.deposit(
          amount,
          description: '충전',
          payment_method: params[:payment_method] || '신용카드',
          metadata: { source: 'app' }
        )
        
        if tx
          render json: { 
            success: true, 
            message: "#{number_to_currency(amount, unit: '₩', precision: 0)}이 충전되었습니다.",
            balance: wallet.balance,
            transaction: format_transaction(tx)
          }
        else
          render json: { error: '충전에 실패했습니다.' }, status: :unprocessable_entity
        end
      end
      
      private
      
      def format_transaction(transaction)
        {
          id: transaction.id,
          type: transaction.transaction_type,
          type_korean: transaction_type_to_korean(transaction.transaction_type),
          amount: transaction.amount,
          formatted_amount: number_to_currency(transaction.amount, unit: '₩', precision: 0),
          description: transaction.description,
          payment_method: transaction.payment_method,
          status: transaction.status,
          created_at: transaction.created_at,
          formatted_date: transaction.created_at.strftime('%Y년 %m월 %d일 %H:%M')
        }
      end
      
      def transaction_type_to_korean(type)
        case type
        when 'deposit' then '충전'
        when 'withdrawal' then '출금'
        when 'purchase' then '사용'
        else type
        end
      end
    end
  end
end 