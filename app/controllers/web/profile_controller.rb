# app/controllers/web/profile_controller.rb
module Web
  class ProfileController < Web::BaseController
    before_action :authenticate_user!

    # GET /profile
    def show
      render inertia: "Profile/Show", props: {
        profile: serialize_profile(current_user)
      }
    end

    # GET /profile/edit
    def edit
      render inertia: "Profile/Edit", props: {
        profile: serialize_profile(current_user)
      }
    end

    # PATCH /profile
    def update
      if current_user.update(profile_params)
        redirect_to "/profile", notice: "프로필이 수정되었습니다."
      else
        redirect_to "/profile/edit", inertia: {
          errors: current_user.errors.messages.transform_values(&:first)
        }
      end
    end

    private

    def profile_params
      params.permit(:nickname, :gender, :age_range, :bio)
    end

    def serialize_profile(user)
      {
        id: user.id,
        nickname: user.nickname,
        phone_number: mask_phone(user.phone_number),
        gender: user.gender,
        age_range: user.respond_to?(:age_range) ? user.age_range : nil,
        bio: user.respond_to?(:bio) ? user.bio : nil,
        broadcasts_count: user.broadcasts.count,
        conversations_count: Conversation.for_user(user.id).count,
        created_at: user.created_at.iso8601
      }
    end

    def mask_phone(phone)
      return "" unless phone
      "#{phone[0..2]}****#{phone[-4..]}"
    end
  end
end
