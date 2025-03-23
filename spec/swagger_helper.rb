require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.swagger_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under swagger_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a swagger_doc tag to the
  # the root example_group in your specs, e.g. describe '...', swagger_doc: 'v2/swagger.json'
  config.swagger_docs = {
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
              last_login_at: { type: 'string', format: 'date-time' },
              created_at: { type: 'string', format: 'date-time' }
            },
            required: ['id', 'nickname', 'phone_number']
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

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The swagger_docs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.swagger_format = :yaml
end
