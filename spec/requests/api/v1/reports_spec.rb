require 'rails_helper'

RSpec.describe 'Api::V1::Reports', type: :request do
  let!(:user) { create(:user) }
  let!(:other_user) { create(:user) }
  let(:auth_headers) { auth_headers_for(user) }

  # JSON response helper
  def json_response
    JSON.parse(response.body)
  end

  describe 'POST /api/v1/reports' do
    let(:valid_params) do
      {
        report: {
          reported_id: other_user.id,
          report_type: 'user',
          reason: 'harassment'
        }
      }
    end

    context 'with valid parameters' do
      it 'creates a new report' do
        expect {
          post '/api/v1/reports', params: valid_params, headers: auth_headers
        }.to change(Report, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(json_response['report']['reported_id']).to eq(other_user.id)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post '/api/v1/reports', params: valid_params
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable entity when reported_id is missing' do
        invalid_params = { report: { report_type: 'user', reason: 'harassment' } }
        post '/api/v1/reports', params: invalid_params, headers: auth_headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v1/reports/my_reports' do
    context 'with authentication' do
      it 'returns user reports list' do
        create(:report, reporter: user, reported: other_user, reason: 'test reason')
        get '/api/v1/reports/my_reports', headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('reports')
        expect(json_response['reports']).not_to be_empty
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/reports/my_reports'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/users/:id/block' do
    let!(:user_to_block) { create(:user) }

    context 'with valid authentication' do
      it 'blocks the user successfully' do
        post "/api/v1/users/#{user_to_block.id}/block", headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(json_response['message']).to be_present
      end

      it 'creates a Block record' do
        expect {
          post "/api/v1/users/#{user_to_block.id}/block", headers: auth_headers
        }.to change(Block, :count).by(1)
      end

      it 'returns ok when user is already blocked' do
        Block.create!(blocker_id: user.id, blocked_id: user_to_block.id)
        post "/api/v1/users/#{user_to_block.id}/block", headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/users/#{user_to_block.id}/block"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user does not exist' do
      it 'returns not found' do
        post '/api/v1/users/999999/block', headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET /api/v1/users/blocks' do
    context 'with authentication' do
      it 'returns blocked users list' do
        blocked = create(:user)
        Block.create!(blocker_id: user.id, blocked_id: blocked.id)
        get '/api/v1/users/blocks', headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('blocks')
        expect(json_response['blocks'].first['blocked_user']['id']).to eq(blocked.id)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/users/blocks'
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/users/:id/unblock' do
    let!(:blocked_user) { create(:user) }

    before do
      Block.create!(blocker_id: user.id, blocked_id: blocked_user.id)
    end

    context 'with authentication' do
      it 'unblocks the user successfully' do
        post "/api/v1/users/#{blocked_user.id}/unblock", headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(json_response['message']).to be_present
        expect(Block.exists?(blocker_id: user.id, blocked_id: blocked_user.id)).to be(false)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        post "/api/v1/users/#{blocked_user.id}/unblock"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when user is not blocked' do
      it 'returns not found' do
        other = create(:user)
        post "/api/v1/users/#{other.id}/unblock", headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
