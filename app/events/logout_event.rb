# app/events/logout_event.rb
class LogoutEvent < BaseEvent
  attr_reader :user
  
  def initialize(user:)
    super(user: user)
  end
  
  def to_h
    super.merge(
      user_id: user.id,
      user_phone: user.phone_number,
      logged_out_at: occurred_at
    )
  end
end 