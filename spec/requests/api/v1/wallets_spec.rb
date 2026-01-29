require 'rails_helper'

RSpec.describe 'Api::V1::Wallets', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers_for(user) }

  # User model automatically creates a wallet with after_create callback
  # So we access the user's wallet directly instead of creating a new one

  describe 'GET /api/v1/wallet' do
    context 'when user has a wallet' do
      before do
        # Update the auto-created wallet balance
        user.wallet.update!(balance: 15000)
      end

      it 'returns wallet information with formatted currency' do
        get '/api/v1/wallet', headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)

        # Balance is returned as decimal string from DB
        expect(json_response['balance'].to_f).to eq(15000.0)
        expect(json_response['formatted_balance']).to eq('₩15,000')
        expect(json_response).to have_key('transaction_count')
      end
    end

    context 'when user wallet has default balance' do
      it 'returns wallet information with default balance' do
        get '/api/v1/wallet', headers: headers

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)

        # Default wallet balance is set by create_wallet_for_user callback (0 by default)
        expect(json_response).to have_key('balance')
        expect(json_response).to have_key('formatted_balance')
      end
    end
  end

  describe 'GET /api/v1/wallets/my_wallet' do
    before do
      user.wallet.update!(balance: 15000)
    end

    it 'returns wallet information' do
      get '/api/v1/wallets/my_wallet', headers: headers

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['balance'].to_f).to eq(15000.0)
    end
  end

  describe 'GET /api/v1/wallets/:id' do
    before do
      user.wallet.update!(balance: 15000)
    end

    it 'returns wallet information' do
      get "/api/v1/wallets/#{user.wallet.id}", headers: headers

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response['balance'].to_f).to eq(15000.0)
    end
  end
end
