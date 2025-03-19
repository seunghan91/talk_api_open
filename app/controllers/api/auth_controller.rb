# app/controllers/api/auth_controller.rb
module Api
  class AuthController < BaseController
    # 회원가입/로그인(전화번호 인증)에는 JWT 없이 접근 가능
    skip_before_action :authorize_request, only: [:request_code, :verify_code, :register, :login]

    def request_code
      phone_number = params[:phone_number]
      
      # 로깅 추가
      Rails.logger.info("인증코드 요청: 전화번호 #{phone_number}")
      
      # 전화번호 형식 검증 (하이픈 있는 형식 또는 숫자만 있는 형식 모두 허용)
      unless phone_number.present? && (phone_number.match?(/^\d{3}-\d{3,4}-\d{4}$/) || phone_number.match?(/^\d{10,11}$/))
        Rails.logger.warn("잘못된 전화번호 형식: #{phone_number}")
        return render json: { error: "유효한 전화번호 형식이 아닙니다. (예: 010-1234-5678 또는 01012345678)" }, status: :bad_request
      end
      
      # 하이픈 제거하여 숫자만 추출
      digits_only = phone_number.gsub(/\D/, '')
      
      # 전화번호 인증코드 생성/발송 로직
      code = rand(100000..999999).to_s
      
      # 실제 서비스에서는 SMS 발송 로직 추가
      # SmsService.send_verification(digits_only, code)
      
      # 코드 저장 (실제로는 Redis나 DB에 저장)
      # VerificationCode.create(phone_number: digits_only, code: code, expires_at: 5.minutes.from_now)
      
      # 로깅
      Rails.logger.info("인증코드 생성 완료: 전화번호 #{digits_only}, 코드 #{code}")
      
      # 예시로 JSON 응답
      render json: {
        phone_number: digits_only,
        code: code,
        message: "인증코드가 발송되었습니다. (테스트 환경)"
      }
    end

    def verify_code
      phone_number = params[:phone_number]
      code = params[:code]
      
      # 로깅 추가
      Rails.logger.info("인증코드 확인: 전화번호 #{phone_number}, 코드 #{code}")
      
      # 전화번호 형식 검증 (하이픈 있는 형식 또는 숫자만 있는 형식 모두 허용)
      unless phone_number.present? && (phone_number.match?(/^\d{3}-\d{3,4}-\d{4}$/) || phone_number.match?(/^\d{10,11}$/))
        Rails.logger.warn("잘못된 전화번호 형식: #{phone_number}")
        return render json: { error: "유효한 전화번호 형식이 아닙니다." }, status: :bad_request
      end
      
      # 하이픈 제거하여 숫자만 추출
      digits_only = phone_number.gsub(/\D/, '')
      
      # 코드 검증 (실제로는 Redis나 DB에서 확인)
      # verification = VerificationCode.find_by(phone_number: digits_only)
      # if verification.nil? || verification.code != code || verification.expires_at < Time.current
      #   return render json: { error: "유효하지 않은 인증코드입니다." }, status: :unauthorized
      # end
      
      # 실제 서비스에서는 DB/Redis에서 코드 검증
      # 여기서는 테스트용으로 간단 처리
      # 유저 찾거나 생성
      user = User.find_or_create_by(phone_number: digits_only) do |u|
        # 새 사용자인 경우 닉네임 자동 생성
        random_nickname = NicknameGenerator.generate_unique
        u.nickname = random_nickname
        Rails.logger.info("새 사용자 생성: 전화번호 #{digits_only}, 닉네임 #{random_nickname}")
      end
      
      # 기존 사용자인데 닉네임이 없는 경우 생성
      if user.nickname.blank?
        random_nickname = NicknameGenerator.generate_unique
        user.update(nickname: random_nickname)
        Rails.logger.info("기존 사용자 닉네임 생성: 전화번호 #{digits_only}, 닉네임 #{random_nickname}")
      end
      
      # JWT 발급
      token = JsonWebToken.encode({ user_id: user.id })
      Rails.logger.info("인증 성공: 사용자 ID #{user.id}, 전화번호 #{digits_only}")
      
      render json: {
        message: "인증이 완료되었습니다.",
        token: token,
        user: {
          id: user.id,
          phone_number: user.phone_number,
          nickname: user.nickname,
          gender: user.gender || "unknown",
          verified: user.verified || false
        }
      }
    end

    def register
      # 사용자 정보 가져오기
      user_params = params.require(:user).permit(
        :phone_number, :nickname, :gender, :password, :password_confirmation
      )
      
      # 로깅 추가
      Rails.logger.info("회원가입 요청: 전화번호 #{user_params[:phone_number]}")
      
      # 전화번호 형식 검증 (하이픈 있는 형식 또는 숫자만 있는 형식 모두 허용)
      unless user_params[:phone_number].present? && (user_params[:phone_number].match?(/^\d{3}-\d{3,4}-\d{4}$/) || user_params[:phone_number].match?(/^\d{10,11}$/))
        Rails.logger.warn("잘못된 전화번호 형식: #{user_params[:phone_number]}")
        return render json: { error: "유효한 전화번호 형식이 아닙니다." }, status: :bad_request
      end
      
      # 하이픈 제거하여 숫자만 추출
      digits_only = user_params[:phone_number].gsub(/\D/, '')
      user_params[:phone_number] = digits_only
      
      # 비밀번호 검증
      if user_params[:password].blank? || user_params[:password].length < 6
        return render json: { error: "비밀번호는 최소 6자 이상이어야 합니다." }, status: :bad_request
      end
      
      if user_params[:password] != user_params[:password_confirmation]
        return render json: { error: "비밀번호와 비밀번호 확인이 일치하지 않습니다." }, status: :bad_request
      end
      
      # 이미 존재하는 사용자인지 확인
      existing_user = User.find_by(phone_number: digits_only)
      if existing_user && existing_user.password_digest.present?
        return render json: { error: "이미 가입된 전화번호입니다." }, status: :conflict
      end
      
      # 사용자 생성 또는 업데이트
      user = existing_user || User.new(phone_number: digits_only)
      user.nickname = user_params[:nickname] if user_params[:nickname].present?
      user.gender = user_params[:gender].present? ? user_params[:gender] : 'male'
      user.password = user_params[:password]
      user.password_confirmation = user_params[:password_confirmation]
      
      if user.save
        # JWT 발급
        token = JsonWebToken.encode({ user_id: user.id })
        Rails.logger.info("회원가입 성공: 사용자 ID #{user.id}, 전화번호 #{digits_only}")
        
        render json: {
          message: "회원가입이 완료되었습니다.",
          token: token,
          user: {
            id: user.id,
            phone_number: user.phone_number,
            nickname: user.nickname,
            gender: user.gender || "unspecified",
            created_at: user.created_at,
            updated_at: user.updated_at
          }
        }, status: :created
      else
        Rails.logger.warn("회원가입 실패: #{user.errors.full_messages.join(', ')}")
        render json: { error: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end

    def login
      # 로그인 정보 가져오기
      phone_number = params[:phone_number]
      password = params[:password]
      
      # 로깅 추가
      Rails.logger.info("로그인 요청: 전화번호 #{phone_number}")
      
      # 전화번호와 비밀번호 검증
      if phone_number.blank? || password.blank?
        return render json: { error: "전화번호와 비밀번호를 입력해주세요." }, status: :bad_request
      end
      
      # 하이픈 제거하여 숫자만 추출
      digits_only = phone_number.gsub(/\D/, '')
      
      # 테스트 계정 지원 - 개발 환경에서만 동작
      if Rails.env.development? && password == 'test1234'
        test_accounts = {
          '01011111111' => { id: 1, nickname: 'A - 김철수', gender: 'male' },
          '01022222222' => { id: 2, nickname: 'B - 이영희', gender: 'female' },
          '01033333333' => { id: 3, nickname: 'C - 박지민', gender: 'male' },
          '01044444444' => { id: 4, nickname: 'D - 최수진', gender: 'female' },
          '01055555555' => { id: 5, nickname: 'E - 정민준', gender: 'male' }
        }
        
        if test_account = test_accounts[digits_only]
          # 테스트 계정이 존재하면 사용자 정보 생성 또는 업데이트
          user = User.find_or_create_by(phone_number: digits_only) do |u|
            u.nickname = test_account[:nickname]
            u.gender = test_account[:gender]
            u.password = password
            u.password_confirmation = password
          end
          
          # 기존 사용자의 정보 업데이트
          unless user.nickname == test_account[:nickname] && user.gender == test_account[:gender]
            user.update(nickname: test_account[:nickname], gender: test_account[:gender])
          end
          
          # JWT 발급
          token = JsonWebToken.encode({ user_id: user.id })
          Rails.logger.info("테스트 계정 로그인 성공: 사용자 ID #{user.id}, 전화번호 #{digits_only}")
          
          return render json: {
            message: "로그인에 성공했습니다.",
            token: token,
            user: {
              id: user.id,
              phone_number: user.phone_number,
              nickname: user.nickname,
              gender: user.gender || "unspecified",
              created_at: user.created_at,
              updated_at: user.updated_at
            }
          }
        end
      end
      
      # 일반 사용자 찾기
      user = User.find_by(phone_number: digits_only)
      
      # 사용자가 없거나 비밀번호가 일치하지 않는 경우
      if user.nil? || !user.authenticate(password)
        Rails.logger.warn("로그인 실패: 전화번호 #{digits_only}")
        return render json: { error: "전화번호 또는 비밀번호가 올바르지 않습니다." }, status: :unauthorized
      end
      
      # JWT 발급
      token = JsonWebToken.encode({ user_id: user.id })
      Rails.logger.info("로그인 성공: 사용자 ID #{user.id}, 전화번호 #{digits_only}")
      
      render json: {
        message: "로그인에 성공했습니다.",
        token: token,
        user: {
          id: user.id,
          phone_number: user.phone_number,
          nickname: user.nickname,
          gender: user.gender || "unspecified",
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      }
    end

    # 로그아웃 처리
    def logout
      # 클라이언트에서는 토큰을 삭제하므로 서버에서는 성공 응답만 반환
      render json: { message: "로그아웃 되었습니다." }, status: :ok
    end
  end
end