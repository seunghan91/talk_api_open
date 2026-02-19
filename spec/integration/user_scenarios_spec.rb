# spec/integration/user_scenarios_spec.rb
require 'rails_helper'

RSpec.describe 'User Scenario Tests', type: :request do
  # ActiveJob 테스트 모드 (Solid Queue)
  include ActiveJob::TestHelper

  # ============================================
  # 페르소나 정의
  # ============================================

  # 페르소나 1: 김민수 (25세 남성, 적극적 사용자)
  # - 매일 앱을 사용하는 활성 사용자
  # - 브로드캐스트를 자주 보내고 답장도 적극적으로 함
  # - 프리미엄 기능에 관심 있음
  let(:minsu) do
    create(:user,
      nickname: '김민수',
      gender: 'male',
      verified: true,
      blocked: false
    ).tap { |u| u.wallet.update(balance: 5000) }
  end

  # 페르소나 2: 이수진 (23세 여성, 신규 사용자)
  # - 앱을 처음 사용하는 신규 가입자
  # - 브로드캐스트를 받아보고 관심 있으면 답장
  # - 조심스러운 성격으로 차단 기능 활용
  let(:sujin) do
    create(:user,
      nickname: '이수진',
      gender: 'female',
      verified: true,
      blocked: false
    ).tap { |u| u.wallet.update(balance: 1000) }
  end

  # 페르소나 3: 박지훈 (28세 남성, 비활성 사용자)
  # - 가끔씩 앱을 사용
  # - 브로드캐스트는 받기만 하고 거의 답장 안 함
  let(:jihoon) do
    create(:user,
      nickname: '박지훈',
      gender: 'male',
      verified: true,
      blocked: false
    ).tap { |u| u.wallet.update(balance: 500) }
  end

  # 페르소나 4: 최유리 (26세 여성, 활성 사용자)
  # - 브로드캐스트에 적극적으로 답장
  # - 대화를 즐기는 사교적인 성격
  let(:yuri) do
    create(:user,
      nickname: '최유리',
      gender: 'female',
      verified: true,
      blocked: false
    ).tap { |u| u.wallet.update(balance: 3000) }
  end

  # 페르소나 5: 정태현 (30세 남성, 프리미엄 사용자)
  # - 프리미엄 구독자
  # - 하루에 여러 번 브로드캐스트 전송
  let(:taehyun) do
    create(:user,
      nickname: '정태현',
      gender: 'male',
      verified: true,
      blocked: false
    ).tap { |u| u.wallet.update(balance: 50000) }
  end

  let(:audio_file) do
    fixture_file_upload(Rails.root.join('spec/fixtures/files/sample_audio.wav'), 'audio/wav')
  end

  # ============================================
  # 시나리오 1: 신규 사용자의 첫 브로드캐스트 수신 및 답장
  # ============================================
  describe '시나리오 1: 신규 사용자 수진이의 첫 경험' do
    before do
      # 여성 사용자들 생성 (수신자 풀)
      create_list(:user, 5, gender: 'female', verified: true, blocked: false)
    end

    it '수진이가 민수의 브로드캐스트를 받고 답장하여 대화가 시작된다' do
      # Step 1: 민수가 브로드캐스트 전송
      post '/api/v1/broadcasts',
        params: {
          broadcast: {
            voice_file: audio_file,
            content: '안녕하세요! 오늘 날씨가 좋네요.',
            recipient_count: 3
          }
        },
        headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:created)
      broadcast_id = JSON.parse(response.body)['broadcast']['id']

      # Step 2: 수신자 수동 설정 (ActiveJob test mode)
      broadcast = Broadcast.find(broadcast_id)
      BroadcastRecipient.create!(broadcast: broadcast, user: sujin, status: :delivered)

      # Step 3: 수진이가 브로드캐스트에 답장
      post "/api/v1/broadcasts/#{broadcast_id}/reply",
        params: { voice_file: audio_file },
        headers: auth_headers_for(sujin)

      expect(response).to have_http_status(:ok)
      conversation_data = JSON.parse(response.body)['conversation']
      expect(conversation_data).to be_present

      # Step 4: 대화방 생성 확인
      conversation = Conversation.find(conversation_data['id'])
      expect([conversation.user_a_id, conversation.user_b_id]).to match_array([minsu.id, sujin.id])

      # Step 5: 민수가 대화 목록에서 수진과의 대화 확인
      get '/api/v1/conversations', headers: auth_headers_for(minsu)
      expect(response).to have_http_status(:ok)

      conversations = JSON.parse(response.body)['conversations']
      expect(conversations).to be_present
    end
  end

  # ============================================
  # 시나리오 2: 활성 사용자 간의 대화 플로우
  # ============================================
  describe '시나리오 2: 민수와 유리의 활발한 대화' do
    let!(:conversation) do
      Conversation.create!(
        user_a: minsu,
        user_b: yuri,
        deleted_by_a: false,
        deleted_by_b: false
      )
    end

    it '민수와 유리가 메시지를 주고받는다' do
      # Step 1: 민수가 유리에게 메시지 전송
      post "/api/v1/conversations/#{conversation.id}/send_message",
        params: { voice_file: audio_file },
        headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:created)

      # Step 2: 유리가 대화 조회
      get "/api/v1/conversations/#{conversation.id}",
        headers: auth_headers_for(yuri)

      expect(response).to have_http_status(:ok)
      messages = JSON.parse(response.body)['messages']
      expect(messages.length).to be >= 1

      # Step 3: 유리가 답장
      post "/api/v1/conversations/#{conversation.id}/send_message",
        params: { voice_file: audio_file },
        headers: auth_headers_for(yuri)

      expect(response).to have_http_status(:created)

      # Step 4: 대화 메시지 수 확인
      get "/api/v1/conversations/#{conversation.id}",
        headers: auth_headers_for(minsu)

      messages = JSON.parse(response.body)['messages']
      expect(messages.length).to eq(2)
    end

    it '유리가 대화를 즐겨찾기에 추가한다' do
      post "/api/v1/conversations/#{conversation.id}/favorite",
        headers: auth_headers_for(yuri)

      expect(response).to have_http_status(:ok)
    end
  end

  # ============================================
  # 시나리오 3: 포인트 부족 상황
  # ============================================
  describe '시나리오 3: 지훈이의 포인트 부족' do
    it '포인트가 부족하면 브로드캐스트를 보낼 수 없다' do
      # 지훈의 포인트를 0으로 설정
      jihoon.wallet.update(balance: 0)

      post '/api/v1/broadcasts',
        params: {
          broadcast: {
            voice_file: audio_file,
            content: '테스트 메시지',
            recipient_count: 1
          }
        },
        headers: auth_headers_for(jihoon)

      expect(response).to have_http_status(:payment_required)
      expect(JSON.parse(response.body)['error']).to include('포인트')
    end
  end

  # ============================================
  # 시나리오 4: 프리미엄 사용자의 대량 브로드캐스트
  # ============================================
  describe '시나리오 4: 태현이의 프리미엄 사용' do
    before do
      # 충분한 여성 사용자 생성
      create_list(:user, 10, gender: 'female', verified: true, blocked: false)
    end

    it '프리미엄 사용자가 여러 명에게 브로드캐스트를 보낸다' do
      post '/api/v1/broadcasts',
        params: {
          broadcast: {
            voice_file: audio_file,
            content: '프리미엄 사용자의 브로드캐스트입니다.',
            recipient_count: 5
          }
        },
        headers: auth_headers_for(taehyun)

      expect(response).to have_http_status(:created)
      result = JSON.parse(response.body)
      expect(result['broadcast']).to be_present
    end

    it '프리미엄 사용자의 지갑 잔액이 충분하다' do
      get '/api/v1/wallets/my_wallet', headers: auth_headers_for(taehyun)

      expect(response).to have_http_status(:ok)
      wallet_data = JSON.parse(response.body)
      expect(wallet_data['balance'].to_i).to eq(50000)
    end
  end

  # ============================================
  # 시나리오 5: 권한 없는 접근 시도
  # ============================================
  describe '시나리오 5: 권한 없는 접근 방지' do
    let!(:conversation) do
      Conversation.create!(
        user_a: minsu,
        user_b: yuri,
        deleted_by_a: false,
        deleted_by_b: false
      )
    end

    it '지훈이는 민수와 유리의 대화를 볼 수 없다' do
      get "/api/v1/conversations/#{conversation.id}",
        headers: auth_headers_for(jihoon)

      expect(response).to have_http_status(:forbidden)
    end

    it '지훈이는 민수와 유리의 대화에 메시지를 보낼 수 없다' do
      post "/api/v1/conversations/#{conversation.id}/send_message",
        params: { voice_file: audio_file },
        headers: auth_headers_for(jihoon)

      expect(response).to have_http_status(:forbidden)
    end
  end

  # ============================================
  # 시나리오 6: 대화 삭제 및 복구
  # ============================================
  describe '시나리오 6: 수진이의 대화 관리' do
    let!(:conversation) do
      Conversation.create!(
        user_a: minsu,
        user_b: sujin,
        deleted_by_a: false,
        deleted_by_b: false
      )
    end

    it '수진이가 대화를 삭제해도 민수에게는 보인다' do
      # Step 1: 수진이가 대화 삭제
      delete "/api/v1/conversations/#{conversation.id}",
        headers: auth_headers_for(sujin)

      expect(response).to have_http_status(:ok)

      # Step 2: 민수에게는 여전히 보임
      get "/api/v1/conversations/#{conversation.id}",
        headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:ok)

      # Step 3: 수진에게는 안 보임
      get "/api/v1/conversations/#{conversation.id}",
        headers: auth_headers_for(sujin)

      # 삭제된 대화는 forbidden, not_found, 또는 gone
      expect(response.status).to be_in([403, 404, 410])
    end
  end

  # ============================================
  # 시나리오 7: 인증 실패 케이스
  # ============================================
  describe '시나리오 7: 인증 실패 처리' do
    it '토큰 없이 API 접근 시 401 에러' do
      get '/api/v1/conversations'
      expect(response).to have_http_status(:unauthorized)
    end

    it '잘못된 토큰으로 접근 시 401 에러' do
      get '/api/v1/conversations',
        headers: { 'Authorization' => 'Bearer invalid_token' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ============================================
  # 시나리오 8: 사용자 프로필 조회 및 수정
  # ============================================
  describe '시나리오 8: 민수의 프로필 관리' do
    it '민수가 자신의 프로필을 조회한다' do
      get '/api/v1/users/me', headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:ok)
      user_data = JSON.parse(response.body)['user']
      expect(user_data['nickname']).to eq('김민수')
    end

    it '민수가 닉네임을 변경한다' do
      post '/api/v1/users/change_nickname',
        params: { nickname: '민수킴' },
        headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:ok)

      minsu.reload
      expect(minsu.nickname).to eq('민수킴')
    end
  end

  # ============================================
  # 시나리오 9: 공지사항 조회
  # ============================================
  describe '시나리오 9: 공지사항 확인' do
    let!(:category) { create(:announcement_category, name: '서비스 공지') }
    let!(:announcement) do
      create(:announcement,
        title: '서비스 업데이트 안내',
        content: 'Rails 8.1로 업그레이드되었습니다.',
        category: category,
        is_published: true
      )
    end

    it '사용자가 공지사항 목록을 조회한다' do
      get '/api/v1/announcements', headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:ok)
      announcements = JSON.parse(response.body)['announcements']
      expect(announcements).to be_present
    end
  end

  # ============================================
  # 시나리오 10: 전체 사용자 여정 (End-to-End)
  # ============================================
  describe '시나리오 10: 완전한 사용자 여정' do
    before do
      create_list(:user, 5, gender: 'female', verified: true, blocked: false)
    end

    it '회원가입부터 대화까지 전체 플로우' do
      # Step 1: 민수가 브로드캐스트 전송
      post '/api/v1/broadcasts',
        params: {
          broadcast: {
            voice_file: audio_file,
            content: '안녕하세요! 좋은 하루 되세요.',
            recipient_count: 2
          }
        },
        headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:created)
      broadcast_id = JSON.parse(response.body)['broadcast']['id']

      # Step 2: 수진이 수신자로 설정
      broadcast = Broadcast.find(broadcast_id)
      BroadcastRecipient.create!(broadcast: broadcast, user: sujin, status: :delivered)

      # Step 3: 수진이 답장하여 대화 시작
      post "/api/v1/broadcasts/#{broadcast_id}/reply",
        params: { voice_file: audio_file },
        headers: auth_headers_for(sujin)

      expect(response).to have_http_status(:ok)
      conversation_id = JSON.parse(response.body)['conversation']['id']

      # Step 4: 민수가 대화 목록 확인
      get '/api/v1/conversations', headers: auth_headers_for(minsu)
      expect(response).to have_http_status(:ok)

      # Step 5: 민수가 답장
      post "/api/v1/conversations/#{conversation_id}/send_message",
        params: { voice_file: audio_file },
        headers: auth_headers_for(minsu)

      expect(response).to have_http_status(:created)

      # Step 6: 수진이 대화 확인
      get "/api/v1/conversations/#{conversation_id}",
        headers: auth_headers_for(sujin)

      expect(response).to have_http_status(:ok)
      messages = JSON.parse(response.body)['messages']
      expect(messages.length).to eq(2)  # 수진의 답장 + 민수의 메시지

      # Step 7: 지갑 잔액 확인 (브로드캐스트 비용 차감)
      get '/api/v1/wallets/my_wallet', headers: auth_headers_for(minsu)
      expect(response).to have_http_status(:ok)

      current_balance = JSON.parse(response.body)['balance'].to_i
      expect(current_balance).to be < 5000  # 초기 잔액보다 적음
    end
  end

  private

  def json_response
    JSON.parse(response.body)
  end
end
