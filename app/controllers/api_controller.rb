# app/controllers/api_controller.rb
class ApiController < ActionController::Base
  include ApiAuthentication

  protect_from_forgery with: :null_session

  before_action :authorize_request
end
