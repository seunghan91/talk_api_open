module Api
  module V1
    class BroadcastsController < Api::V1::BaseController
      before_action :authorize_request
      before_action :ensure_user_active
      # 인증 요청 엔드포인트는 인증 없이 접근 가능하도록 설정
      # request_code와 verify_code 액션이 없으므로 제거
      # skip_before_action :authorize_request, only: [:request_code, :verify_code]

      # 예제 브로드캐스트 API 추가
      def example_broadcast
        begin
          # 샘플 오디오 파일 URL 생성
          base_url = ENV.fetch("RENDER_EXTERNAL_URL", "http://#{request.host_with_port}")
          sample_audio_url = "#{base_url}/audio_samples/sample_audio.wav"

          # 샘플 브로드캐스트 응답 생성
          render json: {
            example_broadcast: {
              id: 999,
              text: "이것은 샘플 브로드캐스트입니다.",
              audio_url: sample_audio_url,
              created_at: Time.current,
              sender: {
                id: current_user.id,
                nickname: current_user.nickname
              }
            },
            message: "이 브로드캐스트는 테스트용 예제입니다. 실제 데이터베이스에 저장되지 않습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("예제 브로드캐스트 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "예제 브로드캐스트를 조회하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      def index
        begin
          # 쿼리 파라미터로 필터 옵션 받기
          filter = params[:filter] || "all" # all, sent, received

          case filter
          when "sent"
            # 보낸 브로드캐스트만
            @broadcasts = current_user.broadcasts
                                     .includes(:user, broadcast_recipients: :user)
                                     .with_attached_audio
                                     .order(created_at: :desc)
                                     .limit(50)
          when "received"
            # 받은 브로드캐스트만
            @broadcasts = Broadcast.joins(:broadcast_recipients)
                                  .where(broadcast_recipients: { user_id: current_user.id })
                                  .includes(:user)
                                  .with_attached_audio
                                  .order("broadcast_recipients.created_at DESC")
                                  .limit(50)
          else
            # 모든 브로드캐스트 (보낸 것 + 받은 것)
            sent_broadcasts = current_user.broadcasts.select(:id).to_sql
            received_broadcasts = Broadcast.joins(:broadcast_recipients)
                                         .where(broadcast_recipients: { user_id: current_user.id })
                                         .select(:id).to_sql

            broadcast_ids = Broadcast.from("(#{sent_broadcasts} UNION #{received_broadcasts}) AS broadcasts").pluck(:id)

            @broadcasts = Broadcast.where(id: broadcast_ids)
                                  .includes(:user, broadcast_recipients: :user)
                                  .with_attached_audio
                                  .order(created_at: :desc)
                                  .limit(50)
          end

          render json: {
            broadcasts: @broadcasts.map { |broadcast| broadcast_response(broadcast) },
            filter: filter,
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("방송 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "방송 목록을 조회하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      # 받은 브로드캐스트 목록 조회 (별도 엔드포인트)
      def received
        begin
          # 현재 사용자가 수신한 브로드캐스트 목록
          @broadcasts = Broadcast.joins(:broadcast_recipients)
                                .where(broadcast_recipients: { user_id: current_user.id })
                                .includes(:user)
                                .with_attached_audio
                                .order("broadcast_recipients.created_at DESC")
                                .page(params[:page])
                                .per(20)

          # 각 브로드캐스트의 수신 상태 포함
          broadcasts_with_status = @broadcasts.map do |broadcast|
            recipient = broadcast.broadcast_recipients.find { |r| r.user_id == current_user.id }
            broadcast_data = broadcast_response(broadcast)
            broadcast_data[:recipient_status] = recipient.status
            broadcast_data[:received_at] = recipient.created_at
            broadcast_data
          end

          render json: {
            broadcasts: broadcasts_with_status,
            pagination: {
              current_page: @broadcasts.current_page,
              total_pages: @broadcasts.total_pages,
              total_count: @broadcasts.total_count
            },
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("수신 방송 목록 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "수신 방송 목록을 조회하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      # 브로드캐스트 읽음 상태 업데이트
      def mark_as_read
        begin
          broadcast = Broadcast.find(params[:id])
          recipient = BroadcastRecipient.find_by!(
            broadcast_id: broadcast.id,
            user_id: current_user.id
          )

          # 상태를 'read'로 업데이트
          recipient.update!(status: :read) if recipient.delivered?

          render json: {
            message: "브로드캐스트가 읽음 처리되었습니다.",
            status: recipient.status,
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue ActiveRecord::RecordNotFound
          render json: {
            error: "브로드캐스트를 찾을 수 없거나 권한이 없습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :not_found
        rescue => e
          Rails.logger.error("브로드캐스트 읽음 처리 중 오류 발생: #{e.message}")
          render json: {
            error: "브로드캐스트 읽음 처리 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      def create
        Rails.logger.info "방송 생성 요청: 사용자 ID #{current_user.id}, 닉네임 #{current_user.nickname}"

        # SOLID 원칙에 따라 Command 패턴 사용
        command = ::Broadcasts::CreateBroadcastCommand.new(
          user: current_user,
          audio_file: params[:broadcast][:voice_file],
          content: params[:broadcast][:content],
          recipient_count: params[:broadcast][:recipient_count]
        )

        result = command.execute

        if result[:success]
          render json: {
            message: "방송이 성공적으로 전송되었습니다.",
            broadcast: result[:broadcast],
            recipient_count: result[:recipient_count],
            request_id: request.request_id || SecureRandom.uuid
          }, status: :created
        else
          render json: {
            error: result[:error],
            errors: result[:errors],
            request_id: request.request_id || SecureRandom.uuid
          }.compact, status: result[:status] || :unprocessable_entity
        end
      rescue ActionController::ParameterMissing => e
        Rails.logger.warn("파라미터 누락: #{e.message}")
        render json: {
          error: "필수 파라미터가 누락되었습니다.",
          request_id: request.request_id || SecureRandom.uuid
        }, status: :bad_request
      rescue => e
        Rails.logger.error("방송 생성 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: {
          error: "방송을 전송하는 중 오류가 발생했습니다.",
          request_id: request.request_id || SecureRandom.uuid
        }, status: :internal_server_error
      end

      def show
        begin
          @broadcast = Broadcast.includes(:user)
                               .with_attached_audio
                               .find_by(id: params[:id])

          unless @broadcast
            return render json: {
              error: "방송을 찾을 수 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :not_found
          end

          # 권한 검사: 자신의 방송이거나 수신한 방송인지 확인
          unless @broadcast.user_id == current_user.id || is_recipient?(@broadcast)
            return render json: {
              error: "이 방송에 접근할 권한이 없습니다.",
              request_id: request.request_id || SecureRandom.uuid
            }, status: :forbidden
          end

          render json: {
            broadcast: broadcast_detail_response(@broadcast),
            request_id: request.request_id || SecureRandom.uuid
          }
        rescue => e
          Rails.logger.error("방송 조회 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
          render json: {
            error: "방송을 조회하는 중 오류가 발생했습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :internal_server_error
        end
      end

      def reply
        Rails.logger.info("방송 답장 요청: 사용자 ID #{current_user.id}, 방송 ID #{params[:id]}")

        # SOLID 원칙에 따라 Command 패턴 사용
        command = ::Broadcasts::ReplyToBroadcastCommand.new(
          user: current_user,
          broadcast_id: params[:id],
          voice_file: params[:voice_file]
        )

        result = command.execute

        if result[:success]
          render json: {
            message: "답장이 성공적으로 전송되었습니다.",
            conversation: {
              id: result[:conversation_id],
              with_user: result[:recipient]
            },
            request_id: request.request_id || SecureRandom.uuid
          }, status: :ok
        else
          render json: {
            error: result[:error],
            errors: result[:errors],
            request_id: request.request_id || SecureRandom.uuid
          }.compact, status: result[:status] || :unprocessable_entity
        end
      rescue => e
        Rails.logger.error("답장 중 오류 발생: #{e.message}\n#{e.backtrace.join("\n")}")
        render json: {
          error: "답장 처리 중 오류가 발생했습니다.",
          request_id: request.request_id || SecureRandom.uuid
        }, status: :internal_server_error
      end

      private

      # 사용자가 활성 상태인지 확인
      def ensure_user_active
        unless current_user.status_active?
          Rails.logger.warn("비활성 사용자의 방송 접근 시도: 사용자 ID #{current_user.id}, 상태 #{current_user.status}")
          render json: {
            error: "현재 계정 상태로는 이 기능을 사용할 수 없습니다.",
            request_id: request.request_id || SecureRandom.uuid
          }, status: :forbidden
          return false
        end
        true
      end

      # 테스트 계정 여부 확인
      def is_test_account?
        current_user.phone_number.match?(/^010\d{8}$/) &&
        current_user.phone_number.gsub(/\D/, "").match?(/^010(1|2|3|4|5){2}+\1{6}$/)
      end

      # 테스트 계정 방송 처리
      def handle_test_account_broadcast(broadcast_content, recipient_count)
        Rails.logger.info "테스트 계정 방송 처리: #{current_user.phone_number}"
        # 테스트 계정은 다른 테스트 계정에만 방송
        all_test_recipients = [
          { id: 1, phone_number: "01011111111", nickname: "김철수", gender: "male" },
          { id: 2, phone_number: "01022222222", nickname: "이영희", gender: "female" },
          { id: 3, phone_number: "01033333333", nickname: "박지민", gender: "male" },
          { id: 4, phone_number: "01044444444", nickname: "최수진", gender: "female" },
          { id: 5, phone_number: "01055555555", nickname: "정민준", gender: "male" }
        ]

        # 현재 사용자를 제외
        filtered_recipients = all_test_recipients.reject { |recipient| recipient[:id] == current_user.id }

        # 수신자 수만큼 선택
        recipients = filtered_recipients.sample(recipient_count)

        # 방송 생성 및 저장
        # 여기서는 테스트 데이터만 반환하고 실제 저장은 하지 않음
        render json: {
          message: "방송이 성공적으로 전송되었습니다.",
          broadcast: {
            id: SecureRandom.uuid,
            audio_url: "https://example.com/test_audio.mp3",
            content: broadcast_content,
            sender: {
              id: current_user.id,
              nickname: current_user.nickname
            },
            created_at: Time.current,
            is_test: true
          },
          recipient_count: recipient_count,
          recipients: recipients,
          request_id: request.request_id || SecureRandom.uuid
        }, status: :created
      end

      # 현재 사용자가 방송의 수신자인지 확인
      def is_recipient?(broadcast)
        BroadcastRecipient.exists?(broadcast_id: broadcast.id, user_id: current_user.id)
      end

      # 방송 목록 응답 포맷
      def broadcast_response(broadcast)
        # 오디오 URL 유효 기간 설정 (환경 변수에서 가져오거나 기본값 7일 사용)
        audio_url_expiry = ENV.fetch("AUDIO_URL_EXPIRY_DAYS", "7").to_i.days

        # 로그에 현재 설정된 만료 시간 기록 (디버깅용)
        Rails.logger.debug("오디오 URL 만료 시간 설정: #{audio_url_expiry / 1.day}일")

        {
          id: broadcast.id,
          content: broadcast.content,
          # 서명된 URL 생성 - 콘텐츠 자체 만료 시간과 일관되게 설정
          audio_url: broadcast.audio.attached? ? rails_blob_url(broadcast.audio, disposition: "attachment", expires_in: audio_url_expiry) : nil,
          sender: {
            id: broadcast.user_id,
            nickname: broadcast.user.nickname
          },
          created_at: broadcast.created_at
        }
      end

      # 방송 상세 응답 포맷
      def broadcast_detail_response(broadcast)
        response = broadcast_response(broadcast)

        # 수신자 목록 추가 (본인이 발신자인 경우에만)
        if broadcast.user_id == current_user.id
          recipients = BroadcastRecipient.includes(:user)
                                        .where(broadcast_id: broadcast.id)
                                        .map do |br|
            {
              id: br.user_id,
              nickname: br.user.nickname,
              status: br.status
            }
          end

          response[:recipients] = recipients
        end

        # 본인이 수신자인 경우 상태 추가
        if broadcast.user_id != current_user.id
          recipient = BroadcastRecipient.find_by(broadcast_id: broadcast.id, user_id: current_user.id)
          response[:status] = recipient&.status
        end

        response
      end
    end
  end
end
