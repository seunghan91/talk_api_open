require 'swagger_helper'

RSpec.describe 'Wallets API', type: :request do
  let(:user) { create(:user) }
  let(:valid_token) { generate_token_for(user) }

  before do
    # User's wallet is auto-created by after_create callback
    # Update balance if needed for tests
    user.wallet.update!(balance: 10000)
  end

  path '/api/v1/wallet' do
    get 'Get my wallet information' do
      tags 'Wallets'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Wallet information fetched successfully' do
        schema type: :object,
          properties: {
            balance: { type: :string, description: 'Wallet balance as decimal string' },
            transaction_count: { type: :integer },
            formatted_balance: { type: :string }
          }

        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end
  end

  path '/api/v1/wallets/my_wallet' do
    get 'Get my wallet information (alternate route)' do
      tags 'Wallets'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Wallet information fetched successfully' do
        schema type: :object,
          properties: {
            balance: { type: :string, description: 'Wallet balance as decimal string' },
            transaction_count: { type: :integer },
            formatted_balance: { type: :string }
          }

        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end
  end
end
