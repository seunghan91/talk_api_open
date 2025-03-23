# app/controllers/api/v1/auth_controller.rb
module Api
  module V1
    class AuthController < Api::V1::BaseController
      # 인증이 필요한 액션에서만 authorize_request 실행
      before_action :authorize_request, except: [ :login, :register, :request_code, :verify_code, :check_phone, :resend_code ]

      # 로그인 처리
      def login
        # 로그 추가
        Rails.logger.info("로그인 시도: #{params[:phone_number]}")

        begin
          # 전화번호로 사용자 찾기
          @user = User.find_by(phone_number: params[:phone_number])

          # 사용자가 없거나 비밀번호가 일치하지 않으면
          unless @user && @user.authenticate(params[:password])
            Rails.logger.warn("로그인 실패: #{params[:phone_number]} - 사용자가 없거나 비밀번호가 일치하지 않음")
            return render json: { error: "전화번호 또는 비밀번호가 올바르지 않습니다." }, status: :unauthorized
          end

          # JWT 토큰 생성
          token = AuthToken.encode(user_id: @user.id)

          # 로그인 정보 저장 (최근 로그인 시간 등)
          @user.update(last_login_at: Time.current)

          # 성공 응답
          render json: {
            token: token,
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
        # 로그 추가
        phone_number = params[:phone_number]
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

          # 인증 코드 확인 - 임시로 우회
          verification = PhoneVerification.find_by(phone_number: phone_number)

          # 인증 레코드가 있는 경우 로깅만 하고 진행 (인증 검증 로직 임시 제거)
          if verification.nil?
            # 인증 레코드가 없는 경우도 로깅만 하고 진행
            Rails.logger.warn("회원가입 임시 허용: #{phone_number} - 인증 기록 없음 (인증 검증 임시 비활성화)")
          else
            # 인증 상태 로깅
            verified_status = verification.verified ? "인증됨" : "미인증" 
            Rails.logger.warn("회원가입 임시 허용: #{phone_number} - 인증 상태: #{verified_status} (인증 검증 임시 비활성화)")
          end

          # 임시 우회 조치 로그
          Rails.logger.info("⚠️ 주의: 인증 단계 임시 우회 중 - 향후 SMS 인증 연동 후 검증 로직 복원 필요")

          # *** 인증 검증 로직 주석 처리 - 임시 조치 ***
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
          
          # *** 인증 시간 확인 로직 주석 처리 - 임시 조치 ***
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

          # 사용자 생성
          @user = User.new(user_params)
          @user.last_login_at = Time.current

          if @user.save
            # JWT 토큰 생성
            token = AuthToken.encode(user_id: @user.id)

            # 지갑 생성
            wallet = Wallet.create!(user: @user, balance: 0)

            # 성공 응답
            render json: {
              token: token,
              user: {
                id: @user.id,
                nickname: @user.nickname,
                phone_number: @user.phone_number,
                created_at: @user.created_at
              },
              message: "회원가입에 성공했습니다."
            }, status: :created

            Rails.logger.info("회원가입 성공: 사용자 ID #{@user.id}")
          else
            Rails.logger.warn("회원가입 실패: #{params[:phone_number]} - #{@user.errors.full_messages.join(', ')}")
            render json: { error: @user.errors.full_messages.join(", ") }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("회원가입 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "회원가입 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # 인증 코드 요청
      def request_code
        phone_number = params[:phone_number]

        # 로그 추가
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

          # 응답 데이터 구성
          response_data = {
            message: "인증 코드가 발송되었습니다.",
            expires_at: verification.expires_at,
            dev_mode: !Rails.env.production?
          }

          # 개발 또는 스테이징 환경에서만 코드 제공
          unless Rails.env.production?
            response_data[:code] = code
            response_data[:note] = "개발/스테이징 환경에서만 코드가 노출됩니다."
          end

          # 추가 정보 (테스트 편의성)
          if Rails.env.development? || Rails.env.test?
            response_data[:test_info] = {
              code_valid_until: verification.expires_at.strftime("%Y-%m-%d %H:%M:%S"),
              remaining_time: ((verification.expires_at - Time.current) / 60).round(1),
              phone_number: phone_number
            }
          end

          # 인증 코드를 로그에 기록 (디버깅용, 프로덕션에서도 로그에는 기록)
          Rails.logger.info("🔑 인증코드 발급: 전화번호=#{phone_number}, 코드=#{code}, 만료=#{verification.expires_at.strftime('%H:%M:%S')}")

          render json: response_data, status: :ok
        rescue => e
          Rails.logger.error("인증코드 발송 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "인증 코드 발송에 실패했습니다." }, status: :internal_server_error
        end
      end

      # 인증 코드 확인
      def verify_code
        phone_number = params[:phone_number]
        code = params[:code]

        # 로그 추가
        Rails.logger.info("인증코드 확인: #{phone_number}, 입력 코드: #{code}")

        begin
          verification = PhoneVerification.find_by(phone_number: phone_number)

          if verification.nil?
            Rails.logger.warn("인증코드 확인 실패: #{phone_number} - 해당 전화번호의 인증 정보가 없음")
            return render json: { error: "인증 요청을 먼저 진행해주세요." }, status: :not_found
          end

          # 인증 데이터 로깅
          Rails.logger.info("인증코드 정보: 전화번호=#{phone_number}, 저장코드=#{verification.code}, 만료시간=#{verification.expires_at}, 현재시간=#{Time.current}, 시도횟수=#{verification.attempt_count}")

          # 만료 확인
          if verification.expires_at < Time.current
            Rails.logger.warn("인증코드 확인 실패: #{phone_number} - 만료된 인증 코드. 만료시간: #{verification.expires_at}, 현재시간: #{Time.current}")
            return render json: { 
              error: "인증 코드가 만료되었습니다. 다시 요청해주세요.",
              expired: true,
              can_resend: true
            }, status: :bad_request
          end

          # 시도 횟수 초과 확인 (최대 5회)
          if verification.attempts_exceeded?
            Rails.logger.warn("인증코드 확인 실패: #{phone_number} - 시도 횟수 초과 (#{verification.attempt_count}/#{PhoneVerification::MAX_ATTEMPTS})")
            return render json: { 
              error: "인증 시도 횟수를 초과했습니다. 새로운 인증 코드를 요청해주세요.",
              verification_status: {
                verified: false,
                attempt_count: verification.attempt_count,
                max_attempts: PhoneVerification::MAX_ATTEMPTS,
                can_resend: true
              }
            }, status: :too_many_requests
          end

          # 시도 횟수 증가
          verification.increment_attempt_count!
          
          # 코드 확인 - 공백 제거 후 비교
          if verification.code.to_s.strip == code.to_s.strip
            # 인증 성공 처리 - 시도 횟수 초기화
            verification.mark_as_verified!

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

            Rails.logger.info("인증코드 확인 성공: #{phone_number}")
          else
            # 실패 시 시도 횟수 증가
            verification.increment_attempt!
            
            # 남은 시도 횟수 계산
            remaining_attempts = verification.remaining_attempts

            Rails.logger.warn("인증코드 확인 실패: #{phone_number} - 잘못된 인증 코드, 입력: '#{code}', 저장: '#{verification.code}', 남은 시도: #{remaining_attempts}")

            render json: {
              error: "인증 코드가 일치하지 않습니다.",
              verification_status: {
                verified: false,
                attempt_count: verification.attempt_count,
                remaining_attempts: remaining_attempts,
                can_resend: remaining_attempts <= 2, # 남은 시도 횟수가 2회 이하면 재전송 권장
                expires_at: verification.expires_at,
                phone_number: phone_number
              }
            }, status: :bad_request
          end
        rescue => e
          Rails.logger.error("인증코드 확인 중 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "인증 확인 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # 인증 코드 재전송 (편의성 향상)
      def resend_code
        phone_number = params[:phone_number]

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

          # 응답 - 개발 및 스테이징 환경에서는 코드 포함, 프로덕션에서는 제외
          response_data = {
            message: "인증 코드가 재발송되었습니다.",
            expires_at: verification.expires_at,
            development_mode: !Rails.env.production?
          }

          # 개발 또는 스테이징 환경에서는 코드 반환 (테스트 용이성)
          unless Rails.env.production?
            response_data[:code] = code
            response_data[:note] = "개발/스테이징 환경에서만 코드가 노출됩니다."
          end

          # 인증 코드 정보를 로그에 항상 기록 (중요: 프로덕션 환경에서도)
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
        phone_number = params[:phone_number]

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
        # JWT는 서버에 저장되지 않으므로, 클라이언트에서 토큰 삭제하는 것이 중요
        # 하지만 선택적으로 블랙리스트 등을 관리할 수 있음

        # 로그 추가
        Rails.logger.info("로그아웃: 사용자 ID #{current_user.id}")

        render json: { message: "로그아웃되었습니다." }, status: :ok
      end

      private

      # 허용된 파라미터 목록
      def user_params
        params.permit(:phone_number, :password, :nickname, :gender)
      end

      # 한국 전화번호 유효성 검사
      def valid_phone_number?(phone_number)
        # 한국 전화번호 형식 검증 (010으로 시작하는 10-11자리 숫자)
        phone_number =~ /^01[0-9]{8,9}$/
      end

      # 더 안전한 인증 코드 생성 (6자리 숫자)
      def generate_secure_verification_code
        # 개발 환경에서는 고정 코드 사용 (테스트 편의성)
        return "123456" if Rails.env.development?
        
        # 프로덕션 환경에서는 SecureRandom 사용하여 중복 가능성이 낮은 코드 생성
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
