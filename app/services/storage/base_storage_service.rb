# frozen_string_literal: true

module Storage
  class BaseStorageService
    # 모든 Storage 서비스가 구현해야 하는 인터페이스
    
    def upload(file:, key:, content_type: nil)
      raise NotImplementedError, "#{self.class} must implement #upload"
    end
    
    def download(key:)
      raise NotImplementedError, "#{self.class} must implement #download"
    end
    
    def delete(key:)
      raise NotImplementedError, "#{self.class} must implement #delete"
    end
    
    def exists?(key:)
      raise NotImplementedError, "#{self.class} must implement #exists?"
    end
    
    def url(key:)
      raise NotImplementedError, "#{self.class} must implement #url"
    end
    
    protected
    
    def validate_file!(file)
      raise ArgumentError, "File cannot be nil" if file.nil?
      raise ArgumentError, "File must respond to :read" unless file.respond_to?(:read)
    end
    
    def validate_key!(key)
      raise ArgumentError, "Key cannot be nil or empty" if key.nil? || key.empty?
    end
  end
end 