require "test_helper"

class AuthControllerTest < ActionDispatch::IntegrationTest
  test "should get request_code" do
    post api_v1_auth_request_code_url, params: { user: { phone_number: "01012345678" } }, as: :json
    assert_response :success
  end

  test "should get verify_code" do
    post api_v1_auth_verify_code_url, params: { user: { phone_number: "01012345678", code: "123456" } }, as: :json
    assert_response :success
  end
end
