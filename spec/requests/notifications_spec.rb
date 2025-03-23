require 'swagger_helper'

RSpec.describe 'Notifications API', type: :request do
  path '/api/notifications' do
    get 'List notifications' do
      tags 'Notifications'
      security [ bearer_auth: [] ]
      produces 'application/json'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'

      response '200', 'Notifications fetched successfully' do
        schema type: :object,
          properties: {
            notifications: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  user_id: { type: :integer },
                  notification_type: { type: :string },
                  title: { type: :string, nullable: true },
                  body: { type: :string },
                  read: { type: :boolean },
                  metadata: { type: :object },
                  created_at: { type: :string, format: 'date-time' }
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
            },
            unread_count: { type: :integer }
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

  path '/api/notifications/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Notification ID'

    get 'Get a notification' do
      tags 'Notifications'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Notification fetched successfully' do
        schema type: :object,
          properties: {
            notification: {
              type: :object,
              properties: {
                id: { type: :integer },
                user_id: { type: :integer },
                notification_type: { type: :string },
                title: { type: :string, nullable: true },
                body: { type: :string },
                read: { type: :boolean },
                metadata: { type: :object },
                created_at: { type: :string, format: 'date-time' }
              }
            }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '404', 'Notification not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end

  path '/api/notifications/{id}/mark_as_read' do
    parameter name: :id, in: :path, type: :integer, description: 'Notification ID'

    post 'Mark notification as read' do
      tags 'Notifications'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'Notification marked as read' do
        schema type: :object,
          properties: {
            message: { type: :string },
            notification: {
              type: :object,
              properties: {
                id: { type: :integer },
                read: { type: :boolean }
              }
            }
          }

        let(:id) { '1' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end

      response '404', 'Notification not found' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:id) { '999' }
        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end

  path '/api/notifications/mark_all_as_read' do
    post 'Mark all notifications as read' do
      tags 'Notifications'
      security [ bearer_auth: [] ]
      produces 'application/json'

      response '200', 'All notifications marked as read' do
        schema type: :object,
          properties: {
            message: { type: :string },
            count: { type: :integer }
          }

        let(:Authorization) { "Bearer token" }
        run_test!
      end
    end
  end

  path '/api/notifications/update_push_token' do
    post 'Update push notification token' do
      tags 'Notifications'
      security [ bearer_auth: [] ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :params, in: :body, schema: {
        type: :object,
        properties: {
          push_token: { type: :string, example: 'ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]' },
          device_id: { type: :string, example: 'device-uuid-123' }
        },
        required: [ 'push_token' ]
      }

      response '200', 'Push token updated successfully' do
        schema type: :object,
          properties: {
            message: { type: :string }
          }

        let(:Authorization) { "Bearer token" }
        let(:params) { { push_token: 'ExponentPushToken[xxxxxxxxxxxxxxxxxxxxxx]', device_id: 'device-uuid-123' } }
        run_test!
      end

      response '422', 'Invalid parameters' do
        schema '$ref' => '#/components/schemas/error_response'
        let(:Authorization) { "Bearer token" }
        let(:params) { { push_token: '' } }
        run_test!
      end
    end
  end

  path '/api/notifications/settings' do
    get 'Get notification settings' do
      tags 'Notifications'
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
  end

  path '/api/notifications/update_settings' do
    post 'Update notification settings' do
      tags 'Notifications'
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
            message: { type: :string },
            settings: {
              type: :object,
              properties: {
                push_enabled: { type: :boolean },
                broadcast_push_enabled: { type: :boolean },
                message_push_enabled: { type: :boolean }
              }
            }
          }

        let(:Authorization) { "Bearer token" }
        let(:params) { { push_enabled: true, broadcast_push_enabled: false, message_push_enabled: true } }
        run_test!
      end
    end
  end
end 