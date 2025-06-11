require 'swagger_helper'

RSpec.describe 'Wallets API', type: :request do
  path '/api/wallets' do
    get 'Get wallet information' do
      tags 'Wallets'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Wallet information fetched successfully' do
        schema type: :object,
          properties: {
            wallet: {
              type: :object,
              properties: {
                id: { type: :integer },
                user_id: { type: :integer },
                balance: { type: :integer },
                created_at: { type: :string, format: 'date-time' },
                updated_at: { type: :string, format: 'date-time' }
              }
            },
            user: { '$ref' => '#/components/schemas/user' }
          }

        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end
  end

  path '/api/wallets/transactions' do
    get 'Get wallet transactions' do
      tags 'Wallets'
      security [ bearer_auth: [] ]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'

      response '200', 'Wallet transactions fetched successfully' do
        schema type: :object,
          properties: {
            transactions: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  wallet_id: { type: :integer },
                  amount: { type: :integer },
                  transaction_type: { type: :string },
                  description: { type: :string },
                  created_at: { type: :string, format: 'date-time' }
                }
              }
            },
            pagination: {
              type: :object,
              properties: {
                current_page: { type: :integer },
                total_pages: { type: :integer },
                total_count: { type: :integer }
              }
            }
          }

        let(:Authorization) { "Bearer token" }
        let(:page) { 1 }
        let(:per_page) { 10 }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end
  end

  path '/api/wallets/deposit' do
    post 'Deposit to wallet' do
      tags 'Wallets'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :integer, example: 10000 },
          payment_method: { type: :string, example: 'card' }
        },
        required: [ 'amount', 'payment_method' ]
      }

      response '200', 'Deposit successful' do
        schema type: :object,
          properties: {
            message: { type: :string },
            transaction: {
              type: :object,
              properties: {
                id: { type: :integer },
                amount: { type: :integer },
                transaction_type: { type: :string },
                description: { type: :string },
                created_at: { type: :string, format: 'date-time' }
              }
            },
            wallet: {
              type: :object,
              properties: {
                id: { type: :integer },
                balance: { type: :integer }
              }
            }
          }

        let(:Authorization) { "Bearer token" }
        let(:params) { { amount: 10000, payment_method: 'card' } }
        run_test!
      end

      response '422', 'Invalid parameters' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer token" }
        let(:params) { { amount: -1000, payment_method: 'card' } }
        run_test!
      end
    end
  end
end
