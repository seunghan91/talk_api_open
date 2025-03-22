module Api
  module V1
    class ConversationsController < ApplicationController
      before_action :authorize_request
      
      # 모든 대화 목록 가져오기
      def index
        # 사용자별로 대화를 그룹화하여 표시
        @conversations = Message.where(recipient_id: current_user.id)
                               .order(created_at: :desc)
                               .group_by(&:sender_id)
                               .map do |sender_id, messages|
          sender = User.find(sender_id)
          last_message = messages.max_by(&:created_at)
          {
            id: sender_id,
            sender: {
              id: sender.id,
              nickname: sender.nickname,
              profile_image: sender.profile_image_url,
              gender: sender.gender
            },
            last_message: {
              id: last_message.id,
              content: last_message.content,
              voice_url: last_message.voice_recording_url,
              created_at: last_message.created_at,
              formatted_date: last_message.created_at.strftime('%Y년 %m월 %d일 %H:%M')
            },
            unread_count: messages.count { |m| m.read_at.nil? },
            message_count: messages.count,
            is_favorite: current_user.favorite_conversation?(sender_id),
            updated_at: last_message.created_at
          }
        end.sort_by { |conv| conv[:updated_at] }.reverse
        
        render json: @conversations
      end
      
      # 특정 대화 내용 가져오기
      def show
        sender_id = params[:id]
        
        begin
          sender = User.find(sender_id)
        rescue ActiveRecord::RecordNotFound
          return render json: { error: '사용자를 찾을 수 없습니다' }, status: :not_found
        end
        
        # 1. 일반 메시지 조회
        direct_messages = Message.where(
          "(sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)",
          sender_id, current_user.id, current_user.id, sender_id
        )
        
        # 2. 브로드캐스트 메시지 조회
        broadcast_messages = []
        begin
          # 상대방이 보낸 브로드캐스트 조회
          broadcasts = Broadcast.where(user_id: sender_id)
            .joins(:recipients)
            .where(recipients: { user_id: current_user.id })
          
          # 현재 사용자가 보낸 브로드캐스트 중 상대방에게 전송된 메시지도 포함
          user_broadcasts = Broadcast.where(user_id: current_user.id)
            .joins(:recipients)
            .where(recipients: { user_id: sender_id })
          
          # 모든 브로드캐스트 합치기
          all_broadcasts = broadcasts + user_broadcasts
          
          # 브로드캐스트 정보를 메시지 형식으로 변환
          all_broadcasts.each do |broadcast|
            broadcast_messages << {
              id: "broadcast_#{broadcast.id}",
              sender_id: broadcast.user_id,
              recipient_id: broadcast.user_id == current_user.id ? sender_id : current_user.id,
              content: broadcast.content,
              voice_recording_url: broadcast.voice_recording_url,
              created_at: broadcast.created_at,
              read_at: Time.current, # 읽은 것으로 표시
              message_type: 'broadcast'
            }
          end
        rescue => e
          Rails.logger.error("브로드캐스트 메시지 조회 오류: #{e.message}")
        end
        
        # 3. 모든 메시지 통합 및 시간순 정렬
        all_messages = (direct_messages.to_a + broadcast_messages).sort_by { |m| m.is_a?(Hash) ? m[:created_at] : m.created_at }
        
        # 4. 읽지 않은 메시지 읽음 처리
        direct_messages.where(recipient_id: current_user.id, read_at: nil).update_all(read_at: Time.current)
        
        # 5. 응답 형식 구성
        formatted_messages = all_messages.map do |message|
          is_broadcast = message.is_a?(Hash) && message[:message_type] == 'broadcast'
          sender_id = is_broadcast ? message[:sender_id] : message.sender_id
          {
            id: is_broadcast ? message[:id] : message.id,
            content: is_broadcast ? message[:content] : message.content,
            voice_url: is_broadcast ? message[:voice_recording_url] : message.voice_recording_url,
            is_sender: sender_id == current_user.id,
            created_at: is_broadcast ? message[:created_at] : message.created_at,
            formatted_date: (is_broadcast ? message[:created_at] : message.created_at).strftime('%Y년 %m월 %d일 %H:%M'),
            is_read: is_broadcast ? true : !message.read_at.nil?,
            message_type: is_broadcast ? 'broadcast' : 'direct'
          }
        end
        
        render json: {
          conversation: {
            id: sender_id,
            sender: {
              id: sender.id,
              nickname: sender.nickname,
              profile_image: sender.profile_image_url,
              gender: sender.gender
            },
            is_favorite: current_user.favorite_conversation?(sender_id)
          },
          messages: formatted_messages
        }
      end
      
      # 메시지 보내기
      def send_message
        recipient_id = params[:id]
        
        # 수신자 확인
        begin
          recipient = User.find(recipient_id)
        rescue ActiveRecord::RecordNotFound
          return render json: { error: '수신자를 찾을 수 없습니다' }, status: :not_found
        end
        
        # 대화 찾기 또는 생성
        conversation = Conversation.find_by(
          "(user_a_id = ? AND user_b_id = ?) OR (user_a_id = ? AND user_b_id = ?)",
          current_user.id, recipient_id, recipient_id, current_user.id
        )
        
        # 대화가 없으면 생성
        unless conversation
          conversation = Conversation.create(
            user_a_id: current_user.id,
            user_b_id: recipient_id
          )
        end
        
        # 메시지 생성
        @message = Message.new(
          sender_id: current_user.id,
          recipient_id: recipient_id,
          conversation_id: conversation&.id,
          content: params[:content],
          message_type: 'text'
        )
        
        # 음성 메시지인 경우
        if params[:voice_recording].present?
          begin
            @message.voice_recording.attach(params[:voice_recording])
            @message.message_type = 'voice'
            
            # 첨부 확인
            if !@message.voice_recording.attached?
              return render json: { error: '음성 파일 첨부에 실패했습니다.' }, status: :unprocessable_entity
            end
          rescue => e
            Rails.logger.error("음성 파일 첨부 중 오류: #{e.message}")
            return render json: { error: "음성 파일 처리 중 오류가 발생했습니다: #{e.message}" }, status: :unprocessable_entity
          end
        end
        
        # 메시지 저장
        if @message.save
          # 푸시 알림 전송 (필요하다면)
          # PushNotificationWorker.perform_async('new_message', @message.id, current_user.id)
          
          render json: {
            success: true,
            message: {
              id: @message.id,
              content: @message.content,
              voice_url: @message.voice_recording_url,
              is_sender: true,
              created_at: @message.created_at,
              formatted_date: @message.created_at.strftime('%Y년 %m월 %d일 %H:%M'),
              is_read: false,
              message_type: 'direct'
            }
          }, status: :created
        else
          render json: { error: '메시지 전송에 실패했습니다', details: @message.errors.full_messages }, status: :unprocessable_entity
        end
      end
      
      # 대화 삭제
      def destroy
        sender_id = params[:id]
        
        # 해당 사용자와의 모든 메시지 삭제
        Message.where(
          "(sender_id = ? AND recipient_id = ?) OR (sender_id = ? AND recipient_id = ?)",
          sender_id, current_user.id, current_user.id, sender_id
        ).destroy_all
        
        render json: { success: true, message: '대화가 삭제되었습니다' }
      end
      
      # 대화 즐겨찾기 추가
      def favorite
        sender_id = params[:id]
        
        # 즐겨찾기 추가 로직 (사용자 모델에 메서드로 구현)
        if current_user.add_favorite_conversation(sender_id)
          render json: { success: true, message: '즐겨찾기에 추가되었습니다' }
        else
          render json: { error: '즐겨찾기 추가에 실패했습니다' }, status: :unprocessable_entity
        end
      end
      
      # 대화 즐겨찾기 제거
      def unfavorite
        sender_id = params[:id]
        
        # 즐겨찾기 제거 로직 (사용자 모델에 메서드로 구현)
        if current_user.remove_favorite_conversation(sender_id)
          render json: { success: true, message: '즐겨찾기에서 제거되었습니다' }
        else
          render json: { error: '즐겨찾기 제거에 실패했습니다' }, status: :unprocessable_entity
        end
      end
    end
  end
end 