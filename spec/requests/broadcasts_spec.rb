require 'swagger_helper'

RSpec.describe 'Broadcasts API', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:valid_token) { generate_token_for(user) }

  # Create a broadcast from another user for testing show/reply endpoints
  let!(:broadcast) do
    create(:broadcast, user: other_user)
  end

  # Make current user a recipient of the broadcast
  let!(:broadcast_recipient) do
    create(:broadcast_recipient, broadcast: broadcast, user: user)
  end

  path '/api/v1/broadcasts' do
    get 'List broadcasts' do
      tags 'Broadcasts'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Broadcasts fetched successfully' do
        schema type: :object,
          properties: {
            broadcasts: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  content: { type: :string, nullable: true },
                  audio_url: { type: :string, nullable: true },
                  sender: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      nickname: { type: :string }
                    }
                  },
                  created_at: { type: :string, format: 'date-time' }
                }
              }
            },
            filter: { type: :string },
            request_id: { type: :string }
          }

        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end

      response '401', 'Unauthorized' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer invalid_token" }
        run_test!
      end
    end

    post 'Create a broadcast' do
      tags 'Broadcasts'
      security [ bearer_auth: [] ]
      consumes 'multipart/form-data'
      produces 'application/json'
      parameter name: 'broadcast[content]', in: :formData, type: :string, description: 'Broadcast content'
      parameter name: 'broadcast[voice_file]', in: :formData, type: :file, description: 'Voice file'
      parameter name: 'broadcast[recipient_count]', in: :formData, type: :integer, description: 'Recipient count'

      response '400', 'Invalid parameters - missing voice file' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer #{valid_token}" }
        let(:'broadcast[content]') { 'Test broadcast' }
        let(:'broadcast[voice_file]') { nil }
        let(:'broadcast[recipient_count]') { 5 }

        run_test!
      end
    end
  end

  path '/api/v1/broadcasts/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Broadcast ID'

    get 'Get a broadcast' do
      tags 'Broadcasts'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Broadcast fetched successfully' do
        schema type: :object,
          properties: {
            broadcast: {
              type: :object,
              properties: {
                id: { type: :integer },
                content: { type: :string, nullable: true },
                audio_url: { type: :string, nullable: true },
                sender: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    nickname: { type: :string }
                  }
                },
                created_at: { type: :string, format: 'date-time' },
                status: { type: :string, nullable: true }
              }
            },
            request_id: { type: :string }
          }

        let(:id) { broadcast.id }
        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end

      response '404', 'Broadcast not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { 999999 }
        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end
    end
  end
end
