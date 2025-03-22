require 'sidekiq/web'

Rails.application.routes.draw do
  #mount Rswag::Ui::Engine => '/api-docs'
  #mount Rswag::Api::Engine => '/api-docs'
  # 사이드킥(Sidekiq) 관리자 UI
  mount Sidekiq::Web => '/sidekiq'
  
  # 헬스 체크 엔드포인트
  get "/api/health_check", to: "health_check#index"
  
  # 헬스 체크 엔드포인트 추가
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
  
  # RailsAdmin 마운트
  # mount RailsAdmin::Engine => '/admin', as: 'rails_admin'  # 젬이 설치되지 않아 주석 처리

  # 2) API
  namespace :api do
    namespace :v1 do
      # 지갑 관련 API
      get 'wallet', to: 'wallets#show'
      get 'wallet/transactions', to: 'wallets#transactions'
      post 'wallet/deposit', to: 'wallets#deposit'
      
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
    end
    
    # 인증 관련 API
    post "auth/request_code", to: "auth#request_code"
    post "auth/verify_code",  to: "auth#verify_code"
    post "auth/register",     to: "auth#register"
    post "auth/login",        to: "auth#login"
    post "auth/logout",       to: "auth#logout"

    # 사용자 관련 API
    get "users/me", to: "users#me"
    get "users/profile", to: "users#profile"
    get "users/:id", to: "users#show"
    patch "users/me", to: "users#update"
    put "users/me", to: "users#update"
    post "users/change_password", to: "users#change_password"
    
    # 기존 사용자 API (이전 버전과의 호환성 유지)
    get "me", to: "users#me"
    post "change_nickname", to: "users#change_nickname"
    get "generate_random_nickname", to: "users#generate_random_nickname"
    post "update_profile", to: "users#update_profile"
    post "users/update_profile", to: "users#update_profile"
    
    # 알림 설정 관련 API
    get "users/notification_settings", to: "users#notification_settings"
    post "users/notification_settings", to: "users#update_notification_settings"

    resources :broadcasts, only: [:index, :create, :show] do
      member do
        post :reply
      end
    end

    resources :conversations, only: [:index, :show, :destroy] do
      member do
        post :favorite
        post :unfavorite
        post :send_message
      end
    end
  end

  # 3) Users
  resources :users, only: [:index, :create, :show, :update] do
    member do
      post :report
      post :block
      post :unblock
    end

    # update_push_token을 컬렉션(collection)으로 선언
    # => 경로: POST /users/update_push_token
    collection do
      post :update_push_token
    end
  end
end