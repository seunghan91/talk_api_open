require 'rails_helper'

RSpec.describe Api::V1::WalletsController, type: :controller do
  let(:user) { create(:user) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authorize_request).and_return(true)
    # Clear Rails cache to avoid stale data between tests
    Rails.cache.clear
  end

  describe 'GET #my_wallet' do
    context 'when user has a wallet (auto-created)' do
      before do
        # User model auto-creates wallet with balance 0
        # Update balance to test specific value
        user.wallet.update!(balance: 15000)
      end

      it 'returns wallet information with formatted currency' do
        get :my_wallet

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
        get :my_wallet

        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)

        # Default balance is 0 (set in Wallet model)
        # Balance is decimal type, may be returned as string or number depending on caching
        expect(json_response['balance'].to_i).to eq(0)
        expect(json_response['formatted_balance']).to eq('₩0')
        expect(json_response['transaction_count'].to_i).to eq(0)
      end
    end

    it 'delegates to show method' do
      expect(controller).to receive(:show).and_call_original
      get :my_wallet
    end
  end

  describe 'GET #show (via ID route)' do
    it 'returns wallet information when accessed with wallet ID' do
      user.wallet.update!(balance: 5000)

      get :show, params: { id: user.wallet.id }

      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)

      # Balance is decimal type, may be returned as string or number depending on caching
      expect(json_response['balance'].to_i).to eq(5000)
      expect(json_response['formatted_balance']).to eq('₩5,000')
    end
  end

  describe '#format_currency (private method)' do
    it 'formats currency correctly' do
      # Access private method for testing
      formatted = controller.send(:format_currency, 15000)
      expect(formatted).to eq('₩15,000')

      formatted_large = controller.send(:format_currency, 1234567)
      expect(formatted_large).to eq('₩1,234,567')
    end

    it 'formats zero correctly' do
      formatted = controller.send(:format_currency, 0)
      expect(formatted).to eq('₩0')
    end
  end
end
