require 'swagger_helper'

RSpec.describe 'Conversations API', type: :request do
  path '/api/conversations' do
    get 'List conversations' do
      tags 'Conversations'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Conversations fetched successfully' do
        schema type: :object,
          properties: {
            conversations: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  with_user: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      nickname: { type: :string },
                      profile_image: { type: :string, nullable: true }
                    }
                  },
                  last_message: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      text: { type: :string },
                      sender_id: { type: :integer },
                      voice_url: { type: :string, nullable: true },
                      created_at: { type: :string, format: 'date-time' }
                    }
                  },
                  unread_count: { type: :integer },
                  favorited: { type: :boolean },
                  updated_at: { type: :string, format: 'date-time' }
                }
              }
            },
            request_id: { type: :string }
          }

        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end
  end

  path '/api/conversations/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Conversation ID'

    get 'Get a conversation with messages' do
      tags 'Conversations'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Conversation fetched successfully' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            with_user: {
              type: :object,
              properties: {
                id: { type: :integer },
                nickname: { type: :string },
                profile_image: { type: :string, nullable: true }
              }
            },
            messages: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  text: { type: :string },
                  sender_id: { type: :integer },
                  voice_url: { type: :string, nullable: true },
                  created_at: { type: :string, format: 'date-time' },
                  read: { type: :boolean }
                }
              }
            },
            favorited: { type: :boolean },
            request_id: { type: :string }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end

    delete 'Delete a conversation' do
      tags 'Conversations'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Conversation deleted successfully' do
        schema type: :object,
          properties: {
            message: { type: :string }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end

  path '/api/conversations/{id}/favorite' do
    parameter name: :id, in: :path, type: :integer, description: 'Conversation ID'

    post 'Mark conversation as favorite' do
      tags 'Conversations'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Conversation marked as favorite' do
        schema type: :object,
          properties: {
            message: { type: :string },
            favorited: { type: :boolean }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end

  path '/api/conversations/{id}/unfavorite' do
    parameter name: :id, in: :path, type: :integer, description: 'Conversation ID'

    post 'Remove conversation from favorites' do
      tags 'Conversations'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Conversation removed from favorites' do
        schema type: :object,
          properties: {
            message: { type: :string },
            favorited: { type: :boolean }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end

  path '/api/conversations/{id}/send_message' do
    parameter name: :id, in: :path, type: :integer, description: 'Conversation ID'

    post 'Send a message in the conversation' do
      tags 'Conversations'
      security [ bearer_auth: [] ]
      consumes 'multipart/form-data'
      produces 'application/json'
      parameter name: :text, in: :formData, type: :string, description: 'Message text'
      parameter name: :voice_file, in: :formData, type: :file, description: 'Voice file (optional)'

      response '201', 'Message sent successfully' do
        schema type: :object,
          properties: {
            message: {
              type: :object,
              properties: {
                id: { type: :integer },
                sender_id: { type: :integer },
                text: { type: :string },
                voice_url: { type: :string, nullable: true },
                created_at: { type: :string, format: 'date-time' }
              }
            }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer token" }
        let(:text) { '안녕하세요!' }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer token" }
        let(:text) { '안녕하세요!' }
        run_test!
      end
    end
  end
end 