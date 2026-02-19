require 'swagger_helper'

RSpec.describe 'Auth API', type: :request do
  # Shared test data
  let(:test_phone_number) { '01012345678' }
  let(:test_password) { 'password123' }
  let(:test_nickname) { '홍길동' }
  let(:test_code) { '123456' }

  path '/api/v1/auth/request_code' do
    post 'Requests authentication code' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              phone_number: { type: :string, example: '01012345678' }
            }
          }
        },
        required: [ 'user' ]
      }

      response '200', 'Authentication code sent' do
        schema type: :object,
          properties: {
            message: { type: :string },
            code: { type: :string },
            expires_at: { type: :string, format: 'date-time' },
            note: { type: :string }
          }

        let(:params) { { user: { phone_number: test_phone_number } } }
        run_test!
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { user: { phone_number: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/verify_code' do
    post 'Verifies authentication code' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              phone_number: { type: :string, example: '01012345678' },
              code: { type: :string, example: '123456' }
            }
          }
        },
        required: [ 'user' ]
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

        # Create phone verification with correct code (test env generates "123456")
        before do
          create(:phone_verification, phone_number: test_phone_number, code: test_code)
        end

        let(:params) { { user: { phone_number: test_phone_number, code: test_code } } }
        run_test!
      end

      response '400', 'Missing code parameter' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { user: { phone_number: test_phone_number, code: '' } } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/register' do
    post 'Register a new user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              phone_number: { type: :string, example: '01012345678' },
              password: { type: :string, example: 'password123' },
              nickname: { type: :string, example: '홍길동' },
              gender: { type: :integer, example: 1, description: '0: unknown, 1: male, 2: female' }
            }
          }
        },
        required: [ 'user' ]
      }

      response '201', 'User registered successfully' do
        schema type: :object,
          properties: {
            token: { type: :string },
            user: { '$ref' => '#/components/schemas/user' },
            message: { type: :string }
          }

        # Use a unique phone number for registration with password_confirmation
        let(:unique_phone) { "010#{rand(1000..9999)}#{rand(1000..9999)}" }
        let(:params) do
          {
            user: {
              phone_number: unique_phone,
              password: test_password,
              password_confirmation: test_password,
              nickname: test_nickname,
              gender: 1
            }
          }
        end
        run_test!
      end

      response '422', 'Invalid parameters or phone number is not verified' do
        schema '$ref' => '#/components/schemas/error_response'

        # Create existing user to trigger "already registered" error
        before do
          create(:user, phone_number: test_phone_number)
        end

        let(:params) do
          {
            user: {
              phone_number: test_phone_number,
              password: test_password,
              password_confirmation: test_password,
              nickname: test_nickname
            }
          }
        end
        run_test!
      end
    end
  end

  path '/api/v1/auth/login' do
    post 'Login a user' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          user: {
            type: :object,
            properties: {
              phone_number: { type: :string, example: '01012345678' },
              password: { type: :string, example: 'password123' }
            }
          }
        },
        required: [ 'user' ]
      }

      response '200', 'Login successful' do
        schema type: :object,
          properties: {
            token: { type: :string },
            user: { '$ref' => '#/components/schemas/user' },
            message: { type: :string }
          }

        # Create a user before testing login
        before do
          create(:user, phone_number: test_phone_number, password: test_password)
        end

        let(:params) { { user: { phone_number: test_phone_number, password: test_password } } }
        run_test!
      end

      response '401', 'Login failed' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { user: { phone_number: test_phone_number, password: 'wrong' } } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/check_phone' do
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

        let(:params) { { phone_number: test_phone_number } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/resend_code' do
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

        # Create an old phone verification to allow resend (beyond rate limit window)
        before do
          verification = create(:phone_verification, phone_number: test_phone_number)
          # Force update timestamps to be 2 minutes ago to bypass rate limiting
          verification.update_columns(created_at: 2.minutes.ago, updated_at: 2.minutes.ago)
        end

        let(:params) { { phone_number: test_phone_number } }
        run_test!
      end

      response '400', 'Bad request' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { phone_number: '' } }
        run_test!
      end
    end
  end

  path '/api/v1/auth/logout' do
    post 'Logout a user' do
      tags 'Authentication'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Logout successful' do
        schema type: :object,
          properties: {
            message: { type: :string }
          }

        let(:user) { create(:user) }
        let(:Authorization) { auth_headers_for(user)["Authorization"] }
        run_test!
      end
    end
  end
end
