require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where OpenAPI JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve OpenAPI specs from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more OpenAPI documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete OpenAPI spec will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding an openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.yaml'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Talk API',
        version: 'v1',
        description: 'API 문서',
        contact: {
          name: 'API Support',
          email: 'support@example.com'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        },
        {
          url: 'https://talkk-api.onrender.com',
          description: 'Production server'
        }
      ],
      components: {
        schemas: {
          error_response: {
            type: 'object',
            properties: {
              error: { type: 'string' }
            }
          },
          user: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              nickname: { type: 'string' },
              phone_number: { type: 'string' },
              gender: { type: 'string', enum: [ 'male', 'female', 'unknown' ] },
              age_group: { type: 'string', enum: [ '20s', '30s', '40s', '50s' ], nullable: true },
              region: { type: 'string', nullable: true, description: '사용자 지역 정보 (국가/시도 형식)' },
              blocked: { type: 'boolean', description: '계정 정지/차단 상태' },
              warning_count: { type: 'integer', description: '누적 경고 횟수' },
              profile_completed: { type: 'boolean', description: '프로필 완성도 상태' },
              last_login_at: { type: 'string', format: 'date-time' },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: [ 'id', 'nickname', 'phone_number' ]
          },
          broadcast: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              user_id: { type: 'integer' },
              audio_url: { type: 'string' },
              duration: { type: 'integer' },
              private: { type: 'boolean' },
              expired_at: { type: 'string', format: 'date-time' },
              created_at: { type: 'string', format: 'date-time' },
              user: { '$ref': '#/components/schemas/user' }
            },
            required: [ 'id', 'user_id', 'audio_url' ]
          },
          message: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              conversation_id: { type: 'integer' },
              sender_id: { type: 'integer' },
              receiver_id: { type: 'integer' },
              broadcast_id: { type: 'integer' },
              message_type: { type: 'string', enum: [ 'voice' ] },
              audio_url: { type: 'string' },
              duration: { type: 'integer' },
              is_read: { type: 'boolean' },
              created_at: { type: 'string', format: 'date-time' },
              sender: { '$ref': '#/components/schemas/user' }
            },
            required: [ 'id', 'conversation_id', 'sender_id', 'message_type' ]
          },
          conversation: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              user_a_id: { type: 'integer' },
              user_b_id: { type: 'integer' },
              last_message_at: { type: 'string', format: 'date-time' },
              created_at: { type: 'string', format: 'date-time' },
              user_a: { '$ref': '#/components/schemas/user' },
              user_b: { '$ref': '#/components/schemas/user' },
              favorited_by_user_a: { type: 'boolean' },
              favorited_by_user_b: { type: 'boolean' }
            },
            required: [ 'id', 'user_a_id', 'user_b_id' ]
          },
          notification: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              user_id: { type: 'integer' },
              title: { type: 'string' },
              body: { type: 'string' },
              notification_type: { type: 'string', enum: [ 'broadcast', 'message', 'system', 'account_warning', 'account_suspension', 'suspension_ended' ] },
              read: { type: 'boolean' },
              metadata: { type: 'object' },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: [ 'id', 'user_id', 'notification_type' ]
          },
          report: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              reporter_id: { type: 'integer' },
              reported_id: { type: 'integer' },
              report_type: { type: 'string', enum: [ 'user', 'broadcast', 'message' ] },
              reason: { type: 'string', enum: [ 'gender_impersonation', 'inappropriate_content', 'spam', 'harassment', 'other' ] },
              status: { type: 'string', enum: [ 'pending', 'processing', 'resolved', 'rejected' ] },
              related_id: { type: 'integer', nullable: true, description: '관련 브로드캐스트/메시지 ID' },
              created_at: { type: 'string', format: 'date-time' },
              updated_at: { type: 'string', format: 'date-time' },
              reporter: { '$ref': '#/components/schemas/user' },
              reported: { '$ref': '#/components/schemas/user' }
            },
            required: [ 'id', 'reporter_id', 'reported_id', 'report_type', 'reason', 'status' ]
          },
          user_suspension: {
            type: 'object',
            properties: {
              id: { type: 'integer' },
              user_id: { type: 'integer' },
              reason: { type: 'string' },
              suspended_at: { type: 'string', format: 'date-time' },
              suspended_until: { type: 'string', format: 'date-time' },
              suspended_by: { type: 'string' },
              active: { type: 'boolean' },
              created_at: { type: 'string', format: 'date-time' },
              updated_at: { type: 'string', format: 'date-time' },
              user: { '$ref': '#/components/schemas/user' }
            },
            required: [ 'id', 'user_id', 'reason', 'suspended_at', 'suspended_until' ]
          }
        },
        securitySchemes: {
          bearer_auth: {
            type: 'http',
            scheme: 'bearer',
            bearerFormat: 'JWT'
          }
        }
      }
    }
  }

  # Specify the format of the output OpenAPI file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
