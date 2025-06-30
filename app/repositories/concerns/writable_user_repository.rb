# frozen_string_literal: true

module WritableUserRepository
  extend ActiveSupport::Concern
  
  included do
    # 쓰기 전용 메서드들
    def create(attributes)
      User.create(attributes)
    end
    
    def create!(attributes)
      User.create!(attributes)
    end
    
    def update(id, attributes)
      user = User.find(id)
      user.update(attributes)
      user
    end
    
    def update!(id, attributes)
      user = User.find(id)
      user.update!(attributes)
      user
    end
    
    def destroy(id)
      user = User.find(id)
      user.destroy
    end
    
    def destroy_all(conditions = {})
      if conditions.any?
        User.where(conditions).destroy_all
      else
        User.destroy_all
      end
    end
    
    def insert_all(attributes_array)
      User.insert_all(attributes_array)
    end
    
    def upsert_all(attributes_array)
      User.upsert_all(attributes_array)
    end
    
    # 트랜잭션 지원
    def transaction(&block)
      User.transaction(&block)
    end
  end
end

# 쓰기 전용 Repository 구현
class WriteOnlyUserRepository
  include WritableUserRepository
  
  # 읽기 메서드를 명시적으로 비활성화
  def find(*)
    raise NotImplementedError, "This is a write-only repository"
  end
  
  def find_by(*)
    raise NotImplementedError, "This is a write-only repository"
  end
  
  def where(*)
    raise NotImplementedError, "This is a write-only repository"
  end
  
  def all
    raise NotImplementedError, "This is a write-only repository"
  end
  
  def count(*)
    raise NotImplementedError, "This is a write-only repository"
  end
end 