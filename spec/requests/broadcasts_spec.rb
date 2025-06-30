require 'swagger_helper'

RSpec.describe 'Broadcasts API', type: :request do
  let(:user) { create(:user) }
  let(:valid_token) { generate_token_for(user) }
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
                  user_id: { type: :integer },
                  text: { type: :string },
                  audio_url: { type: :string },
                  expired_at: { type: :string, format: 'date-time' },
                  created_at: { type: :string, format: 'date-time' },
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      nickname: { type: :string },
                      profile_image: { type: :string, nullable: true }
                    }
                  }
                }
              }
            },
            pagination: {
              type: :object,
              properties: {
                current_page: { type: :integer },
                total_pages: { type: :integer },
                total_count: { type: :integer }
              }
            }
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
      parameter name: :text, in: :formData, type: :string, description: 'Broadcast text'
      parameter name: :audio, in: :formData, type: :file, description: 'Audio file'

      response '201', 'Broadcast created successfully' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            user_id: { type: :integer },
            text: { type: :string },
            audio_url: { type: :string },
            expired_at: { type: :string, format: 'date-time' },
            created_at: { type: :string, format: 'date-time' }
          }

        let(:Authorization) { "Bearer #{valid_token}" }
        let(:text) { '안녕하세요!' }
        let(:audio) { fixture_file_upload('spec/fixtures/files/sample_audio.wav', 'audio/wav') }
        run_test!
      end

      response '422', 'Invalid parameters' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer #{valid_token}" }
        let(:text) { '안녕하세요!' }
        let(:audio) { nil }
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
                user_id: { type: :integer },
                text: { type: :string },
                audio_url: { type: :string },
                expired_at: { type: :string, format: 'date-time' },
                created_at: { type: :string, format: 'date-time' },
                user: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    nickname: { type: :string },
                    profile_image: { type: :string, nullable: true }
                  }
                }
              }
            }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end

      response '404', 'Broadcast not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer #{valid_token}" }
        run_test!
      end
    end
  end

  path '/api/v1/broadcasts/{id}/reply' do
    parameter name: :id, in: :path, type: :integer, description: 'Broadcast ID'

    post 'Reply to a broadcast' do
      tags 'Broadcasts'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          message: { type: :string, example: '반갑습니다!' }
        },
        required: [ 'message' ]
      }

      response '201', 'Reply sent successfully' do
        schema type: :object,
          properties: {
            message: { type: :string },
            conversation_id: { type: :integer }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer #{valid_token}" }
        let(:params) { { message: '반갑습니다!' } }
        run_test!
      end

      response '404', 'Broadcast not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer #{valid_token}" }
        let(:params) { { message: '반갑습니다!' } }
        run_test!
      end
    end
  end
end
