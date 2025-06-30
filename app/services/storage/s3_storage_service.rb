# frozen_string_literal: true

require_relative "base_storage_service"

module Storage
  class S3StorageService < BaseStorageService
    attr_reader :bucket_name

    def initialize(bucket_name: ENV["S3_BUCKET_NAME"], region: ENV["AWS_REGION"])
      @bucket_name = bucket_name
      @region = region
      # 실제 구현에서는 aws-sdk-s3 클라이언트 초기화
      # @s3_client = Aws::S3::Client.new(region: @region)
    end

    def upload(file:, key:, content_type: nil)
      validate_file!(file)
      validate_key!(key)

      # 실제 S3 업로드 로직
      # @s3_client.put_object(
      #   bucket: @bucket_name,
      #   key: key,
      #   body: file.read,
      #   content_type: content_type
      # )

      # 개발용 모의 구현
      url(key: key)
    end

    def download(key:)
      validate_key!(key)

      # 실제 S3 다운로드 로직
      # response = @s3_client.get_object(bucket: @bucket_name, key: key)
      # response.body.read

      # 개발용 모의 구현
      "S3 content for #{key}"
    rescue => e
      nil
    end

    def delete(key:)
      validate_key!(key)

      # 실제 S3 삭제 로직
      # @s3_client.delete_object(bucket: @bucket_name, key: key)

      true
    rescue => e
      false
    end

    def exists?(key:)
      validate_key!(key)

      # 실제 S3 존재 확인 로직
      # @s3_client.head_object(bucket: @bucket_name, key: key)
      # true

      # 개발용 모의 구현
      true
    rescue => e
      false
    end

    def url(key:)
      validate_key!(key)
      "https://s3.amazonaws.com/#{@bucket_name}/#{key}"
    end

    # S3 특화 메서드
    def presigned_url(key:, expires_in: 3600)
      validate_key!(key)

      # 실제 presigned URL 생성 로직
      # signer = Aws::S3::Presigner.new(client: @s3_client)
      # signer.presigned_url(:get_object, bucket: @bucket_name, key: key, expires_in: expires_in)

      # 개발용 모의 구현
      "https://s3.amazonaws.com/#{@bucket_name}/#{key}?X-Amz-Expires=#{expires_in}"
    end

    def list_objects(prefix: nil)
      # 실제 S3 객체 목록 조회 로직
      # response = @s3_client.list_objects_v2(bucket: @bucket_name, prefix: prefix)
      # response.contents.map(&:key)

      # 개발용 모의 구현
      []
    end
  end
end

# 하위 호환성을 위한 alias
S3StorageService = Storage::S3StorageService
