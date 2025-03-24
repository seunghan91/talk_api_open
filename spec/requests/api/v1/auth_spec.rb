require 'rails_helper'

RSpec.describe 'Api::V1::Auth', type: :request do
  describe 'POST /api/v1/auth/register' do
    let(:valid_params) do
      {
        phone_number: '01012345678',
        password: 'test1234',
        nickname: '테스터',
        gender: 'unspecified'
      }
    end

    it '회원가입 성공' do
      post '/api/v1/auth/register', params: valid_params
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['phone_number']).to eq('01012345678')
    end

    it '전화번호가 누락되면 실패' do
      post '/api/v1/auth/register', params: valid_params.except(:phone_number)
      expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:bad_request)
    end
    
    it '비밀번호가 누락되면 실패' do
      post '/api/v1/auth/register', params: valid_params.except(:password)
      expect(response).to have_http_status(:unprocessable_entity).or have_http_status(:bad_request)
    end
  end
  
  describe 'POST /api/v1/auth/login' do
    let!(:user) { create(:user, phone_number: '01012345678', password: 'test1234') }
    
    it '로그인 성공' do
      post '/api/v1/auth/login', params: { phone_number: '01012345678', password: 'test1234' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('token')
      expect(json['phone_number']).to eq('01012345678')
    end
    
    it '비밀번호가 틀리면 실패' do
      post '/api/v1/auth/login', params: { phone_number: '01012345678', password: 'wrong' }
      expect(response).to have_http_status(:unauthorized)
    end
  end
  
  describe 'POST /api/v1/auth/request_code' do
    it '인증 코드 요청 성공' do
      post '/api/v1/auth/request_code', params: { phone_number: '01012345678' }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key('message')
    end
  end
  
  describe 'POST /api/v1/auth/verify_code' do
    let(:phone_number) { '01012345678' }
    
    before do
      post '/api/v1/auth/request_code', params: { phone_number: phone_number }
      @code = JSON.parse(response.body)['code'] if Rails.env.development? || Rails.env.test?
    end
    
    it '인증 코드 확인 성공' do
      post '/api/v1/auth/verify_code', params: { phone_number: phone_number, code: @code }
      expect(response).to have_http_status(:ok)
    end
    
    it '인증 코드가 틀리면 실패' do
      post '/api/v1/auth/verify_code', params: { phone_number: phone_number, code: '999999' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end 