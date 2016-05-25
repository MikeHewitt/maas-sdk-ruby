require 'test_helper'

class MiraclApiTest < Minitest::Test
  def setup
    @miracl = MiraclApi::MiraclClient.new({
      client_id: "MOCK_CLIENT",
      client_secret: "MOCK_SECRET",
      redirect_uri: "http://empty"})
  end

  def test_get_authorization_request_url
    session = {}
    url = @miracl.get_authorization_request_url(session)
    assert !session[:miracl_nonce].nil?
    assert !session[:miracl_state].nil?
    assert !url.nil?
  end

  def test_validation_saves_token_and_userinfo_in_session
    session = {miracl_state: "MOCK_STATE"}
    params = {state: 'MOCK_STATE', code: "MOCK_CODE"}
    response = "MOCK_TOKEN"
    OpenIDConnect::Client.any_instance.stubs(:access_token!).returns(response)
    response.stubs(:userinfo! => "MOCK_USERINFO", :access_token => "MOCK_ACCESS_TOKEN")
    @miracl.validate_authorization(params, session)
    assert !session[:miracl_token].nil?
    assert !session[:miracl_userinfo].nil?
  end

  def test_validation_with_empty_url
    session = {}
    @miracl.get_authorization_request_url(session)
    params = {}
    assert_nil @miracl.validate_authorization(params, session)
  end

  def test_session_state_differs_from_url_raises_exception
    session = {}
    @miracl.get_authorization_request_url(session)
    session[:miracl_state] = nil
    params = {state: "MOCK_STATE", code: "MOCK_STATE"}
    assert_raises MiraclApi::MiraclClient::MiraclError do
      @miracl.validate_authorization(params, session)
    end
  end

  def test_request_user_info_with_invalid_token_raises_exception
    session = {miracl_token: "INVALID_ACCESS_TOKEN"}
    assert_raises MiraclApi::MiraclClient::MiraclError do
      @miracl.get_email(session)
    end
  end

  def test_request_user_info_with_valid_token_saves_userinfo_in_session
    session = {miracl_token: "VALID_ACCESS_TOKEN", miracl_userinfo: nil}
    access_token = "MOCK_TOKEN"
    OpenIDConnect::AccessToken.stubs(:new).returns(access_token)
    user_info = {email: "MOCK_EMAIL", sub: "MOCK_SUB"}
    access_token.stubs(:userinfo!).returns(user_info)
    user_info.stubs(:email).returns(user_info[:email])
    @miracl.get_email(session)
    assert_equal "MOCK_EMAIL", session[:miracl_userinfo][:email]
  end
end
