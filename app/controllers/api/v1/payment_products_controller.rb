module Api
  module V1
    class PaymentProductsController < ApplicationController
      skip_before_action :authorize_request, only: [ :index ]

      # GET /api/v1/payment_products
      def index
        @products = PaymentProduct.active.ordered

        render json: {
          success: true,
          products: @products.map do |product|
            {
              id: product.id,
              product_id: product.product_id,
              store_product_id: product.store_product_id,
              name: product.name,
              amount: product.amount,
              bonus_amount: product.bonus_amount,
              total_amount: product.total_amount,
              bonus_percentage: product.bonus_percentage,
              price: product.price,
              display_price: product.display_price,
              display_amount: product.display_amount,
              metadata: product.metadata
            }
          end
        }
      end
    end
  end
end
