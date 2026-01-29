# app/events/base_event.rb
class BaseEvent
  include ActiveSupport::Callbacks
  
  define_callbacks :publish
  
  attr_reader :occurred_at, :event_id
  
  def initialize(**attributes)
    @occurred_at = Time.current
    @event_id = SecureRandom.uuid
    
    attributes.each do |key, value|
      instance_variable_set("@#{key}", value)
      self.class.send(:attr_reader, key) unless respond_to?(key)
    end
  end
  
  def publish
    run_callbacks :publish do
      Rails.logger.info("Publishing event: #{self.class.name} (#{event_id})")
      
      # 이벤트 발행 전략 선택
      publisher.publish(self)
    end
  end
  
  def to_h
    instance_variables.each_with_object({}) do |var, hash|
      key = var.to_s.delete("@")
      hash[key.to_sym] = instance_variable_get(var)
    end
  end
  
  private
  
  def publisher
    # 기본 발행자 (추후 Redis Pub/Sub, Kafka 등으로 확장 가능)
    @publisher ||= InMemoryEventPublisher.new
  end
end

# 인메모리 이벤트 발행자 (개발/테스트용)
class InMemoryEventPublisher
  def publish(event)
    # 등록된 구독자들에게 이벤트 전달
    EventBus.publish(event)
  end
end 