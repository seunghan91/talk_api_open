# frozen_string_literal: true

require_relative 'base_storage_service'

module Storage
  class LocalStorageService < BaseStorageService
    def initialize(base_path: Rails.root.join('public', 'uploads'))
      @base_path = base_path
    end
    
    def upload(file:, key:, content_type: nil)
      validate_file!(file)
      validate_key!(key)
      
      path = File.join(@base_path, key)
      FileUtils.mkdir_p(File.dirname(path))
      
      File.open(path, 'wb') do |f|
        f.write(file.read)
      end
      
      url(key: key)
    end
    
    def download(key:)
      validate_key!(key)
      
      path = File.join(@base_path, key)
      return nil unless File.exist?(path)
      
      File.read(path)
    end
    
    def delete(key:)
      validate_key!(key)
      
      path = File.join(@base_path, key)
      return false unless File.exist?(path)
      
      File.delete(path)
      true
    end
    
    def exists?(key:)
      validate_key!(key)
      
      path = File.join(@base_path, key)
      File.exist?(path)
    end
    
    def url(key:)
      validate_key!(key)
      "/uploads/#{key}"
    end
    
    # LocalStorageService 특화 메서드
    def cleanup_old_files(older_than: 7.days.ago)
      Dir.glob(File.join(@base_path, '**/*')).each do |file|
        next unless File.file?(file)
        next unless File.mtime(file) < older_than
        
        File.delete(file)
      end
    end
    
    def storage_size
      total_size = 0
      Dir.glob(File.join(@base_path, '**/*')).each do |file|
        total_size += File.size(file) if File.file?(file)
      end
      total_size
    end
  end
end

# 하위 호환성을 위한 alias
LocalStorageService = Storage::LocalStorageService 