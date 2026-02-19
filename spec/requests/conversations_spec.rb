require 'swagger_helper'

RSpec.describe 'Conversations API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:valid_headers) { auth_headers_for(user) }

  # Create a conversation between user and other_user
  let!(:conversation) do
    create(:conversation, user_a: user, user_b: other_user)
  end

  # Create a message in the conversation
  let!(:message) do
    create(:message, conversation: conversation, sender: other_user)
  end

  path '/api/v1/conversations' do
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
                      text: { type: :string, nullable: true },
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

        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end
  end

  path '/api/v1/conversations/{id}' do
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
                  text: { type: :string, nullable: true },
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

        let(:id) { conversation.id }
        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 999999 }
        let(:Authorization) { valid_headers["Authorization"] }
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

        let(:id) { conversation.id }
        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 999999 }
        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end
    end
  end

  path '/api/v1/conversations/{id}/favorite' do
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

        let(:id) { conversation.id }
        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 999999 }
        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end
    end
  end

  path '/api/v1/conversations/{id}/unfavorite' do
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

        let(:id) { conversation.id }
        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 999999 }
        let(:Authorization) { valid_headers["Authorization"] }
        run_test!
      end
    end
  end

  path '/api/v1/conversations/{id}/send_message' do
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
                text: { type: :string, nullable: true },
                voice_url: { type: :string, nullable: true },
                created_at: { type: :string, format: 'date-time' }
              }
            }
          }

        let(:id) { conversation.id }
        let(:Authorization) { valid_headers["Authorization"] }
        let(:text) { nil }
        let(:voice_file) { fixture_file_upload('spec/fixtures/files/sample_audio.wav', 'audio/wav') }
        run_test!
      end

      response '404', 'Conversation not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 999999 }
        let(:Authorization) { valid_headers["Authorization"] }
        let(:text) { nil }
        let(:voice_file) { fixture_file_upload('spec/fixtures/files/sample_audio.wav', 'audio/wav') }
        run_test!
      end
    end
  end
end
