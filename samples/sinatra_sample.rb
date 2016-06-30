require "bundler/setup"
require 'sinatra'
require 'sinatra/flash'
require 'miracl_api'
require 'json'

# Enabling session for sinatra app and implicitly assigning it to 'session' hash
configure do
  set :port, 5000
  enable :sessions
end

before do
  # Retrieving credentials from 'sample.json'for authentication
  file = open("sample.json")
  json = file.read
  parsed = JSON.parse(json)

  # converting parsed JSON to Ruby hash
  credentials = parsed.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

  # initialization of MiraclClient before every controller method
  @miracl = MiraclApi::MiraclClient.new(credentials)
end

# MiraclClient#is_authorized(session) returns access token(true) if in session or false otherwise
# If user is not authorized then authorization url has to be obtained and passed to view
# If user is authorized then user info can obtained by calling MiraclClient#get_email(session) and MiraclClient#get_user_id(session)
get('/') do
  @retry = flash[:danger] ? true : false
  @is_authorized = @miracl.is_authorized(session)
  if @is_authorized
    @email = @miracl.get_email(session)
    @user_id = @miracl.get_user_id(session)
  else
    @auth_url = @miracl.get_authorization_request_url(session)
  end
  erb :application
end

# When provider has authorized the user and redirects back to your app,
# authorization has to be validated by calling MiraclClient#validate_authorization(params, session).
# 'params' hash contains sinatra parsed request query string. It should include :state and :code so access token
# along with user info can be obtained by calling MiraclClient#validate_authorization(params, session) and be stored in session
get('/c2id') do
  if @miracl.validate_authorization(params, session)
    flash[:success] = "Successfully logged in!"
  else
    flash[:danger] = "Login failed!"
  end
  redirect '/'
end

# MiraclClient#clear_user_info(session) clears user info from session
# but access token remains so user info can be obtained
# by calling MiraclClient#get_email(session) and MiraclClient#get_user_id(session)
get('/refresh') do
  @miracl.clear_user_info(session)
  redirect '/'
end

# If 'including_auth=true' is passed as second parameter to MiraclClient#clear_user_info,
# then not only user info is cleared from session but also access token
# so call of MiraclClient#is_authorized(session) returns false
get('/logout') do
  @miracl.clear_user_info(session, including_auth=true)
  redirect '/'
end
