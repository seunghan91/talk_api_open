# frozen_string_literal: true

require_relative "base_storage_service"

module Storage
  class MemoryStorageService < BaseStorageService
    def initialize
      @storage = {}
    end

    def upload(file:, key:, content_type: nil)
      validate_file!(file)
      validate_key!(key)

      @storage[key] = {
        content: file.read,
        content_type: content_type,
        uploaded_at: Time.current
      }

      url(key: key)
    end

    def download(key:)
      validate_key!(key)

      return nil unless @storage.key?(key)
      @storage[key][:content]
    end

    def delete(key:)
      validate_key!(key)

      return false unless @storage.key?(key)
      @storage.delete(key)
      true
    end

    def exists?(key:)
      validate_key!(key)
      @storage.key?(key)
    end

    def url(key:)
      validate_key!(key)
      "memory://#{key}"
    end

    # 테스트용 특화 메서드
    def clear!
      @storage.clear
    end

    def storage_size
      @storage.values.sum { |item| item[:content].bytesize }
    end

    def keys
      @storage.keys
    end

    def inspect_storage
      @storage.transform_values do |item|
        {
          size: item[:content].bytesize,
          content_type: item[:content_type],
          uploaded_at: item[:uploaded_at]
        }
      end
    end
  end
end

# 하위 호환성을 위한 alias
MemoryStorageService = Storage::MemoryStorageService
