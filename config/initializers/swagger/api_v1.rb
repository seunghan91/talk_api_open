module Swagger
  module ApiV1
    class << self
      def swagger_docs
        {
          'v1/swagger.json' => {
            openapi: '3.0.0',
            info: {
              title: 'TALKK API',
              version: 'v1',
              description: 'TALKK 앱의 API 문서입니다.'
            },
            servers: [
              {
                url: 'https://talkk-api.onrender.com',
                description: '운영 서버'
              },
              {
                url: 'http://localhost:3000',
                description: '로컬 개발 서버'
              }
            ],
            consumes: ['application/json'],
            produces: ['application/json'],
            components: {
              securitySchemes: {
                bearerAuth: {
                  type: :http,
                  scheme: :bearer,
                  bearerFormat: 'JWT'
                }
              },
              schemas: {
                User: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    phone_number: { type: :string },
                    nickname: { type: :string },
                    gender: { type: :string, enum: ['male', 'female', 'unspecified'] },
                    created_at: { type: :string, format: :datetime },
                    updated_at: { type: :string, format: :datetime }
                  },
                  required: ['id', 'phone_number', 'nickname']
                },
                Broadcast: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    content: { type: :string },
                    user_id: { type: :integer },
                    expired_at: { type: :string, format: :datetime },
                    created_at: { type: :string, format: :datetime },
                    updated_at: { type: :string, format: :datetime }
                  },
                  required: ['id', 'content', 'user_id']
                },
                Conversation: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    user: { '$ref' => '#/components/schemas/User' },
                    last_message: { '$ref' => '#/components/schemas/Message' },
                    is_favorite: { type: :boolean },
                    unread_count: { type: :integer }
                  },
                  required: ['id', 'user']
                },
                Message: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    content: { type: :string },
                    user_id: { type: :integer },
                    conversation_id: { type: :integer },
                    is_read: { type: :boolean },
                    created_at: { type: :string, format: :datetime },
                    updated_at: { type: :string, format: :datetime }
                  },
                  required: ['id', 'content', 'user_id', 'conversation_id']
                },
                Wallet: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    user_id: { type: :integer },
                    balance: { type: :number, format: :float },
                    transaction_count: { type: :integer },
                    created_at: { type: :string, format: :datetime },
                    updated_at: { type: :string, format: :datetime }
                  },
                  required: ['id', 'user_id', 'balance']
                },
                Transaction: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    wallet_id: { type: :integer },
                    amount: { type: :number, format: :float },
                    transaction_type: { type: :string, enum: ['deposit', 'withdrawal', 'transfer'] },
                    description: { type: :string },
                    status: { type: :string, enum: ['pending', 'completed', 'failed'] },
                    created_at: { type: :string, format: :datetime },
                    updated_at: { type: :string, format: :datetime }
                  },
                  required: ['id', 'wallet_id', 'amount', 'transaction_type', 'status']
                },
                Error: {
                  type: :object,
                  properties: {
                    error: { type: :string },
                    code: { type: :string }
                  },
                  required: ['error']
                }
              }
            },
            security: [
              { bearerAuth: [] }
            ],
            paths: {
              # 경로는 각 컨트롤러의 swagger 주석에서 자동으로 생성됩니다.
            }
          }
        }
      end
    end
  end
end 