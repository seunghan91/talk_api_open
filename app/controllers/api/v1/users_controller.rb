module Api
  module V1
    class UsersController < Api::V1::BaseController
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

      private

      def set_user
        @user = User.find(params[:id])
      end
    end
  end
end
