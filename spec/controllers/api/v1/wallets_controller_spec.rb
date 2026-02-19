require 'rails_helper'

RSpec.describe 'Api::V1::Wallets', type: :request do
  let(:user) { create(:user) }

  before do
    # Clear Rails cache to avoid stale data between tests
    Rails.cache.clear
  end

  describe 'GET /api/v1/wallets/my_wallet' do
    context 'when user has a wallet (auto-created)' do
      before do
        # User model auto-creates wallet with balance 0
        # Update balance to test specific value
        user.wallet.update!(balance: 15000)
      end

      it 'returns wallet information with formatted currency' do
        get '/api/v1/wallets/my_wallet', headers: auth_headers_for(user)

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)

        # Balance is decimal type, may be returned as string or number depending on caching
        expect(json_response['balance'].to_i).to eq(15000)
        expect(json_response['formatted_balance']).to eq('₩15,000')
        expect(json_response['transaction_count']).to be_present
      end
    end

    context 'when user wallet has default balance' do
      it 'returns wallet with default balance (0)' do
        get '/api/v1/wallets/my_wallet', headers: auth_headers_for(user)

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)

        # Default balance is 0 (set in Wallet model)
        # Balance is decimal type, may be returned as string or number depending on caching
        expect(json_response['balance'].to_i).to eq(0)
        expect(json_response['formatted_balance']).to eq('₩0')
        expect(json_response['transaction_count'].to_i).to eq(0)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/wallets/my_wallet'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/wallets/:id' do
    it 'returns wallet information when accessed with wallet ID' do
      user.wallet.update!(balance: 5000)

      get "/api/v1/wallets/#{user.wallet.id}", headers: auth_headers_for(user)

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)

      # Balance is decimal type, may be returned as string or number depending on caching
      expect(json_response['balance'].to_i).to eq(5000)
      expect(json_response['formatted_balance']).to eq('₩5,000')
    end
  end
end
