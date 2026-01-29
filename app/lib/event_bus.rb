# app/lib/event_bus.rb
class EventBus
  class << self
    def subscribe(event_class, subscriber)
      subscribers[event_class.name] ||= []
      subscribers[event_class.name] << subscriber
    end
    
    def unsubscribe(event_class, subscriber)
      subscribers[event_class.name]&.delete(subscriber)
    end
    
    def publish(event)
      event_subscribers = subscribers[event.class.name] || []
      
      event_subscribers.each do |subscriber|
        begin
          if subscriber.respond_to?(:call)
            subscriber.call(event)
          elsif subscriber.respond_to?(:handle)
            subscriber.handle(event)
          else
            method_name = "on_#{event.class.name.underscore}"
            subscriber.send(method_name, event) if subscriber.respond_to?(method_name)
          end
        rescue => e
          Rails.logger.error("Error handling event #{event.class.name}: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
    end
    
    def reset!
      @subscribers = {}
    end
    
    private
    
    def subscribers
      @subscribers ||= {}
    end
  end
end 