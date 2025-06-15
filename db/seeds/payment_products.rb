# 결제 상품 시드 데이터
puts "Creating payment products..."

payment_products = [
  {
    product_id: 'cash_100',
    name: '100 캐시',
    amount: 100,
    bonus_amount: 0,
    price: 1100,
    sort_order: 1
  },
  {
    product_id: 'cash_500',
    name: '500 캐시',
    amount: 500,
    bonus_amount: 0,
    price: 5500,
    sort_order: 2
  },
  {
    product_id: 'cash_1000',
    name: '1,000 캐시',
    amount: 1000,
    bonus_amount: 50,  # 5% 보너스
    price: 11000,
    sort_order: 3
  },
  {
    product_id: 'cash_3000',
    name: '3,000 캐시',
    amount: 3000,
    bonus_amount: 300,  # 10% 보너스
    price: 33000,
    sort_order: 4
  },
  {
    product_id: 'cash_5000',
    name: '5,000 캐시',
    amount: 5000,
    bonus_amount: 750,  # 15% 보너스
    price: 55000,
    sort_order: 5
  },
  {
    product_id: 'cash_10000',
    name: '10,000 캐시',
    amount: 10000,
    bonus_amount: 2000,  # 20% 보너스
    price: 110000,
    sort_order: 6
  }
]

payment_products.each do |product_data|
  PaymentProduct.find_or_create_by(product_id: product_data[:product_id]) do |product|
    product.name = product_data[:name]
    product.amount = product_data[:amount]
    product.bonus_amount = product_data[:bonus_amount]
    product.price = product_data[:price]
    product.sort_order = product_data[:sort_order]
    product.active = true
    product.metadata = {
      description: "#{product_data[:amount]} 캐시 구매",
      currency: "KRW"
    }
  end
end

puts "Created #{PaymentProduct.count} payment products" 