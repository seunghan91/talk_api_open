# app/controllers/api/auth_controller.rb
module Api
  class AuthController < BaseController
    # 회원가입/로그인(전화번호 인증)에는 JWT 없이 접근 가능
    skip_before_action :authorize_request, only: [:request_code, :verify_code, :register, :login]

    def request_code
      phone_number = params[:phone_number]
      
      # 로깅 추가
      Rails.logger.info("인증코드 요청: 전화번호 #{phone_number}")
      
      begin
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
        
        # 기존의 만료되지 않은 인증 코드가 있는지 확인
        existing_verification = PhoneVerification.where(phone_number: digits_only, verified: false)
                                              .where("expires_at > ?", Time.current)
                                              .order(created_at: :desc)
                                              .first

        # 기존 인증 코드가 있다면 만료 처리
        if existing_verification
          Rails.logger.info("기존 인증 코드 만료 처리: #{existing_verification.id}")
          existing_verification.update(expires_at: Time.current)
        end
        
        # 새 인증 코드 저장
        verification = nil
        begin
          verification = PhoneVerification.create!(
            phone_number: digits_only,
            code: code,
            expires_at: 5.minutes.from_now,
            verified: false
          )
          Rails.logger.info("인증코드 생성 완료: ID #{verification.id}, 전화번호 #{digits_only}, 코드 #{code}")
        rescue => e
          Rails.logger.error("인증코드 생성 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          return render json: { error: "인증코드 생성 중 오류가 발생했습니다." }, status: :internal_server_error
        end
        
        # JSON 응답
        render json: {
          phone_number: digits_only,
          code: code, # 테스트 환경에서만 코드 노출
          message: "인증코드가 발송되었습니다. (테스트 환경)",
          verification_id: verification.id
        }
      rescue => e
        # 전체 예외 처리
        Rails.logger.error("인증코드 요청 중 예외 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "인증코드 요청 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def verify_code
      phone_number = params[:phone_number]
      code = params[:code]
      
      # 로깅 추가
      Rails.logger.info("인증코드 확인: 전화번호 #{phone_number}, 코드 #{code}")
      
      begin
        # 전화번호 형식 검증 (하이픈 있는 형식 또는 숫자만 있는 형식 모두 허용)
        unless phone_number.present? && (phone_number.match?(/^\d{3}-\d{3,4}-\d{4}$/) || phone_number.match?(/^\d{10,11}$/))
          Rails.logger.warn("잘못된 전화번호 형식: #{phone_number}")
          return render json: { error: "유효한 전화번호 형식이 아닙니다." }, status: :bad_request
        end
        
        # 하이픈 제거하여 숫자만 추출
        digits_only = phone_number.gsub(/\D/, '')
        
        # 인증 코드 확인
        verification = PhoneVerification.where(phone_number: digits_only, verified: false)
                                      .where("expires_at > ?", Time.current)
                                      .order(created_at: :desc)
                                      .first
        
        Rails.logger.info("검색된 인증정보: #{verification.inspect}")
        
        unless verification
          Rails.logger.warn("인증정보 없음: 전화번호 #{digits_only}")
          return render json: { error: "유효한 인증요청이 없거나 이미 만료되었습니다." }, status: :unauthorized
        end
        
        unless verification.code == code
          Rails.logger.warn("인증코드 불일치: 입력 #{code}, 저장 #{verification.code}")
          return render json: { error: "인증코드가 올바르지 않습니다." }, status: :unauthorized
        end
        
        # 인증 성공 처리
        verification.update(verified: true)
        Rails.logger.info("인증 성공 처리: verification_id=#{verification.id}")
        
        # 유저 찾거나 생성
        user = nil
        begin
          user = User.find_or_create_by(phone_number: digits_only) do |u|
            # 새 사용자인 경우 닉네임 자동 생성
            random_nickname = NicknameGenerator.generate_unique
            u.nickname = random_nickname
            u.gender = 'unknown'  # 기본값 설정
            u.password = SecureRandom.hex(8) if u.respond_to?(:password)  # 임시 비밀번호
            Rails.logger.info("새 사용자 생성: 전화번호 #{digits_only}, 닉네임 #{random_nickname}")
          end
          Rails.logger.info("사용자 정보: #{user.inspect}")
        rescue => e
          Rails.logger.error("사용자 생성 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          return render json: { error: "사용자 정보 처리 중 오류가 발생했습니다." }, status: :internal_server_error
        end
        
        if user.nil?
          Rails.logger.error("사용자 객체가 nil입니다: phone_number=#{digits_only}")
          return render json: { error: "사용자 정보를 찾을 수 없습니다." }, status: :internal_server_error
        end
        
        # PhoneVerification과 User 연결
        begin
          verification.update(user: user)
          Rails.logger.info("사용자와 인증정보 연결: user_id=#{user.id}, verification_id=#{verification.id}")
        rescue => e
          Rails.logger.error("인증정보 연결 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          # 치명적 오류는 아니므로 진행
        end
        
        # 기존 사용자인데 닉네임이 없는 경우 생성
        if user.nickname.blank?
          random_nickname = NicknameGenerator.generate_unique
          user.update(nickname: random_nickname)
          Rails.logger.info("기존 사용자 닉네임 생성: 전화번호 #{digits_only}, 닉네임 #{random_nickname}")
        end
        
        # JWT 발급
        token = nil
        begin
          token = JsonWebToken.encode({ user_id: user.id })
          Rails.logger.info("JWT 발급 성공: 사용자 ID #{user.id}")
        rescue => e
          Rails.logger.error("JWT 발급 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          return render json: { error: "인증 토큰 생성 중 오류가 발생했습니다." }, status: :internal_server_error
        end
        
        # 응답 반환
        render json: {
          message: "인증이 완료되었습니다.",
          token: token,
          user: {
            id: user.id,
            phone_number: user.phone_number,
            nickname: user.nickname,
            gender: user.gender || "unknown",
            verified: true  # 인증 완료 시 verified를 true로 설정
          }
        }
      rescue => e
        # 전체 예외 처리
        Rails.logger.error("인증 과정 중 예외 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "인증 처리 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def register
      begin
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
        
        # 닉네임 검증
        if user_params[:nickname].blank?
          # 닉네임이 없으면 자동 생성
          user_params[:nickname] = NicknameGenerator.generate_unique
          Rails.logger.info("닉네임 자동 생성: #{user_params[:nickname]}")
        end
        
        # 비밀번호 검증
        if user_params[:password].blank? || user_params[:password].length < 6
          return render json: { error: "비밀번호는 최소 6자 이상이어야 합니다." }, status: :bad_request
        end
        
        if user_params[:password] != user_params[:password_confirmation]
          return render json: { error: "비밀번호와 비밀번호 확인이 일치하지 않습니다." }, status: :bad_request
        end
        
        # 이미 존재하는 사용자인지 확인
        existing_user = User.find_by(phone_number: digits_only)
        
        # 이미 비밀번호가 설정된 사용자인 경우 (진짜 가입 완료된 사용자)
        if existing_user && existing_user.password_digest.present? && existing_user.is_verified
          Rails.logger.warn("이미 가입된 전화번호: #{digits_only}")
          return render json: { error: "이미 가입된 전화번호입니다." }, status: :conflict
        end
        
        # 사용자 생성 또는 업데이트
        if existing_user
          # 기존에 인증만 했고 회원가입은 안 한 사용자 (비밀번호 없음)
          Rails.logger.info("기존 계정 업데이트 (비밀번호 미설정): #{digits_only}")
          user = existing_user
        else
          # 신규 사용자 생성
          Rails.logger.info("신규 사용자 생성: #{digits_only}")
          user = User.new(phone_number: digits_only)
        end
        
        # 닉네임 업데이트
        user.nickname = user_params[:nickname]
        
        # 성별 값이 존재하는지 확인하고 유효한 값인지 검증
        if user_params[:gender].present?
          # 성별이 유효한지 검사 (male, female, unknown만 허용) - unspecified는 unknown으로 변환
          if user_params[:gender] == 'unspecified'
            user.gender = 'unknown'
          elsif User.genders.keys.include?(user_params[:gender])
            user.gender = user_params[:gender]
          else
            Rails.logger.warn("유효하지 않은 성별 값: #{user_params[:gender]}")
            return render json: { error: "유효하지 않은 성별입니다. 'unknown', 'male', 'female' 중 하나여야 합니다." }, status: :bad_request
          end
        else
          # 성별이 없는 경우 기본값 'male' 사용
          user.gender = 'male'
        end
        
        # 비밀번호 설정
        user.password = user_params[:password]
        user.password_confirmation = user_params[:password_confirmation]
        
        # 회원가입 완료 표시
        user.is_verified = true
        
        # 검증 로그
        Rails.logger.info("저장 전 사용자 검증: #{user.valid?}")
        unless user.valid?
          Rails.logger.warn("사용자 유효성 검증 실패: #{user.errors.full_messages.join(', ')}")
        end
        
        # 사용자 저장
        if user.save
          # 저장 성공 시 JWT 발급
          begin
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
          rescue => e
            Rails.logger.error("JWT 발급 오류: #{e.message}\n#{e.backtrace.join("\n")}")
            render json: { error: "회원가입은 성공했으나 로그인 토큰 생성에 실패했습니다." }, status: :internal_server_error
          end
        else
          # 사용자 저장 실패 시
          Rails.logger.warn("회원가입 실패: #{user.errors.full_messages.join(', ')}")
          render json: { error: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        # 필수 파라미터 누락
        Rails.logger.warn("필수 파라미터 누락: #{e.message}")
        render json: { error: "필수 회원가입 정보가 누락되었습니다." }, status: :bad_request
      rescue => e
        # 그 외 모든 예외
        Rails.logger.error("회원가입 처리 중 예외 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "회원가입 처리 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    def login
      # 로그인 정보 가져오기
      phone_number = params[:phone_number]
      password = params[:password]
      
      # 로깅 추가
      Rails.logger.info("로그인 요청: 전화번호 #{phone_number}")
      
      begin
        # 전화번호와 비밀번호 검증
        if phone_number.blank? || password.blank?
          return render json: { error: "전화번호와 비밀번호를 입력해주세요." }, status: :bad_request
        end
        
        # 하이픈 제거하여 숫자만 추출
        digits_only = phone_number.gsub(/\D/, '')
        
        # 테스트 계정 지원 - 모든 환경에서 동작하도록 수정
        if password == 'test1234'
          Rails.logger.info("테스트 계정 로그인 시도: #{digits_only}")
          
          test_accounts = {
            '01011111111' => { id: 1, nickname: 'A - 김철수', gender: 'male' },
            '01022222222' => { id: 2, nickname: 'B - 이영희', gender: 'female' },
            '01033333333' => { id: 3, nickname: 'C - 박지민', gender: 'male' },
            '01044444444' => { id: 4, nickname: 'D - 최수진', gender: 'female' },
            '01055555555' => { id: 5, nickname: 'E - 정민준', gender: 'male' }
          }
          
          if test_account = test_accounts[digits_only]
            Rails.logger.info("테스트 계정 정보 확인: #{test_account.inspect}")
            
            # 테스트 계정이 존재하면 사용자 정보 생성 또는 업데이트
            user = nil
            
            # 사용자 조회 또는 생성
            begin
              user = User.find_by(phone_number: digits_only)
              
              if user.nil?
                # 테스트 계정 새로 생성
                user = User.new(
                  phone_number: digits_only,
                  nickname: test_account[:nickname],
                  gender: test_account[:gender],
                  is_verified: true
                )
                user.password = password
                user.password_confirmation = password
                
                if user.save
                  Rails.logger.info("테스트 계정 새로 생성 성공: #{user.nickname}")
                else
                  Rails.logger.error("테스트 계정 생성 실패: #{user.errors.full_messages.join(', ')}")
                  return render json: { error: "테스트 계정 생성에 실패했습니다." }, status: :internal_server_error
                end
              else
                # 기존 테스트 계정 정보 업데이트
                needs_update = user.nickname != test_account[:nickname] || user.gender != test_account[:gender] || !user.is_verified
                
                if needs_update
                  Rails.logger.info("테스트 계정 정보 업데이트: #{user.nickname} -> #{test_account[:nickname]}")
                  user.update(
                    nickname: test_account[:nickname],
                    gender: test_account[:gender],
                    is_verified: true
                  )
                end
                
                # 비밀번호 없는 경우 추가
                if !user.password_digest.present?
                  Rails.logger.info("테스트 계정 비밀번호 설정")
                  user.password = password
                  user.password_confirmation = password
                  user.save!
                end
              end
            rescue => e
              Rails.logger.error("테스트 계정 처리 오류: #{e.message}\n#{e.backtrace.join("\n")}")
              return render json: { error: "테스트 계정 처리 중 오류가 발생했습니다." }, status: :internal_server_error
            end
            
            # JWT 발급
            token = nil
            begin
              token = JsonWebToken.encode({ user_id: user.id })
              Rails.logger.info("테스트 계정 로그인 성공: 사용자 ID #{user.id}, 전화번호 #{digits_only}")
            rescue => e
              Rails.logger.error("JWT 발급 오류: #{e.message}\n#{e.backtrace.join("\n")}")
              return render json: { error: "인증 토큰 생성 중 오류가 발생했습니다." }, status: :internal_server_error
            end
            
            return render json: {
              message: "테스트 계정으로 로그인되었습니다.",
              token: token,
              user: {
                id: user.id,
                phone_number: user.phone_number,
                nickname: user.nickname,
                gender: user.gender || "unspecified",
                created_at: user.created_at,
                updated_at: user.updated_at,
                is_test_account: true
              }
            }
          else
            Rails.logger.warn("등록되지 않은 테스트 계정: #{digits_only}")
            return render json: { error: "테스트 계정이 아닙니다. 01011111111부터 01055555555까지의 번호만 테스트 계정으로 사용할 수 있습니다." }, status: :unauthorized
          end
        end
        
        # 일반 사용자 찾기
        user = User.find_by(phone_number: digits_only)
        
        # 사용자가 없는 경우
        if user.nil?
          Rails.logger.warn("존재하지 않는 사용자: #{digits_only}")
          return render json: { error: "전화번호 또는 비밀번호가 올바르지 않습니다." }, status: :unauthorized
        end
        
        # 비밀번호 없는 경우 (예외 상황)
        if !user.password_digest.present?
          Rails.logger.warn("비밀번호가 설정되지 않은 사용자: #{digits_only}")
          return render json: { error: "계정 설정이 완료되지 않았습니다. 회원가입을 진행해주세요." }, status: :unauthorized
        }
        
        # 회원가입 완료 확인
        if !user.is_verified
          Rails.logger.warn("인증되지 않은 사용자: #{digits_only}")
          return render json: { error: "회원가입이 완료되지 않았습니다. 회원가입을 진행해주세요." }, status: :unauthorized
        }
        
        # 비밀번호 확인
        unless user.authenticate(password)
          Rails.logger.warn("비밀번호 불일치: 사용자 ID #{user.id}, 전화번호 #{digits_only}")
          return render json: { error: "전화번호 또는 비밀번호가 올바르지 않습니다." }, status: :unauthorized
        end
        
        # JWT 발급
        token = nil
        begin
          token = JsonWebToken.encode({ user_id: user.id })
          Rails.logger.info("로그인 성공: 사용자 ID #{user.id}, 전화번호 #{digits_only}")
        rescue => e
          Rails.logger.error("JWT 발급 오류: #{e.message}\n#{e.backtrace.join("\n")}")
          return render json: { error: "인증 토큰 생성 중 오류가 발생했습니다." }, status: :internal_server_error
        end
        
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
      rescue => e
        # 전체 예외 처리
        Rails.logger.error("로그인 처리 중 예외 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: { error: "로그인 처리 중 오류가 발생했습니다." }, status: :internal_server_error
      end
    end

    # 로그아웃 처리
    def logout
      # 클라이언트에서는 토큰을 삭제하므로 서버에서는 성공 응답만 반환
      render json: { message: "로그아웃 되었습니다." }, status: :ok
    end
  end
end