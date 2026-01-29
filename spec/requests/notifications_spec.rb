require 'rails_helper'

RSpec.describe 'Notifications API', type: :request do
  let!(:user) { create(:user) }
  let(:auth_headers) { auth_headers_for(user) }

  # Helper method to parse JSON response
  def json_response
    JSON.parse(response.body)
  end

  # ===================================================================
  #   GET /api/v1/notifications - List notifications
  # ===================================================================
  describe 'GET /api/v1/notifications' do
    context 'with valid authentication' do
      let!(:notifications) { create_list(:notification, 3, user: user) }
      let!(:read_notification) { create(:notification, :read, user: user) }

      it 'returns notifications list with pagination' do
        get '/api/v1/notifications', headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key('notifications')
        expect(json_response).to have_key('pagination')
        expect(json_response).to have_key('unread_count')
        expect(json_response['notifications'].size).to eq(4)
      end

      it 'filters by read status' do
        get '/api/v1/notifications', params: { read: 'false' }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['notifications'].size).to eq(3)
      end

      it 'supports pagination' do
        get '/api/v1/notifications', params: { page: 1 }, headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['pagination']['current_page']).to eq(1)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/notifications'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   GET /api/v1/notifications/:id - Get a notification
  # ===================================================================
  describe 'GET /api/v1/notifications/:id' do
    context 'with valid authentication' do
      let!(:notification) { create(:notification, user: user) }

      it 'returns the notification' do
        get "/api/v1/notifications/#{notification.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(notification.id)
      end
    end

    context 'when notification does not exist' do
      it 'returns not found' do
        get '/api/v1/notifications/999999', headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when notification belongs to another user' do
      let!(:other_user) { create(:user) }
      let!(:other_notification) { create(:notification, user: other_user) }

      it 'returns not found' do
        get "/api/v1/notifications/#{other_notification.id}", headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      let!(:notification) { create(:notification, user: user) }

      it 'returns unauthorized' do
        get "/api/v1/notifications/#{notification.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   PATCH /api/v1/notifications/:id/mark_as_read - Mark notification as read
  # ===================================================================
  describe 'PATCH /api/v1/notifications/:id/mark_as_read' do
    context 'with valid authentication' do
      let!(:notification) { create(:notification, user: user, read: false) }

      it 'marks the notification as read' do
        patch "/api/v1/notifications/#{notification.id}/mark_as_read", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(notification.reload.read).to be true
      end
    end

    context 'when notification does not exist' do
      it 'returns not found' do
        patch '/api/v1/notifications/999999/mark_as_read', headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      let!(:notification) { create(:notification, user: user) }

      it 'returns unauthorized' do
        patch "/api/v1/notifications/#{notification.id}/mark_as_read"

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   PATCH /api/v1/notifications/mark_all_as_read - Mark all as read
  # ===================================================================
  describe 'PATCH /api/v1/notifications/mark_all_as_read' do
    context 'with valid authentication' do
      let!(:notifications) { create_list(:notification, 3, user: user, read: false) }

      it 'marks all notifications as read' do
        patch '/api/v1/notifications/mark_all_as_read', headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(json_response['unread_count']).to eq(0)
        expect(user.notifications.unread.count).to eq(0)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        patch '/api/v1/notifications/mark_all_as_read'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ===================================================================
  #   PATCH /api/v1/notifications/:id - Update notification (mark as read)
  # ===================================================================
  describe 'PATCH /api/v1/notifications/:id' do
    context 'with valid authentication' do
      let!(:notification) { create(:notification, user: user, read: false) }

      it 'updates the notification read status' do
        patch "/api/v1/notifications/#{notification.id}", headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['success']).to be true
        expect(notification.reload.read).to be true
      end
    end

    context 'when notification does not exist' do
      it 'returns not found' do
        patch '/api/v1/notifications/999999', headers: auth_headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ===================================================================
  #   GET /api/v1/notifications/unread_count - Get unread count
  # ===================================================================
  describe 'GET /api/v1/notifications/unread_count' do
    context 'with valid authentication' do
      let!(:unread_notifications) { create_list(:notification, 3, user: user, read: false) }
      let!(:read_notifications) { create_list(:notification, 2, user: user, read: true) }

      it 'returns the unread count' do
        get '/api/v1/notifications/unread_count', headers: auth_headers

        expect(response).to have_http_status(:ok)
        expect(json_response['unread_count']).to eq(3)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/notifications/unread_count'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
