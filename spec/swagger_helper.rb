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
            phone_number: { type: :string },
            code: { type: :string },
            message: { type: :string },
            verification_id: { type: :integer }
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

      response '200', 'Authentication successful' do
        schema type: :object,
          properties: {
            message: { type: :string },
            token: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                phone_number: { type: :string },
                verified: { type: :boolean },
                gender: { type: :string }
              }
            }
          }

        let(:params) { { phone_number: '01012345678', code: '123456' } }
        run_test!
      end

      response '401', 'Authentication failed' do
        schema '$ref' => '#/components/schemas/error_response'

        let(:params) { { phone_number: '01012345678', code: 'wrong' } }
        run_test!
      end
    end
  end
end
