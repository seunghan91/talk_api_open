require 'rails_helper'

RSpec.describe "Api::V1::Broadcasts", type: :request do
  # ActiveJob 테스트 모드 설정 (Solid Queue)
  include ActiveJob::TestHelper

  # 테스트용 사용자 및 인증 헤더 설정
  let!(:user) { create(:user, phone_number: "01012345678") }
  let(:auth_headers) { auth_headers_for(user) }
  let(:valid_audio_file) { fixture_file_upload(Rails.root.join('spec', 'fixtures', 'files', 'sample_audio.wav'), 'audio/wav') }

  before do
    # 테스트 전 사용자 지갑에 충분한 잔액 설정
    user.wallet.update!(balance: 10000)
  end

  # ===================================================================
  #   POST /api/v1/broadcasts - 방송 생성
  # ===================================================================
  describe "POST /api/v1/broadcasts" do
    context "with valid parameters" do
      let(:valid_attributes) { { broadcast: { voice_file: valid_audio_file, content: "테스트 방송입니다.", recipient_count: 5 } } }

      it "creates a new Broadcast successfully" do
        create_list(:user, 5)
        post "/api/v1/broadcasts", params: valid_attributes, headers: auth_headers
        expect(response).to have_http_status(:created)
      end
    end

    context "with invalid parameters (missing voice_file)" do
      let(:invalid_attributes) { { broadcast: { content: "음성 파일 없는 방송" } } }

      it "does not create a new Broadcast and returns an error" do
        expect {
          post "/api/v1/broadcasts", params: invalid_attributes, headers: auth_headers
        }.not_to change(Broadcast, :count)

        # Controller may return bad_request or unprocessable_entity
        expect(response.status).to be_in([400, 422])
        expect(json_response['error']).to be_present
      end
    end

    context "without authentication" do
      it "returns unauthorized" do
        post "/api/v1/broadcasts", params: { broadcast: { content: "test" } }
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   POST /api/v1/broadcasts/:id/reply - 방송에 답장하기
  # ===================================================================
  describe "POST /api/v1/broadcasts/:id/reply" do
    let!(:sender) { create(:user, nickname: "방송인") }
    let!(:broadcast) { create(:broadcast, user: sender) }
    let!(:recipient) { user } # 현재 로그인한 사용자가 수신자
    let!(:broadcast_recipient) { create(:broadcast_recipient, broadcast: broadcast, user: recipient) }

    let(:reply_attributes) { { voice_file: valid_audio_file } }

    context "when the user is a valid recipient" do
      it "processes the reply request" do
        post "/api/v1/broadcasts/#{broadcast.id}/reply", params: reply_attributes, headers: auth_headers
        expect(response).to have_http_status(:ok)
      end
    end

    context "when the user is not a recipient" do
      let!(:non_recipient) { create(:user) }
      let(:non_recipient_headers) { auth_headers_for(non_recipient) }

      it "returns a forbidden error" do
        post "/api/v1/broadcasts/#{broadcast.id}/reply", params: reply_attributes, headers: non_recipient_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when the broadcast does not exist" do
      it "returns a not found error" do
        post "/api/v1/broadcasts/99999/reply", params: reply_attributes, headers: auth_headers
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with invalid parameters (missing voice_file)" do
      it "returns an error" do
        post "/api/v1/broadcasts/#{broadcast.id}/reply", params: { voice_file: nil }, headers: auth_headers
        expect(response.status).to be_in([400, 422])
      end
    end
  end

  # ===================================================================
  #   GET /api/v1/broadcasts - 방송 목록 조회
  # ===================================================================
  describe "GET /api/v1/broadcasts" do
    it "returns broadcasts list" do
      get "/api/v1/broadcasts", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(json_response).to have_key('broadcasts')
    end
  end

  # ===================================================================
  #   GET /api/v1/broadcasts/received - 수신 방송 목록 조회
  # ===================================================================
  describe "GET /api/v1/broadcasts/received" do
    it "returns received broadcasts list" do
      get "/api/v1/broadcasts/received", headers: auth_headers

      expect(response).to have_http_status(:success)
      expect(json_response).to have_key('broadcasts')
    end
  end

  # JSON 응답을 파싱하는 헬퍼 메서드
  def json_response
    JSON.parse(response.body)
  end
end
