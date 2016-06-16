require "bundler/setup"
require 'sinatra'
require 'sinatra/flash'
require 'miracl_api'
require 'json'

configure do
  set :port, 5000
  enable :sessions
end

before do
  file = open("sample.json")
  json = file.read
  parsed = JSON.parse(json)
  credentials = parsed.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
  @miracl = MiraclApi::MiraclClient.new(credentials)
end

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

get('/auth') do
  redirect @miracl.get_authorization_request_url(session)
end

get('/c2id') do
  if @miracl.validate_authorization(params, session)
    flash[:success] = "Successfully logged in!"
  else
    flash[:danger] = "Login failed!"
  end
  redirect '/'
end

get('/refresh') do
  @miracl.clear_user_info(session)
  redirect '/'
end

get('/logout') do
  @miracl.clear_user_info(session, including_auth=true)
  redirect '/'
end
