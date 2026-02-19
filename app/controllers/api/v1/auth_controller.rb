# app/controllers/api/v1/auth_controller.rb
module Api
  module V1
    class AuthController < Api::V1::BaseController
      include ApiAuthentication

      # 인증 없이 접근 가능한 액션
      skip_before_action :authorize_request, only: [ :login, :register, :request_code, :verify_code, :check_phone, :resend_code ]

      # 로그인 처리
      def login
        # 로그 추가 - 전체 파라미터 상세 기록
        Rails.logger.info("로그인 요청 파라미터: #{params.inspect}")

        # 방어적 코드 추가: params.dig를 사용하여 안전하게 접근
        phone_number = params.dig(:user, :phone_number)
        password = params.dig(:user, :password)

        # 필수 파라미터 확인
        unless phone_number.present?
          return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
        end

        unless password.present?
          return render json: { error: "비밀번호를 입력해 주세요." }, status: :bad_request
        end

        Rails.logger.info("로그인 시도: #{phone_number}")

        begin
          # 전화번호로 사용자 찾기
          @user = User.find_by(phone_number: phone_number)

          # 사용자가 없거나 비밀번호가 일치하지 않으면
          unless @user && @user.authenticate(password)
            Rails.logger.warn("로그인 실패: #{phone_number} - 사용자가 없거나 비밀번호가 일치하지 않음")
            return render json: { error: "전화번호 또는 비밀번호가 올바르지 않습니다." }, status: :unauthorized
          end

          # 세션 토큰 생성
          session = start_new_session_for(@user)

          # 로그인 정보 저장 (최근 로그인 시간 등)
          @user.update(last_login_at: Time.current)

          # 성공 응답
          render json: {
            token: session.token,
            user: {
              id: @user.id,
              nickname: @user.nickname,
              phone_number: @user.phone_number,
              last_login_at: @user.last_login_at,
              created_at: @user.created_at
            },
            message: "로그인에 성공했습니다."
          }, status: :ok

          Rails.logger.info("로그인 성공: 사용자 ID #{@user.id}")
        rescue => e
          Rails.logger.error("로그인 중 오류 발생: #{e.message}")
          render json: { error: "로그인 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # 회원가입 처리
      def register
        # 로그 추가 - 전체 파라미터 상세 기록
        Rails.logger.info("회원가입 요청 파라미터: #{params.inspect}")

        # 방어적 코드 추가: params.dig를 사용하여 안전하게 접근
        phone_number = params.dig(:user, :phone_number)

        # 필수 파라미터 확인
        unless phone_number.present?
          return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
        end

        Rails.logger.info("회원가입 시도: #{phone_number}")

        begin
          # 이미 있는 전화번호인지 확인
          if User.exists?(phone_number: phone_number)
            Rails.logger.warn("회원가입 실패: #{phone_number} - 이미 등록된 전화번호")
            return render json: {
              error: "이미 등록된 전화번호입니다.",
              user_exists: true
            }, status: :unprocessable_entity
          end

          # 베타 테스트 기간 동안 인증 검증 과정 우회
          # 인증 레코드가 없는 경우 새로 생성하고 자동으로 인증됨으로 처리
          verification = PhoneVerification.find_by(phone_number: phone_number)
          if verification.nil?
            Rails.logger.info("베타 테스트 - 인증 없이 회원가입: #{phone_number}에 대한 자동 인증 생성")
            verification = PhoneVerification.create!(
              phone_number: phone_number,
              code: "123456", # 임시 코드
              expires_at: 1.hour.from_now,
              verified: true,
              attempt_count: 0
            )
          else
            # 이미 인증 레코드가 있는 경우 자동으로 인증됨으로 설정
            verification.update(verified: true)
          end

          # 아래 인증 검증 코드는 베타 테스트 기간 동안 주석 처리됨
          # 인증 검증
          # verified = verification.verified == true
          #
          # unless verified
          #   Rails.logger.warn("회원가입 실패: #{phone_number} - 인증되지 않은 전화번호 (verified: #{verification.verified})")
          #   return render json: {
          #     error: "인증이 완료되지 않은 전화번호입니다. 인증 코드를 확인해주세요.",
          #     verification_required: true,
          #     verification_status: {
          #       verified: false,
          #       can_resend: true,
          #       message: "인증 코드 확인이 필요합니다."
          #     }
          #   }, status: :unprocessable_entity
          # end
          #
          # # 인증 시간 확인 (추가 보안 - 인증 후 30분 이내만 회원가입 허용)
          # if verification.updated_at < 30.minutes.ago
          #   Rails.logger.warn("회원가입 실패: #{phone_number} - 인증 시간 초과 (#{verification.updated_at})")
          #   return render json: {
          #     error: "인증 시간이 초과되었습니다. 인증을 다시 진행해주세요.",
          #     verification_required: true,
          #     verification_status: {
          #       verified: false,
          #       can_resend: true,
          #       expired: true,
          #       message: "인증이 만료되었습니다."
          #     }
          #   }, status: :unprocessable_entity
          # end

          # 디버깅을 위한 파라미터 로깅
          Rails.logger.info("회원가입 파라미터: #{user_params.inspect}")

          # 사용자 생성
          @user = User.new(user_params)
          @user.last_login_at = Time.current

          if @user.save
            # 세션 토큰 생성
            session = start_new_session_for(@user)

            # 지갑 생성 (이미 존재하면 스킵)
            begin
              wallet = @user.wallet || Wallet.create!(user: @user, balance: 0)
              Rails.logger.info("지갑 상태: 사용자 ID #{@user.id}, 지갑 ID #{wallet.id}, 잔액 #{wallet.balance}")
            rescue ActiveRecord::RecordInvalid => e
              Rails.logger.warn("지갑 생성 실패 (이미 존재할 수 있음): #{e.message}")
              wallet = @user.wallet
            end

            # 성공 응답
            render json: {
              token: session.token,
              user: {
                id: @user.id,
                nickname: @user.nickname,
                phone_number: @user.phone_number,
                created_at: @user.created_at
              },
              message: "회원가입에 성공했습니다."
            }, status: :created

            Rails.logger.info("회원가입 성공: 사용자 ID #{@user.id} (베타 테스트 - 인증 없이 가입)")
          else
            Rails.logger.warn("회원가입 실패: #{params[:phone_number]} - #{@user.errors.full_messages.join(', ')}")
            render json: { error: @user.errors.full_messages.join(", ") }, status: :unprocessable_entity
          end
        rescue StandardError => e
          Rails.logger.error("회원가입 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "회원가입 중 오류가 발생했습니다. (#{e.message})" }, status: :internal_server_error
        end
      end

      # 인증 코드 요청
      def request_code
        # 로그 추가 - 전체 파라미터 상세 기록
        Rails.logger.info("인증코드 요청 파라미터: #{params.inspect}")

        # 방어적 코드 추가: params.dig를 사용하여 안전하게 접근
        phone_number = params.dig(:user, :phone_number)

        # 필수 파라미터 확인
        unless phone_number.present?
          return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
        end

        Rails.logger.info("인증코드 요청: #{phone_number}")

        # 전화번호 형식 검증
        unless valid_phone_number?(phone_number)
          Rails.logger.warn("인증코드 요청 실패: #{phone_number} - 유효하지 않은 전화번호 형식")
          return render json: { error: "유효하지 않은 전화번호 형식입니다." }, status: :bad_request
        end

        begin
          # 인증 코드 생성
          code = generate_secure_verification_code

          # 이미 인증 레코드가 있으면 업데이트, 없으면 새로 생성
          verification = PhoneVerification.find_or_initialize_by(phone_number: phone_number)
          verification.assign_attributes(
            code: code,
            expires_at: 10.minutes.from_now,
            verified: false,
            attempt_count: 0
          )
          verification.save!

          # 실제 환경에서는 SMS 전송
          if Rails.env.production?
            send_sms(phone_number, "인증 코드: #{code}")
            Rails.logger.info("SMS 전송 완료: #{phone_number}")
          end

          # 인증 코드를 로그에 기록 (디버깅용, 프로덕션에서도 로그에는 기록)
          Rails.logger.info("🔑 인증코드 발급: 전화번호=#{phone_number}, 코드=#{code}, 만료=#{verification.expires_at.strftime('%H:%M:%S')}")

          # 이미 가입된 사용자인지 확인
          user_exists = User.exists?(phone_number: phone_number)

          # 모든 환경에서 코드를 응답에 포함 (요청에 따른 임시 변경)
          render json: {
            message: "인증 코드가 발송되었습니다.",
            code: code,
            expires_at: verification.expires_at,
            user_exists: user_exists,  # 이미 가입된 사용자인지 여부
            note: "보안 주의: 모든 환경에서 코드가 직접 표시됩니다."
          }, status: :ok
        rescue => e
          Rails.logger.error("인증코드 발송 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "인증 코드 발송에 실패했습니다." }, status: :internal_server_error
        end
      end

      # 인증 코드 확인
      def verify_code
        # 로그 추가 - 전체 파라미터 상세 기록
        Rails.logger.info("인증코드 확인 파라미터: #{params.inspect}")

        # 방어적 코드 추가: params.dig를 사용하여 안전하게 접근
        phone_number = params.dig(:user, :phone_number)
        code = params.dig(:user, :code)

        # 필수 파라미터 확인
        unless phone_number.present?
          return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
        end

        unless code.present?
          return render json: { error: "인증코드를 입력해 주세요." }, status: :bad_request
        end

        Rails.logger.info("인증코드 확인: #{phone_number}, 입력 코드: #{code}")

        begin
          verification = PhoneVerification.find_by(phone_number: phone_number)

          if verification.nil?
            # 베타 테스트 - 인증 레코드가 없으면 자동 생성
            Rails.logger.info("베타 테스트 - 인증 없이 확인: #{phone_number}에 대한 자동 인증 생성")
            verification = PhoneVerification.create!(
              phone_number: phone_number,
              code: code,
              expires_at: 1.hour.from_now,
              verified: true,
              attempt_count: 0
            )
          else
            # 베타 테스트 - 코드와 상관없이 항상 인증 성공 처리
            verification.mark_as_verified!
            Rails.logger.info("베타 테스트 - 인증 코드 자동 승인: #{phone_number}")
          end

          # 사용자가 이미 존재하는지 확인
          existing_user = User.find_by(phone_number: phone_number)

          render json: {
            message: "인증에 성공했습니다.",
            user_exists: existing_user.present?,
            can_proceed_to_register: !existing_user.present?,
            user: existing_user ? {
              id: existing_user.id,
              nickname: existing_user.nickname
            } : nil,
            verification_status: {
              verified: true,
              verified_at: Time.current,
              phone_number: phone_number
            }
          }, status: :ok

          Rails.logger.info("인증코드 확인 성공: #{phone_number} (베타 테스트 - 자동 인증)")
        rescue => e
          Rails.logger.error("인증코드 확인 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "인증 확인 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # 인증 코드 재전송 (편의성 향상)
      def resend_code
        # 방어적 코드 추가: params.dig를 사용하여 안전하게 접근
        phone_number = params[:phone_number]

        # 필수 파라미터 확인
        unless phone_number.present?
          return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
        end

        # 로그 추가
        Rails.logger.info("인증코드 재전송 요청: #{phone_number}")

        # 전화번호 형식 검증
        unless valid_phone_number?(phone_number)
          Rails.logger.warn("인증코드 재전송 실패: #{phone_number} - 유효하지 않은 전화번호 형식")
          return render json: { error: "유효하지 않은 전화번호 형식입니다." }, status: :bad_request
        end

        begin
          # 기존 인증 정보 찾기
          verification = PhoneVerification.find_by(phone_number: phone_number)

          # 인증 정보가 없으면 새로 생성
          if verification.nil?
            Rails.logger.info("인증코드 재전송: #{phone_number} - 기존 인증 정보 없음, 새로 생성")
            request_code
            return
          end

          # 마지막 전송 시간 확인 (너무 빈번한 요청 방지, 옵션)
          # 예: 1분 이내 재전송 제한
          if verification.updated_at && verification.updated_at > 1.minute.ago
            remaining_seconds = ((verification.updated_at + 1.minute) - Time.current).to_i

            Rails.logger.warn("인증코드 재전송 제한: #{phone_number} - 재전송 대기 시간: #{remaining_seconds}초")
            return render json: {
              error: "잠시 후 다시 시도해주세요.",
              wait_seconds: remaining_seconds
            }, status: :too_many_requests
          end

          # 새 인증 코드 생성
          code = generate_secure_verification_code

          # 인증 정보 업데이트
          verification.assign_attributes(
            code: code,
            expires_at: 10.minutes.from_now,
            verified: false,
            attempt_count: 0
          )
          verification.save!

          # 실제 환경에서는 SMS 전송
          send_sms(phone_number, "인증 코드: #{code}") if Rails.env.production?

          # 응답 - 모든 환경에서 코드 포함 (요청에 따른 임시 변경)
          response_data = {
            message: "인증 코드가 재발송되었습니다.",
            code: code,
            expires_at: verification.expires_at,
            note: "보안 주의: 모든 환경에서 코드가 직접 표시됩니다."
          }

          # 인증 코드 정보를 로그에 항상 기록
          Rails.logger.info("🔐 인증코드 재발송 정보 (관리자 확인용): 전화번호=#{phone_number}, 코드=#{code}, 만료시간=#{verification.expires_at}")

          render json: response_data, status: :ok

          Rails.logger.info("인증코드 재전송 성공: #{phone_number}, 코드: #{code}, 만료시간: #{verification.expires_at}")
        rescue => e
          Rails.logger.error("인증코드 재전송 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "인증 코드 재전송에 실패했습니다." }, status: :internal_server_error
        end
      end

      # 전화번호 존재 여부 확인
      def check_phone
        # 방어적 코드 추가: params를 안전하게 접근
        phone_number = params[:phone_number]

        # 필수 파라미터 확인
        unless phone_number.present?
          return render json: { error: "전화번호를 입력해 주세요." }, status: :bad_request
        end

        # 로그 추가
        Rails.logger.info("전화번호 확인: #{phone_number}")

        begin
          user_exists = User.exists?(phone_number: phone_number)

          render json: {
            exists: user_exists,
            message: user_exists ? "이미 등록된 전화번호입니다." : "사용 가능한 전화번호입니다."
          }, status: :ok

          Rails.logger.info("전화번호 확인 결과: #{phone_number}, 존재 여부: #{user_exists}")
        rescue => e
          Rails.logger.error("전화번호 확인 중 오류: #{e.message}")
          render json: { error: "전화번호 확인 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # 로그아웃 처리
      def logout
        # 세션 토큰 기반 인증 - 서버에서 세션 삭제
        terminate_session

        render json: { message: "로그아웃 되었습니다." }, status: :ok
      end

      # 비밀번호 재설정 기능
      def reset_password
        # 요청 파라미터 추출
        phone_number = params.dig(:user, :phone_number)
        new_password = params.dig(:user, :password)

        # 파라미터 유효성 검사
        unless phone_number.present? && new_password.present?
          render json: { error: "전화번호와 새 비밀번호가 필요합니다." }, status: :bad_request
          return
        end

        # 전화번호로 사용자 찾기
        user = User.find_by(phone_number: phone_number)

        # 사용자가 존재하는지 확인
        unless user
          render json: { error: "해당 전화번호로 가입된 사용자가 없습니다." }, status: :not_found
          return
        end

        # 인증 코드 검증 여부 확인
        verification = PhoneVerification.find_by(phone_number: phone_number, verified: true)

        # 인증되지 않은 전화번호인 경우
        unless verification
          render json: { error: "전화번호 인증이 필요합니다." }, status: :unauthorized
          return
        end

        # 비밀번호 유효성 검사 (최소 6자 이상)
        if new_password.length < 6
          render json: { error: "비밀번호는 최소 6자 이상이어야 합니다." }, status: :bad_request
          return
        end

        # 비밀번호 변경 시도
        begin
          # 비밀번호 변경
          user.password = new_password

          if user.save
            # 비밀번호 변경 성공 로그 기록
            Rails.logger.info("[INFO] 비밀번호 변경 성공: 사용자=#{user.id}, 전화번호=#{phone_number.gsub(/\d(?=\d{4})/, '*')}")

            # 인증 코드 사용 후 삭제
            verification.destroy

            render json: {
              message: "비밀번호가 성공적으로 변경되었습니다.",
              success: true
            }, status: :ok
          else
            # 저장 실패 시 오류 메시지 반환
            render json: { error: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
          end
        rescue => e
          # 예외 발생 시 오류 처리
          Rails.logger.error("[ERROR] 비밀번호 변경 오류: #{e.message}")
          render json: { error: "비밀번호 변경 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      private

      # 허용된 파라미터 목록
      def user_params
        # 중첩된 user 객체에서 허용된 파라미터만 추출
        params.require(:user).permit(:phone_number, :password, :nickname, :gender)
      end

      # 한국 전화번호 유효성 검사
      def valid_phone_number?(phone_number)
        # 한국 전화번호 형식 검증 (010으로 시작하는 10-11자리 숫자)
        phone_number =~ /^01[0-9]{8,9}$/
      end

      # 더 안전한 인증 코드 생성 (6자리 숫자)
      def generate_secure_verification_code
        # 모든 환경에서 랜덤 코드 생성
        SecureRandom.random_number(100000..999999).to_s
      end

      # 기존 인증 코드 생성 메서드는 유지 (호환성)
      def generate_verification_code
        generate_secure_verification_code
      end

      # SMS 전송 메소드 (실제 구현은 서비스에 따라 다름)
      def send_sms(phone_number, message)
        # 실제 SMS 서비스 연동 코드 구현
        # 예: TwilioClient.new.send_sms(phone_number, message)
        Rails.logger.info("SMS 전송 (가상): #{phone_number}, 메시지: #{message}")
      end
    end
  end
end
