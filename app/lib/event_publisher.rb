# app/lib/event_publisher.rb
class EventPublisher
  def initialize
    @bus = EventBus
  end
  
  def publish(event)
    Rails.logger.info("Publishing event: #{event.class.name}")
    @bus.publish(event)
  end
end 