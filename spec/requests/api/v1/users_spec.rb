require 'rails_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  let(:user) { create(:user) }
  let(:auth_headers) { auth_headers_for(user) }

  describe 'GET /api/v1/users/random_nickname' do
    it '랜덤 닉네임을 정상적으로 반환' do
      get '/api/v1/users/generate_random_nickname', headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to have_key('nickname')
    end
  end

  describe 'POST /api/v1/users/change_nickname' do
    it '닉네임 변경 성공' do
      post '/api/v1/users/change_nickname', params: { nickname: '새닉네임' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.nickname).to eq('새닉네임')
    end
    
    it '닉네임이 빈 문자열이면 실패' do
      post '/api/v1/users/change_nickname', params: { nickname: '' }, headers: auth_headers
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /api/v1/users/profile' do
    it '사용자 프로필 조회 성공' do
      get '/api/v1/users/profile', headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('id')
      expect(json).to have_key('nickname')
      expect(json).to have_key('phone_number')
    end
  end
  
  describe 'GET /api/v1/users/notification_settings' do
    it '알림 설정 조회 성공' do
      get '/api/v1/users/notification_settings', headers: auth_headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('push_enabled')
      expect(json).to have_key('broadcast_push_enabled')
      expect(json).to have_key('message_push_enabled')
    end
  end
  
  describe 'POST /api/v1/users/update_profile' do
    it '프로필 업데이트 성공' do
      post '/api/v1/users/update_profile', params: { gender: 'female' }, headers: auth_headers
      expect(response).to have_http_status(:ok)
      expect(user.reload.gender).to eq('female')
    end
  end
end 