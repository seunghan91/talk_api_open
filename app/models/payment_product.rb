class PaymentProduct < ApplicationRecord
  validates :name, :amount, :price, :product_id, presence: true
  validates :product_id, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(sort_order: :asc) }

  # 보너스 캐시 포함 총 금액
  def total_amount
    amount + (bonus_amount || 0)
  end

  # 보너스 퍼센트 계산
  def bonus_percentage
    return 0 if bonus_amount.nil? || bonus_amount.zero?
    ((bonus_amount.to_f / amount) * 100).round
  end

  # 인앱 결제 상품 ID (iOS/Android 공통)
  def store_product_id
    "#{Rails.application.config.iap_prefix}.#{product_id}"
  end

  # 표시용 가격 포맷
  def display_price
    "₩#{price.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')}"
  end

  # 표시용 캐시 포맷
  def display_amount
    if bonus_amount && bonus_amount > 0
      "#{amount.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')} + #{bonus_amount.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')} 캐시"
    else
      "#{amount.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')} 캐시"
    end
  end
end
