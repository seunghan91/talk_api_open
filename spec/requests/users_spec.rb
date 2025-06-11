require 'swagger_helper'

RSpec.describe 'Users API', type: :request do
  path '/api/users/profile' do
    get 'Get user profile' do
      tags 'Users'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Profile fetched successfully' do
        schema type: :object,
          properties: {
            id: { type: :integer },
            nickname: { type: :string },
            phone_number: { type: :string },
            last_login_at: { type: :string, format: 'date-time' },
            created_at: { type: :string, format: 'date-time' }
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

  path '/api/users/me' do
    get 'Get current user information' do
      tags 'Users'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Current user information fetched successfully' do
        schema type: :object,
          properties: {
            user: { '$ref' => '#/components/schemas/user' }
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

  path '/api/users/change_password' do
    post 'Change user password' do
      tags 'Users'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          current_password: { type: :string, example: 'current123' },
          new_password: { type: :string, example: 'new123' },
          new_password_confirmation: { type: :string, example: 'new123' }
        },
        required: [ 'current_password', 'new_password', 'new_password_confirmation' ]
      }

      response '200', 'Password changed successfully' do
        schema type: :object,
          properties: {
            message: { type: :string }
          }

        let(:Authorization) { "Bearer token" }
        let(:params) { { current_password: 'current123', new_password: 'new123', new_password_confirmation: 'new123' } }
        run_test!
      end

      response '422', 'Invalid parameters' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer token" }
        let(:params) { { current_password: 'wrong', new_password: 'new123', new_password_confirmation: 'different' } }
        run_test!
      end
    end
  end

  path '/api/users/notification_settings' do
    get 'Get notification settings' do
      tags 'Users'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Notification settings fetched successfully' do
        schema type: :object,
          properties: {
            push_enabled: { type: :boolean },
            broadcast_push_enabled: { type: :boolean },
            message_push_enabled: { type: :boolean }
          }

        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end

    put 'Update notification settings' do
      tags 'Users'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          push_enabled: { type: :boolean },
          broadcast_push_enabled: { type: :boolean },
          message_push_enabled: { type: :boolean }
        }
      }

      response '200', 'Notification settings updated successfully' do
        schema type: :object,
          properties: {
            push_enabled: { type: :boolean },
            broadcast_push_enabled: { type: :boolean },
            message_push_enabled: { type: :boolean },
            message: { type: :string }
          }

        let(:Authorization) { "Bearer token" }
        let(:params) { { push_enabled: true, broadcast_push_enabled: false, message_push_enabled: true } }
        run_test!
      end
    end
  end

  path '/api/users/change_nickname' do
    post 'Change user nickname' do
      tags 'Users'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          nickname: { type: :string, example: '새닉네임' }
        },
        required: [ 'nickname' ]
      }

      response '200', 'Nickname changed successfully' do
        schema type: :object,
          properties: {
            message: { type: :string },
            nickname: { type: :string }
          }

        let(:Authorization) { "Bearer token" }
        let(:params) { { nickname: '새닉네임' } }
        run_test!
      end

      response '422', 'Invalid nickname' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer token" }
        let(:params) { { nickname: '' } }
        run_test!
      end
    end
  end

  path '/api/users/generate_random_nickname' do
    get 'Generate a random nickname' do
      tags 'Users'
      produces 'application/json'

      response '200', 'Random nickname generated successfully' do
        schema type: :object,
          properties: {
            nickname: { type: :string }
          }

        run_test!
      end
    end
  end

  path '/api/users/update_profile' do
    post 'Update user profile' do
      tags 'Users'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          nickname: { type: :string, example: '새닉네임' },
          gender: { type: :integer, example: 1 }
        }
      }

      response '200', 'Profile updated successfully' do
        schema type: :object,
          properties: {
            message: { type: :string },
            user: { '$ref' => '#/components/schemas/user' }
          }

        let(:Authorization) { "Bearer token" }
        let(:params) { { nickname: '새닉네임', gender: 1 } }
        run_test!
      end

      response '422', 'Invalid parameters' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer token" }
        let(:params) { { nickname: '' } }
        run_test!
      end
    end
  end
end
