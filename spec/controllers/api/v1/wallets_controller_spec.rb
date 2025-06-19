require 'rails_helper'

RSpec.describe Api::V1::WalletsController, type: :controller do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet, user: user, balance: 15000) }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authorize_request).and_return(true)
  end

  describe 'GET #show' do
    context 'when user has a wallet' do
      before { wallet }

      it 'returns wallet information with formatted currency' do
        get :show
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['balance']).to eq(15000)
        expect(json_response['formatted_balance']).to eq('₩15,000')
        expect(json_response['transaction_count']).to be_present
      end
    end

    context 'when user does not have a wallet' do
      it 'creates a new wallet and returns information' do
        expect {
          get :show
        }.to change(Wallet, :count).by(1)
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        expect(json_response['balance']).to eq(5000) # default balance
        expect(json_response['formatted_balance']).to eq('₩5,000')
      end
    end
  end

  describe 'GET #my_wallet' do
    it 'calls show method' do
      expect(controller).to receive(:show)
      get :my_wallet
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
  end
end