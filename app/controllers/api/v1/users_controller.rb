module Api
  module V1
    class UsersController < Api::V1::BaseController
      before_action :authorize_request
      before_action :set_user, only: [ :show, :update, :destroy ]

      # GET /api/v1/users/profile
      #
      # @swagger
      # /api/v1/users/profile:
      #   get:
      #     summary: 현재 로그인한 사용자 프로필 정보 조회
      #     tags: [사용자]
      #     security:
      #       - bearerAuth: []
      #     responses:
      #       200:
      #         description: 성공적으로 사용자 프로필 정보 반환
      #         content:
      #           application/json:
      #             schema:
      #               type: object
      #               properties:
      #                 id:
      #                   type: integer
      #                 nickname:
      #                   type: string
      #                 phone_number:
      #                   type: string
      #                 last_login_at:
      #                   type: string
      #                   format: date-time
      #                 created_at:
      #                   type: string
      #                   format: date-time
      #       401:
      #         description: 인증 실패
      def profile
        Rails.logger.info("사용자 프로필 조회: 사용자 ID #{current_user.id}")

        begin
          render json: {
            id: current_user.id,
            nickname: current_user.nickname,
            phone_number: current_user.phone_number,
            last_login_at: current_user.last_login_at,
            created_at: current_user.created_at
          }, status: :ok
        rescue => e
          Rails.logger.error("사용자 프로필 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "사용자 프로필을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # GET /api/v1/users/me
      #
      # @swagger
      # /api/v1/users/me:
      #   get:
      #     summary: 현재 로그인한 사용자 정보 조회
      #     tags: [사용자]
      #     security:
      #       - bearerAuth: []
      #     responses:
      #       200:
      #         description: 성공적으로 사용자 정보 반환
      #         content:
      #           application/json:
      #             schema:
      #               type: object
      #               properties:
      #                 user:
      #                   $ref: '#/components/schemas/User'
      #       401:
      #         description: 인증 실패
      def me
        Rails.logger.info("현재 로그인 사용자 조회: 사용자 ID #{current_user.id}")

        begin
          render json: {
            user: {
              id: current_user.id,
              phone_number: current_user.phone_number,
              nickname: current_user.nickname,
              gender: current_user.gender || "unspecified",
              push_enabled: current_user.push_enabled,
              broadcast_push_enabled: current_user.broadcast_push_enabled,
              message_push_enabled: current_user.message_push_enabled,
              push_token: current_user.push_token,
              wallet_balance: current_user.wallet_balance,
              unread_notification_count: current_user.unread_notification_count,
              created_at: current_user.created_at,
              updated_at: current_user.updated_at
            }
          }
        rescue => e
          Rails.logger.error("사용자 정보 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "사용자 정보를 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # GET /api/v1/users/generate_random_nickname
      #
      # @swagger
      # /api/v1/users/generate_random_nickname:
      #   get:
      #     summary: 랜덤 닉네임 생성 API
      #     tags: [사용자]
      #     security:
      #       - bearerAuth: []
      #     responses:
      #       200:
      #         description: 성공적으로 랜덤 닉네임 생성
      #         content:
      #           application/json:
      #             schema:
      #               type: object
      #               properties:
      #                 nickname:
      #                   type: string
      #       401:
      #         description: 인증 실패
      def generate_random_nickname
        Rails.logger.info("랜덤 닉네임 생성 요청: 사용자 ID #{current_user.id}")

        begin
          # 랜덤 닉네임 생성 로직
          nickname = generate_random_nickname_string

          render json: {
            nickname: nickname,
            request_id: request.request_id || SecureRandom.uuid
          }, status: :ok

          Rails.logger.info("랜덤 닉네임 생성 성공: #{nickname}")
        rescue => e
          Rails.logger.error("랜덤 닉네임 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "랜덤 닉네임 생성 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      # POST /api/v1/users/change_nickname
      #
      # @swagger
      # /api/v1/users/change_nickname:
      #   post:
      #     summary: 닉네임 변경 API
      #     tags: [사용자]
      #     security:
      #       - bearerAuth: []
      #     requestBody:
      #       content:
      #         application/json:
      #           schema:
      #             type: object
      #             properties:
      #               nickname:
      #                 type: string
      #             required:
      #               - nickname
      #     responses:
      #       200:
      #         description: 성공적으로 닉네임 변경
      #       401:
      #         description: 인증 실패
      #       422:
      #         description: 유효하지 않은 닉네임
      def change_nickname
        Rails.logger.info("닉네임 변경 요청: 사용자 ID #{current_user.id}, 새 닉네임: #{params[:nickname]}")

        begin
          # 닉네임 유효성 검사
          unless params[:nickname].present?
            Rails.logger.warn("닉네임 변경 실패: 닉네임이 비어 있음")
            return render json: {
              error: "닉네임은 비워둘 수 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end

          # 닉네임 글자 수 제한 확인
          if params[:nickname].length < 2 || params[:nickname].length > 20
            Rails.logger.warn("닉네임 변경 실패: 닉네임 길이 제한 위반 (#{params[:nickname].length}자)")
            return render json: {
              error: "닉네임은 2자 이상 20자 이하여야 합니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end

          # 특수 문자 필터링 (선택적)
          if params[:nickname].match?(/[^\p{L}\p{N}\p{Z}]/i)
            Rails.logger.warn("닉네임 변경 실패: 허용되지 않는 특수문자 포함")
            return render json: {
              error: "닉네임에 특수문자를 사용할 수 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end

          # 중복 닉네임 확인 (선택적)
          if User.where.not(id: current_user.id).exists?(nickname: params[:nickname])
            Rails.logger.warn("닉네임 변경 실패: 중복된 닉네임 (#{params[:nickname]})")
            return render json: {
              error: "이미 사용 중인 닉네임입니다. 다른 닉네임을 선택해주세요.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end

          # 닉네임 업데이트
          if current_user.update(nickname: params[:nickname])
            Rails.logger.info("닉네임 변경 성공: 사용자 ID #{current_user.id}, 새 닉네임: #{current_user.nickname}")
            render json: {
              message: "닉네임이 성공적으로 변경되었습니다.",
              user: {
                id: current_user.id,
                nickname: current_user.nickname
              },
              request_id: request.request_id || SecureRandom.uuid
            }, status: :ok
          else
            Rails.logger.warn("닉네임 변경 실패: #{current_user.errors.full_messages.join(', ')}")
            render json: {
              error: current_user.errors.full_messages.join(", "),
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("닉네임 변경 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "닉네임 변경 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      # POST /api/v1/users/update_profile
      #
      # @swagger
      # /api/v1/users/update_profile:
      #   post:
      #     summary: 사용자 프로필 업데이트 API
      #     tags: [사용자]
      #     security:
      #       - bearerAuth: []
      #     requestBody:
      #       content:
      #         application/json:
      #           schema:
      #             type: object
      #             properties:
      #               gender:
      #                 type: string
      #                 enum: [male, female, other, unspecified]
      #               nickname:
      #                 type: string
      #     responses:
      #       200:
      #         description: 성공적으로 프로필 업데이트
      #       401:
      #         description: 인증 실패
      #       422:
      #         description: 유효하지 않은 입력값
      def update_profile
        Rails.logger.info("프로필 업데이트 요청: 사용자 ID #{current_user.id}, 파라미터: #{profile_params.inspect}")

        begin
          # 파라미터 유효성 검사
          if profile_params[:nickname].present?
            if profile_params[:nickname].length < 2 || profile_params[:nickname].length > 20
              Rails.logger.warn("프로필 업데이트 실패: 닉네임 길이 제한 위반 (#{profile_params[:nickname].length}자)")
              return render json: {
                error: "닉네임은 2자 이상 20자 이하여야 합니다.",
                request_id: request.request_id || SecureRandom.uuid
              }, status: :unprocessable_entity
            end
          end

          # 성별 유효성 검사
          if profile_params[:gender].present?
            # "unknown"을 "unspecified"로 변환
            gender_value = profile_params[:gender] == "unknown" ? "unspecified" : profile_params[:gender]
            
            unless [ "male", "female", "other", "unspecified" ].include?(gender_value)
              Rails.logger.warn("프로필 업데이트 실패: 유효하지 않은 성별 값 (#{profile_params[:gender]})")
              return render json: {
                error: "성별은 male, female, other, unspecified 중 하나여야 합니다.",
                request_id: request.request_id || SecureRandom.uuid
              }, status: :unprocessable_entity
            end
            
            # 변환된 값으로 파라미터 업데이트
            params[:gender] = gender_value
          end

          if current_user.update(profile_params)
            Rails.logger.info("프로필 업데이트 성공: 사용자 ID #{current_user.id}, 닉네임: #{current_user.nickname}, 성별: #{current_user.gender}")
            render json: {
              message: "프로필이 성공적으로 업데이트되었습니다.",
              user: {
                id: current_user.id,
                nickname: current_user.nickname,
                gender: current_user.gender || "unspecified"
              },
              request_id: request.request_id || SecureRandom.uuid
            }, status: :ok
          else
            Rails.logger.warn("프로필 업데이트 실패: #{current_user.errors.full_messages.join(', ')}")
            render json: {
              error: current_user.errors.full_messages.join(", "),
              request_id: request.request_id || SecureRandom.uuid
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("프로필 업데이트 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "프로필 업데이트 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      # GET /api/v1/users/notification_settings
      #
      # @swagger
      # /api/v1/users/notification_settings:
      #   get:
      #     summary: 사용자 알림 설정 조회
      #     tags: [사용자, 알림]
      #     security:
      #       - bearerAuth: []
      #     responses:
      #       200:
      #         description: 성공적으로 알림 설정 반환
      #         content:
      #           application/json:
      #             schema:
      #               type: object
      #               properties:
      #                 receive_new_letter:
      #                   type: boolean
      #                 letter_receive_alarm:
      #                   type: boolean
      #                 push_enabled:
      #                   type: boolean
      #                 broadcast_push_enabled:
      #                   type: boolean
      #                 message_push_enabled:
      #                   type: boolean
      #       401:
      #         description: 인증 실패
      def notification_settings
        Rails.logger.info("사용자 알림 설정 조회: 사용자 ID #{current_user.id}")

        begin
          if current_user
            render json: {
              receive_new_letter: current_user.broadcast_push_enabled,
              letter_receive_alarm: current_user.message_push_enabled,
              push_enabled: current_user.push_enabled,
              broadcast_push_enabled: current_user.broadcast_push_enabled,
              message_push_enabled: current_user.message_push_enabled
            }
          else
            Rails.logger.warn("알림 설정 조회 시 사용자 인증 실패")
            render json: {
              error: "사용자를 찾을 수 없습니다. 토큰이 만료되었거나 유효하지 않습니다.",
              code: "invalid_token"
            }, status: :unauthorized
          end
        rescue => e
          Rails.logger.error("알림 설정 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "알림 설정을 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # PATCH/PUT /api/v1/users/notification_settings
      #
      # @swagger
      # /api/v1/users/notification_settings:
      #   patch:
      #     summary: 사용자 알림 설정 업데이트
      #     tags: [사용자, 알림]
      #     security:
      #       - bearerAuth: []
      #     requestBody:
      #       content:
      #         application/json:
      #           schema:
      #             type: object
      #             properties:
      #               receive_new_letter:
      #                 type: boolean
      #               letter_receive_alarm:
      #                 type: boolean
      #               push_enabled:
      #                 type: boolean
      #               broadcast_push_enabled:
      #                 type: boolean
      #               message_push_enabled:
      #                 type: boolean
      #     responses:
      #       200:
      #         description: 성공적으로 알림 설정 업데이트
      #       401:
      #         description: 인증 실패
      #       422:
      #         description: 잘못된 요청
      def update_notification_settings
        Rails.logger.info("사용자 알림 설정 업데이트: 사용자 ID #{current_user.id}")

        begin
          settings_params = params.permit(
            :receive_new_letter,
            :letter_receive_alarm,
            :push_enabled,
            :broadcast_push_enabled,
            :message_push_enabled
          )

          # 매개변수 매핑 (클라이언트 키 -> 서버 DB 컬럼)
          update_params = {}

          # 브로드캐스트 알림 설정
          if settings_params.key?(:receive_new_letter)
            update_params[:broadcast_push_enabled] = settings_params[:receive_new_letter]
          end

          # 메시지 알림 설정
          if settings_params.key?(:letter_receive_alarm)
            update_params[:message_push_enabled] = settings_params[:letter_receive_alarm]
          end

          # 전체 푸시 설정
          if settings_params.key?(:push_enabled)
            update_params[:push_enabled] = settings_params[:push_enabled]
          end

          # 개별 설정이 직접 전달된 경우 (이전 버전과의 호환성)
          if settings_params.key?(:broadcast_push_enabled)
            update_params[:broadcast_push_enabled] = settings_params[:broadcast_push_enabled]
          end

          if settings_params.key?(:message_push_enabled)
            update_params[:message_push_enabled] = settings_params[:message_push_enabled]
          end

          Rails.logger.info("알림 설정 업데이트 파라미터: #{update_params.inspect}")

          if current_user.update(update_params)
            Rails.logger.info("알림 설정 업데이트 성공: 사용자 ID #{current_user.id}")
            render json: {
              message: "알림 설정이 업데이트되었습니다.",
              receive_new_letter: current_user.broadcast_push_enabled,
              letter_receive_alarm: current_user.message_push_enabled,
              push_enabled: current_user.push_enabled,
              broadcast_push_enabled: current_user.broadcast_push_enabled,
              message_push_enabled: current_user.message_push_enabled
            }
          else
            Rails.logger.warn("알림 설정 업데이트 실패: #{current_user.errors.full_messages.join(', ')}")
            render json: { error: current_user.errors.full_messages.join(", ") }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("알림 설정 업데이트 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "알림 설정을 업데이트하는 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # GET /api/v1/users/:id
      #
      # @swagger
      # /api/v1/users/{id}:
      #   get:
      #     summary: 특정 사용자 정보 조회
      #     tags: [사용자]
      #     security:
      #       - bearerAuth: []
      #     parameters:
      #       - name: id
      #         in: path
      #         required: true
      #         schema:
      #           type: integer
      #     responses:
      #       200:
      #         description: 성공적으로 사용자 정보 반환
      #         content:
      #           application/json:
      #             schema:
      #               type: object
      #               properties:
      #                 user:
      #                   $ref: '#/components/schemas/User'
      #       401:
      #         description: 인증 실패
      #       404:
      #         description: 사용자를 찾을 수 없음
      def show
        Rails.logger.info("사용자 상세 정보 조회: 사용자 ID #{@user.id}")

        begin
          render json: {
            user: {
              id: @user.id,
              nickname: @user.nickname,
              gender: @user.gender || "unspecified",
              created_at: @user.created_at,
              updated_at: @user.updated_at
            }
          }, status: :ok
        rescue => e
          Rails.logger.error("사용자 상세 정보 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "사용자 정보를 조회하는 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      # POST /api/v1/users/:id/block
      #
      # @swagger
      # /api/v1/users/{id}/block:
      #   post:
      #     summary: 특정 사용자 차단
      #     tags: [사용자]
      #     security:
      #       - bearerAuth: []
      #     parameters:
      #       - name: id
      #         in: path
      #         required: true
      #         schema:
      #           type: integer
      #     responses:
      #       200:
      #         description: 성공적으로 사용자 차단 완료
      #       401:
      #         description: 인증 실패
      #       404:
      #         description: 사용자를 찾을 수 없음
      def block
        Rails.logger.info("사용자 차단 요청: 차단 대상 사용자 ID #{@user.id}")

        begin
          # 이미 차단한 사용자인지 확인
          existing_block = UserBlock.find_by(blocker_id: current_user.id, blocked_id: @user.id)

          if existing_block
            Rails.logger.info("이미 차단된 사용자: 차단 대상 사용자 ID #{@user.id}")
            render json: { message: "이미 차단된 사용자입니다." }, status: :ok
            return
          end

          # 차단 관계 생성
          block = UserBlock.new(blocker_id: current_user.id, blocked_id: @user.id)

          if block.save
            Rails.logger.info("사용자 차단 성공: 차단 대상 사용자 ID #{@user.id}")
            render json: { message: "사용자가 성공적으로 차단되었습니다." }, status: :ok
          else
            Rails.logger.warn("사용자 차단 실패: #{block.errors.full_messages.join(', ')}")
            render json: { error: block.errors.full_messages.join(", ") }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("사용자 차단 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: { error: "사용자 차단 중 오류가 발생했습니다." }, status: :internal_server_error
        end
      end

      private

      def set_user
        @user = User.find(params[:id])
      end

      def profile_params
        params.permit(:gender, :nickname)
      end

      def generate_random_nickname_string
        # 형용사와 명사 리스트
        adjectives = [ "행복한", "즐거운", "멋진", "신나는", "귀여운", "활발한", "친절한", "사랑스러운", "따뜻한", "밝은",
                      "지혜로운", "용감한", "재미있는", "흥미로운", "창의적인", "열정적인", "정직한", "예쁜", "쾌활한", "다정한" ]
        nouns = [ "강아지", "고양이", "토끼", "사자", "호랑이", "코끼리", "판다", "곰", "여우", "늑대",
                 "독수리", "참새", "햄스터", "다람쥐", "고래", "돌고래", "거북이", "원숭이", "얼룩말", "캥거루" ]

        # 랜덤 형용사와 명사 선택
        adjective = adjectives.sample
        noun = nouns.sample

        # 랜덤 숫자 추가 (100~999)
        number = rand(100..999)

        # 닉네임 조합
        "#{adjective}#{noun}#{number}"
      end
    end
  end
end
