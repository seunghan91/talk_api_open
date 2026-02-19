# frozen_string_literal: true

require "rails_helper"

RSpec.describe Auth::RegisterUserCommand do
  let(:phone_number) { "01098765432" }
  let(:password) { "secure123" }
  let(:password_confirmation) { "secure123" }
  let(:nickname) { "NewUser" }
  let(:gender) { "male" }

  let(:mock_notification_service) { instance_double(NotificationService) }
  let(:mock_wallet_service) { instance_double(WalletService) }

  before do
    allow(mock_notification_service).to receive(:send_welcome_notification)
    allow(mock_wallet_service).to receive(:create_wallet_for_user)
  end

  subject(:result) do
    described_class.new(
      phone_number: phone_number,
      password: password,
      password_confirmation: password_confirmation,
      nickname: nickname,
      gender: gender,
      notification_service: mock_notification_service,
      wallet_service: mock_wallet_service
    ).execute
  end

  describe "#execute" do
    context "happy path - verified phone + valid params" do
      it "creates a user and returns success" do
        expect(result[:success]).to be true
        expect(result[:user]).to be_a(User)
        expect(result[:user]).to be_persisted
        expect(result[:user_data]).to include(
          nickname: nickname,
          phone_number: phone_number
        )
      end

      it "creates the user in the database" do
        expect { result }.to change(User, :count).by(1)
      end
    end

    context "missing required fields" do
      context "missing phone_number" do
        let(:phone_number) { "" }

        it "returns validation error" do
          expect(result[:success]).to be false
          expect(result[:error]).to eq("전화번호를 입력해 주세요.")
          expect(result[:status]).to eq(:bad_request)
        end
      end

      context "missing password" do
        let(:password) { "" }

        it "returns validation error" do
          expect(result[:success]).to be false
          expect(result[:error]).to eq("비밀번호를 입력해 주세요.")
          expect(result[:status]).to eq(:bad_request)
        end
      end

      context "missing nickname" do
        let(:nickname) { "" }

        it "returns validation error" do
          expect(result[:success]).to be false
          expect(result[:error]).to eq("닉네임을 입력해 주세요.")
          expect(result[:status]).to eq(:bad_request)
        end
      end
    end

    context "password confirmation mismatch" do
      let(:password_confirmation) { "different123" }

      it "returns error" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("비밀번호가 일치하지 않습니다.")
        expect(result[:status]).to eq(:bad_request)
      end
    end

    context "password too short" do
      let(:password) { "abc" }
      let(:password_confirmation) { "abc" }

      it "returns error" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("비밀번호는 6자 이상이어야 합니다.")
        expect(result[:status]).to eq(:bad_request)
      end
    end

    context "unverified phone number" do
      before do
        # In test env, skip_verification? returns true and auto-creates verification.
        # To test the unverified path, we need to stub skip_verification? to return false.
        allow_any_instance_of(described_class).to receive(:skip_verification?).and_return(false)
      end

      it "returns error for unverified phone" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("인증이 완료되지 않은 전화번호입니다.")
        expect(result[:status]).to eq(:unprocessable_entity)
        expect(result[:verification_required]).to be true
      end

      context "with expired verification" do
        before do
          create(:phone_verification, :verified, phone_number: phone_number, updated_at: 1.hour.ago)
        end

        it "returns error for expired verification" do
          expect(result[:success]).to be false
          expect(result[:error]).to eq("인증 시간이 초과되었습니다. 인증을 다시 진행해주세요.")
          expect(result[:verification_required]).to be true
        end
      end

      context "with valid verification" do
        before do
          create(:phone_verification, :verified, phone_number: phone_number, updated_at: Time.current)
        end

        it "succeeds" do
          expect(result[:success]).to be true
        end
      end
    end

    context "phone already registered" do
      before do
        create(:user, phone_number: phone_number)
      end

      it "returns error" do
        expect(result[:success]).to be false
        expect(result[:error]).to eq("이미 등록된 전화번호입니다.")
        expect(result[:user_exists]).to be true
        expect(result[:status]).to eq(:unprocessable_entity)
      end
    end

    context "wallet auto-creation on registration" do
      it "calls wallet_service to create wallet" do
        result
        expect(mock_wallet_service).to have_received(:create_wallet_for_user).once
      end
    end

    context "welcome notification sent" do
      it "sends welcome notification" do
        result
        expect(mock_notification_service).to have_received(:send_welcome_notification).once
      end
    end

    context "auto-verification in test environment" do
      it "auto-creates phone verification when none exists" do
        expect { result }.to change(PhoneVerification, :count).by(1)

        verification = PhoneVerification.find_by(phone_number: phone_number)
        expect(verification).to be_present
        expect(verification.verified).to be true
      end
    end

    context "default gender" do
      subject(:result) do
        described_class.new(
          phone_number: phone_number,
          password: password,
          password_confirmation: password_confirmation,
          nickname: nickname,
          notification_service: mock_notification_service,
          wallet_service: mock_wallet_service
        ).execute
      end

      it "defaults to unspecified when gender is not provided" do
        pending "User model may not accept 'unspecified' as valid gender enum if not configured"
        expect(result[:success]).to be true
        expect(result[:user].gender).to eq("unspecified")
      end
    end

    context "serialized user data format" do
      it "returns correct user_data keys" do
        user_data = result[:user_data]

        expect(user_data).to have_key(:id)
        expect(user_data).to have_key(:nickname)
        expect(user_data).to have_key(:phone_number)
        expect(user_data).to have_key(:created_at)
      end
    end
  end
end
