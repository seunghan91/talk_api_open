# app/controllers/web/conversations_controller.rb
module Web
  class ConversationsController < Web::BaseController
    before_action :authenticate_user!

    # GET /conversations
    def index
      conversations = Conversation.for_user(current_user.id)
        .not_deleted_for(current_user.id)
        .includes(:user_a, :user_b)
        .order(updated_at: :desc)
        .page(params[:page])
        .per(20)

      render inertia: "Conversations/Index", props: {
        conversations: conversations.map { |c| serialize_conversation(c) },
        pagination: pagination_meta(conversations)
      }
    end

    # GET /conversations/:id
    def show
      conversation = Conversation.find(params[:id])
      messages = conversation.messages
        .includes(:user)
        .order(created_at: :asc)
        .last(50)

      render inertia: "Conversations/Show", props: {
        conversation: serialize_conversation_detail(conversation),
        messages: messages.map { |m| serialize_message(m) }
      }
    end

    # POST /conversations/:id/send_message
    def send_message
      conversation = Conversation.find(params[:id])
      service = MessageService.new(current_user)

      message_type = params[:voice_file].present? ? "voice" : "text"
      result = service.send_message(conversation.id, {
        message_type: message_type,
        voice_file: params[:voice_file]
      })

      if result.success?
        redirect_to "/conversations/#{conversation.id}"
      else
        redirect_to "/conversations/#{conversation.id}",
          inertia: { errors: { message: result.error } }
      end
    end

    # POST /conversations/:id/favorite
    def favorite
      conversation = Conversation.find(params[:id])
      if conversation.user_a_id == current_user.id
        conversation.update(favorited_by_a: true)
      elsif conversation.user_b_id == current_user.id
        conversation.update(favorited_by_b: true)
      end
      redirect_to "/conversations"
    end

    private

    def serialize_conversation(conversation)
      other_user = conversation.other_user(current_user)
      last_message = conversation.messages.order(created_at: :desc).first

      {
        id: conversation.id,
        other_user: {
          id: other_user&.id,
          nickname: other_user&.nickname
        },
        last_message: last_message ? {
          content: last_message.content,
          is_voice: last_message.voice_file.attached?,
          created_at: last_message.created_at.iso8601
        } : nil,
        is_favorited: conversation.favorited_by?(current_user.id),
        unread_count: conversation.messages
          .where.not(sender_id: current_user.id)
          .where(read: false)
          .count,
        updated_at: conversation.updated_at.iso8601
      }
    rescue => e
      nil
    end

    def serialize_conversation_detail(conversation)
      other_user = conversation.other_user(current_user)
      {
        id: conversation.id,
        other_user: {
          id: other_user&.id,
          nickname: other_user&.nickname
        },
        is_favorited: conversation.favorited_by?(current_user.id),
        broadcast_id: conversation.broadcast_id
      }
    end

    def serialize_message(message)
      {
        id: message.id,
        content: message.content,
        is_mine: message.user_id == current_user.id,
        is_voice: message.voice_file.attached?,
        voice_url: message.voice_file.attached? ? url_for(message.voice_file) : nil,
        duration: message.duration,
        created_at: message.created_at.iso8601
      }
    end
  end
end
