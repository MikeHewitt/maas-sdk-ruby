require "bundler/setup"
require 'sinatra'
require 'sinatra/flash'
require 'miracl_api'

configure do
  set :port, 3000
  enable :sessions
end

before do
  @miracl = MiraclApi::MiraclClient.new({
    client_id: "CLIENT_ID",
    client_secret: "CLIENT_SECRET",
    redirect_uri: "REDIRECT_URI"})
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
