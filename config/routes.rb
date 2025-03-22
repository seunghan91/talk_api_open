require 'sidekiq/web'

Rails.application.routes.draw do
  # Swagger API 문서화 엔진 마운트
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  
  # 사이드킥(Sidekiq) 관리자 UI
  mount Sidekiq::Web => '/sidekiq'
  
  # 헬스 체크 엔드포인트
  get "/api/health_check", to: "health_check#index"
  get '/health', to: proc { [200, {}, ['ok']] }
  
  # 1) 웹용 루트
  root 'pages#home'
  get "purchases/create"
  get "purchases/index"
  
  # 관리자 분석 대시보드
  namespace :admin do
    get 'analytics', to: 'analytics#index'
    get 'analytics/daily', to: 'analytics#daily'
    get 'analytics/weekly', to: 'analytics#weekly'
    get 'analytics/monthly', to: 'analytics#monthly'
  end
  
  # 2) API - 표준화된 v1 네임스페이스 사용
  namespace :api do
    namespace :v1 do
      # 인증 관련 API
      namespace :auth do
        post "request_code", to: "auth#request_code"
        post "verify_code", to: "auth#verify_code"
        post "register", to: "auth#register"
        post "login", to: "auth#login"
        post "logout", to: "auth#logout"
      end
      
      # 지갑 관련 API
      resources :wallets, only: [] do
        collection do
          get '', to: 'wallets#show'
          get 'transactions', to: 'wallets#transactions'
          post 'deposit', to: 'wallets#deposit'
        end
      end
      
      # 알림 관련 API
      resources :notifications, only: [:index, :show] do
        member do
          post :mark_as_read
        end
        collection do
          post :mark_all_as_read
          post :update_push_token
          get :settings
          post :update_settings
        end
      end

      # 사용자 관련 API
      resources :users, only: [:show, :update, :destroy] do
        collection do
          get 'me', to: 'users#me'
          get 'profile', to: 'users#profile'
          patch 'me', to: 'users#update'
          put 'me', to: 'users#update'
          post 'change_password', to: 'users#change_password'
          get 'notification_settings', to: 'users#notification_settings'
          patch 'notification_settings', to: 'users#update_notification_settings'
          put 'notification_settings', to: 'users#update_notification_settings'
          post 'change_nickname', to: 'users#change_nickname'
          get 'generate_random_nickname', to: 'users#generate_random_nickname'
          post 'update_profile', to: 'users#update_profile'
        end
        
        member do
          get 'notification_settings', to: 'users#notification_settings'
          patch 'notification_settings', to: 'users#update_notification_settings'
          put 'notification_settings', to: 'users#update_notification_settings'
          post 'report', to: 'users#report'
          post 'block', to: 'users#block'
          post 'unblock', to: 'users#unblock'
        end
      end

      # 브로드캐스트 관련 API
      resources :broadcasts, only: [:index, :create, :show] do
        member do
          post :reply
        end
      end

      # 대화 관련 API
      resources :conversations, only: [:index, :show, :destroy] do
        member do
          post :favorite
          post :unfavorite
          post :send_message
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
    post "auth/register", to: "v1/auth#register"
    post "auth/login", to: "v1/auth#login"
    post "auth/logout", to: "v1/auth#logout"

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
    
    # 브로드캐스트 관련 레거시 API
    get "broadcasts", to: "v1/broadcasts#index"
    post "broadcasts", to: "v1/broadcasts#create"
    get "broadcasts/:id", to: "v1/broadcasts#show"
    post "broadcasts/:id/reply", to: "v1/broadcasts#reply"
    
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
    post "users/update_profile", to: "v1/users#update_profile"
  end
end