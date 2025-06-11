require 'swagger_helper'

RSpec.describe 'Auth API', type: :request do
  path '/api/auth/request_code' do
    post 'Requests authentication code' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '01012345678' }
        },
        required: [ 'phone_number' ]
      }

      response '200', 'Authentication code sent' do
        schema type: :object,
          properties: {
            message: { type: :string },
            code: { type: :string },
            expires_at: { type: :string, format: 'date-time' },
            note: { type: :string }
          }

        let(:params) { { phone_number: '01012345678' } }
        run_test!
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { phone_number: '' } }
        run_test!
      end
    end
  end

  path '/api/auth/verify_code' do
    post 'Verifies authentication code' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '01012345678' },
          code: { type: :string, example: '123456' }
        },
        required: [ 'phone_number', 'code' ]
      }

      response '200', 'Authentication code verified successfully' do
        schema type: :object,
          properties: {
            message: { type: :string },
            user_exists: { type: :boolean },
            can_proceed_to_register: { type: :boolean },
            user: {
              type: :object,
              nullable: true,
              properties: {
                id: { type: :integer },
                nickname: { type: :string }
              }
            },
            verification_status: {
              type: :object,
              properties: {
                verified: { type: :boolean },
                verified_at: { type: :string, format: 'date-time' },
                phone_number: { type: :string }
              }
            }
          }

        let(:params) { { phone_number: '01012345678', code: '123456' } }
        run_test!
      end

      response '400', 'Invalid authentication code' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { phone_number: '01012345678', code: 'wrong' } }
        run_test!
      end
    end
  end

  path '/api/auth/register' do
    post 'Register a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '01012345678' },
          password: { type: :string, example: 'password123' },
          nickname: { type: :string, example: '홍길동' },
          gender: { type: :integer, example: 1, description: '0: unknown, 1: male, 2: female' }
        },
        required: [ 'phone_number', 'password', 'nickname' ]
      }

      response '201', 'User registered successfully' do
        schema type: :object,
          properties: {
            token: { type: :string },
            user: { '$ref' => '#/components/schemas/user' },
            message: { type: :string }
          }

        let(:params) { { phone_number: '01012345678', password: 'password123', nickname: '홍길동', gender: 1 } }
        run_test!
      end

      response '422', 'Invalid parameters or phone number is not verified' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { phone_number: '01012345678', password: 'pwd', nickname: '' } }
        run_test!
      end
    end
  end

  path '/api/auth/login' do
    post 'Login a user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '01012345678' },
          password: { type: :string, example: 'password123' }
        },
        required: [ 'phone_number', 'password' ]
      }

      response '200', 'Login successful' do
        schema type: :object,
          properties: {
            token: { type: :string },
            user: { '$ref' => '#/components/schemas/user' },
            message: { type: :string }
          }

        let(:params) { { phone_number: '01012345678', password: 'password123' } }
        run_test!
      end

      response '401', 'Login failed' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { phone_number: '01012345678', password: 'wrong' } }
        run_test!
      end
    end
  end

  path '/api/auth/check_phone' do
    post 'Check if phone number exists' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '01012345678' }
        },
        required: [ 'phone_number' ]
      }

      response '200', 'Phone number checked' do
        schema type: :object,
          properties: {
            exists: { type: :boolean },
            message: { type: :string }
          }

        let(:params) { { phone_number: '01012345678' } }
        run_test!
      end
    end
  end

  path '/api/auth/resend_code' do
    post 'Resend authentication code' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          phone_number: { type: :string, example: '01012345678' }
        },
        required: [ 'phone_number' ]
      }

      response '200', 'Authentication code resent' do
        schema type: :object,
          properties: {
            message: { type: :string },
            code: { type: :string },
            expires_at: { type: :string, format: 'date-time' },
            note: { type: :string }
          }

        let(:params) { { phone_number: '01012345678' } }
        run_test!
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { phone_number: '' } }
        run_test!
      end
    end
  end

  path '/api/auth/logout' do
    post 'Logout a user' do
      tags 'Authentication'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Logout successful' do
        schema type: :object,
          properties: {
            message: { type: :string }
          }

        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end
end
