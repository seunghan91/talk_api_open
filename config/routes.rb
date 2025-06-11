require "sidekiq/web"

Rails.application.routes.draw do
  # Swagger API 문서화 엔진 마운트
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  # 사이드킥(Sidekiq) 관리자 UI
  mount Sidekiq::Web => "/sidekiq"

  # 헬스 체크 엔드포인트
  get "/api/health_check", to: "health_check#index"
  get "/health", to: "health_check#index"
  get "/health/worker", to: "health_check#worker_status"
  get "/health/conversations", to: "health_check#conversations_check"

  # 1) 웹용 루트
  root "pages#home"
  get "purchases/create"
  get "purchases/index"

  # 관리자 분석 대시보드
  namespace :admin do
    get "analytics", to: "analytics#index"
    get "analytics/daily", to: "analytics#daily"
    get "analytics/weekly", to: "analytics#weekly"
    get "analytics/monthly", to: "analytics#monthly"
  end

  # 2) API - 표준화된 v1 네임스페이스 사용
  namespace :api do
    get "test/index"
    namespace :v1 do
      # 공지사항 관련 API
      resources :announcement_categories, only: [ :index, :create, :update, :destroy ]
      resources :announcements, only: [ :index, :show, :create, :update, :destroy ]

      # 인증 관련 API
      post "auth/request_code"
      post "auth/verify_code"
      post "auth/resend_code"
      post "auth/register"
      post "auth/login"
      post "auth/logout"
      post "auth/reset_password"
      post "auth/check_phone"

      # 사용자 관련 API
      get "users/me"
      get "users/profile"
      get "users/:id", to: "users#show"
      patch "users/me", to: "users#update"
      put "users/me", to: "users#update"
      post "users/change_password"
      get "users/notification_settings"
      patch "users/notification_settings", to: "users#update_notification_settings"
      put "users/notification_settings", to: "users#update_notification_settings"

      # 브로드캐스트 관련 API
      resources :broadcasts, only: [ :index, :show, :create ] do
        collection do
          get :received
        end
        member do
          post :reply
          patch :mark_as_read
        end
      end

      # 대화 관련 API
      resources :conversations, only: [ :index, :show, :destroy ] do
        member do
          post :send_message
          post :favorite
          post :unfavorite
          post :close
        end
      end

      # 알림 관련 API
      resources :notifications, only: [ :index, :show, :update ] do
        collection do
          put :mark_all_as_read
          get :unread_count
        end
      end

      # 설정 관련 API
      resources :settings, only: [] do
        collection do
          get :notification_settings
          put :update_notification_settings
          patch :update_notification_settings
        end
      end

      # 지갑 관련 API
      resources :wallets, only: [ :show ] do
        collection do
          get :my_wallet
          post :transfer
        end
      end
    end

    # API 버전 2를 위한 네임스페이스 (향후 확장용)
    namespace :v2 do
      # 향후 API v2 엔드포인트가 여기에 추가됩니다.
    end

    # 레거시 API 라우트 - 이전 버전과의 호환성을 위해 v1으로 리다이렉트
    # 인증 관련 API
    post "auth/request_code", to: "v1/auth#request_code"
    post "auth/verify_code", to: "v1/auth#verify_code"
    post "auth/resend_code", to: "v1/auth#resend_code"
    post "auth/register", to: "v1/auth#register"
    post "auth/login", to: "v1/auth#login"
    post "auth/logout", to: "v1/auth#logout"
    post "auth/reset_password", to: "v1/auth#reset_password"
    post "auth/check_phone", to: "v1/auth#check_phone"

    # 사용자 관련 API
    get "users/me", to: "v1/users#me"
    get "users/profile", to: "v1/users#profile"
    get "users/:id", to: "v1/users#show"
    patch "users/me", to: "v1/users#update"
    put "users/me", to: "v1/users#update"
    post "users/change_password", to: "v1/users#change_password"
    get "users/notification_settings", to: "v1/users#notification_settings"
    post "users/notification_settings", to: "v1/users#update_notification_settings"
    patch "users/notification_settings", to: "v1/users#update_notification_settings"
    put "users/notification_settings", to: "v1/users#update_notification_settings"
    get "users/random_nickname", to: "v1/users#generate_random_nickname"
    post "users/change_nickname", to: "v1/users#change_nickname"
    post "users/update_profile", to: "v1/users#update_profile"
    post "users/:id/block", to: "v1/users#block"

    # 브로드캐스트 관련 레거시 API
    get "broadcasts", to: "v1/broadcasts#index"
    get "broadcasts/received", to: "v1/broadcasts#received"
    post "broadcasts", to: "v1/broadcasts#create"
    get "broadcasts/:id", to: "v1/broadcasts#show"
    post "broadcasts/:id/reply", to: "v1/broadcasts#reply"
    patch "broadcasts/:id/mark_as_read", to: "v1/broadcasts#mark_as_read"

    # 대화 관련 레거시 API
    get "conversations", to: "v1/conversations#index"
    get "conversations/:id", to: "v1/conversations#show"
    delete "conversations/:id", to: "v1/conversations#destroy"
    post "conversations/:id/favorite", to: "v1/conversations#favorite"
    post "conversations/:id/unfavorite", to: "v1/conversations#unfavorite"
    post "conversations/:id/send_message", to: "v1/conversations#send_message"

    # 기타 레거시 API
    get "me", to: "v1/users#me"
    post "change_nickname", to: "v1/users#change_nickname"
    get "generate_random_nickname", to: "v1/users#generate_random_nickname"
    post "update_profile", to: "v1/users#update_profile"
  end

  # 관리자 페이지 마운트
  # mount RailsAdmin::Engine => '/admin', as: 'rails_admin'

  # 커스텀 관리자 대시보드
  namespace :admin do
    # 대시보드 기본 페이지
    root to: "dashboard#index"

    # 신고 관리
    get "reports", to: "dashboard#reports"
    put "reports/:id/process", to: "dashboard#process_report", as: "process_report"
    put "reports/:id/reject", to: "dashboard#reject_report", as: "reject_report"

    # 사용자 관리
    get "users", to: "dashboard#users"
    put "users/:id/suspend", to: "dashboard#suspend_user", as: "suspend_user"
    put "users/:id/unsuspend", to: "dashboard#unsuspend_user", as: "unsuspend_user"
  end
end
