require "bundler/setup"
require 'sinatra'
require 'sinatra/flash'
require 'miracl_api'
require 'json'


configure do
  # Telling Sinatra to run local webserver on port 5000
  set :port, 5000

  # Enabling session for sinatra app, implicitly assigned to 'session' hash
  enable :sessions
end

before do
  # Retrieving credentials from 'sample.json' file for authorization
  file = open("sample.json")
  json = file.read
  parsed = JSON.parse(json)

  # Converting parsed JSON to Ruby hash
  credentials = parsed.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}

  # Initialization of MiraclClient before every controller method is called
  @miracl = MiraclApi::MiraclClient.new(credentials)
end

get('/') do
  @retry = flash[:danger] ? true : false

  # Returns access token if in session or false otherwise
  @is_authorized = @miracl.is_authorized(session)

  if @is_authorized
    # Request for user info
    @email = @miracl.get_email(session)
    @user_id = @miracl.get_user_id(session)
  else
    # Returns constructed auth url
    @auth_url = @miracl.get_authorization_request_url(session)
  end

  erb :application
end

get('/c2id') do
  # Validating the authorization
  # 'params' hash contains Sinatra parsed request query string. It should include :state and :code so access token
  #  along with user info can be obtained and stored in session
  if @miracl.validate_authorization(params, session)
    flash[:success] = "Successfully logged in!"
  else
    flash[:danger] = "Login failed!"
  end
  redirect '/'
end

get('/refresh') do
  # Clears user info from session but leaves access token unchanged
  #  so user info can be obtained without performing fresh authorization
  @miracl.clear_user_info(session)
  redirect '/'
end

get('/logout') do
  # If 'including_auth=true' is passed as a second parameter to MiraclClient#clear_user_info,
  #  then not only user info is cleared from session but also access token
  #  so call of MiraclClient#is_authorized returns false
  @miracl.clear_user_info(session, including_auth=true)
  redirect '/'
end
