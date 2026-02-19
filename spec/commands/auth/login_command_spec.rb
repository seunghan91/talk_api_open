# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::LoginCommand do
  let(:phone_number) { "01012345678" }
  let(:password) { "test1234" }
  let!(:user) do
    create(:user, phone_number: phone_number, password: password, nickname: "TestUser")
  end

  subject(:result) do
    described_class.new(phone_number: phone_number, password: password).execute
  end

  describe "#execute" do
    context "happy path - valid credentials" do
      it "returns success with user and user_data" do
        expect(result[:success]).to be true
        expect(result[:user]).to eq(user)
        expect(result[:user_data]).to be_a(Hash)
      end

      it "returns serialized user_data in correct format" do
        user_data = result[:user_data]

        expect(user_data).to include(
          id: user.id,
          nickname: user.nickname,
          phone_number: user.phone_number
        )
        expect(user_data).to have_key(:last_login_at)
        expect(user_data).to have_key(:created_at)
      end

      it "updates last_login_at on success" do
        freeze_time do
          result
          user.reload
          expect(user.last_login_at).to be_within(1.second).of(Time.current)
        end
      end
    end

    context "missing phone_number" do
      subject(:result) do
        described_class.new(phone_number: "", password: password).execute
      end

      it "returns error response" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("전화번호를 입력해 주세요.")
        expect(result[:status]).to eq(:bad_request)
      end
    end

    context "missing password" do
      subject(:result) do
        described_class.new(phone_number: phone_number, password: "").execute
      end

      it "returns error response" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("비밀번호를 입력해 주세요.")
        expect(result[:status]).to eq(:bad_request)
      end
    end

    context "non-existent user" do
      subject(:result) do
        described_class.new(phone_number: "01099999999", password: password).execute
      end

      it "returns unauthorized with generic message (no user enumeration)" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("전화번호 또는 비밀번호가 올바르지 않습니다.")
        expect(result[:status]).to eq(:unauthorized)
      end
    end

    context "wrong password" do
      subject(:result) do
        described_class.new(phone_number: phone_number, password: "wrongpass").execute
      end

      it "returns unauthorized with same generic message as non-existent user" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("전화번호 또는 비밀번호가 올바르지 않습니다.")
        expect(result[:status]).to eq(:unauthorized)
      end
    end

    context "suspended user" do
      let(:expires_at) { 7.days.from_now }
      let(:mock_repo) { instance_double(UserRepository) }

      before do
        create(:user_suspension, user: user, reason: "규칙 위반", suspended_until: expires_at, active: true)
        # Reload so the association is fresh, then set the virtual status attribute
        user.reload
        user.status = :suspended
        allow(mock_repo).to receive(:find_by_phone).with(phone_number).and_return(user)
      end

      subject(:result) do
        described_class.new(phone_number: phone_number, password: password, user_repository: mock_repo).execute
      end

      it "returns forbidden with suspension details" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("계정이 일시 정지되었습니다.")
        expect(result[:status]).to eq(:forbidden)
        expect(result[:reason]).to eq("규칙 위반")
        expect(result[:suspended_until]).to be_present
      end
    end

    context "banned user" do
      let(:mock_repo) { instance_double(UserRepository) }

      before do
        user.status = :banned
        allow(mock_repo).to receive(:find_by_phone).with(phone_number).and_return(user)
      end

      subject(:result) do
        described_class.new(phone_number: phone_number, password: password, user_repository: mock_repo).execute
      end

      it "returns forbidden for banned account" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("계정이 영구 정지되었습니다.")
        expect(result[:status]).to eq(:forbidden)
      end
    end

    context "active user" do
      it "succeeds for active user" do
        expect(result[:success]).to be true
        expect(result[:user].status).to eq("active")
      end
    end

    context "dependency injection" do
      it "accepts a custom user_repository" do
        mock_repo = instance_double(UserRepository)
        allow(mock_repo).to receive(:find_by_phone).with(phone_number).and_return(user)

        command = described_class.new(
          phone_number: phone_number,
          password: password,
          user_repository: mock_repo
        )
        result = command.execute

        expect(result[:success]).to be true
        expect(mock_repo).to have_received(:find_by_phone).with(phone_number)
      end
    end
  end
end
