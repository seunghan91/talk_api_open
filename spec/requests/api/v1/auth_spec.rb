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

    # 폰 인증이 미리 완료되었다고 가정
    before do
      verification = PhoneVerification.create(
        phone_number: '01012345678',
        code: '123456',
        verified: true,
        expires_at: 1.hour.from_now
      )
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

      # 개발 환경에서는 코드가 응답에 포함되어야 함
      if Rails.env.development? || Rails.env.test?
        expect(json).to have_key('code')
        expect(json).to have_key('expires_at')
      end
    end
  end

  describe 'POST /api/v1/auth/verify_code' do
    let(:phone_number) { '01012345678' }
    let(:code) { '123456' }

    before do
      # 인증 코드 생성
      PhoneVerification.create(
        phone_number: phone_number,
        code: code,
        verified: false,
        expires_at: 10.minutes.from_now
      )
    end

    it '인증 코드 확인 성공' do
      post '/api/v1/auth/verify_code', params: { phone_number: phone_number, code: code }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be_truthy

      # 인증 상태가 업데이트되었는지 확인
      verification = PhoneVerification.find_by(phone_number: phone_number)
      expect(verification.verified).to be_truthy
    end

    it '인증 코드가 틀리면 실패' do
      post '/api/v1/auth/verify_code', params: { phone_number: phone_number, code: 'wrong_code' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('인증코드')
    end

    it '만료된 인증 코드는 실패' do
      # 만료된 인증 코드 생성
      expired_verification = PhoneVerification.create(
        phone_number: '01099999999',
        code: '999999',
        verified: false,
        expires_at: 10.minutes.ago
      )

      post '/api/v1/auth/verify_code', params: { phone_number: '01099999999', code: '999999' }
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to include('만료')
    end
  end
end
