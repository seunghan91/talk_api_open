# frozen_string_literal: true

module ReadableUserRepository
  extend ActiveSupport::Concern
  
  included do
    # 읽기 전용 메서드들
    def find(id)
      User.find(id)
    end
    
    def find_by(attributes)
      User.find_by(attributes)
    end
    
    def find_by_phone_number(phone_number)
      User.find_by(phone_number: phone_number)
    end
    
    def all
      User.all
    end
    
    def where(conditions)
      User.where(conditions)
    end
    
    def exists?(id_or_conditions)
      if id_or_conditions.is_a?(Hash)
        User.exists?(id_or_conditions)
      else
        User.exists?(id_or_conditions)
      end
    end
    
    def count(conditions = {})
      if conditions.any?
        User.where(conditions).count
      else
        User.count
      end
    end
    
    # 추가 읽기 전용 메서드들
    def first
      User.first
    end
    
    def last
      User.last
    end
    
    def pluck(*column_names)
      User.pluck(*column_names)
    end
    
    def includes(*associations)
      User.includes(*associations)
    end
    
    def joins(*associations)
      User.joins(*associations)
    end
    
    def order(args)
      User.order(args)
    end
    
    def limit(value)
      User.limit(value)
    end
  end
end

# 읽기 전용 Repository 구현
class ReadOnlyUserRepository
  include ReadableUserRepository
  
  # 쓰기 메서드를 명시적으로 비활성화
  def create(*)
    raise NotImplementedError, "This is a read-only repository"
  end
  
  def update(*)
    raise NotImplementedError, "This is a read-only repository"
  end
  
  def destroy(*)
    raise NotImplementedError, "This is a read-only repository"
  end
  
  def save(*)
    raise NotImplementedError, "This is a read-only repository"
  end
end 