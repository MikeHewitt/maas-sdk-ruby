require "miracl_api/version"
require "openid_connect"
module MiraclApi
  class MiraclClient
    class MiraclError < StandardError
      def initialize(message, exception=nil)
        message = exception ? "#{message}, original exception: #{exception.inspect}" : message
        super(message)
      end
    end
    ISSUER = "http://mpinaas-demo.miracl.net:8001"

    def initialize(options = {})
        @client_id = options[:client_id]
        @client_secret = options[:client_secret]
        @redirect_uri = options[:redirect_uri]
        @provider_info = discover!
        client
    end

    def get_authorization_request_url(session)
      # Returns redirect URL for authorization via M-Pin system. After URL
      # redirects back, pass url params to validate_authorization to complete
      # authorization with server.
      # :arg session ruby hash that contains session variables

      session[:miracl_state] ||= SecureRandom.hex(16)
      session[:miracl_nonce] ||= SecureRandom.hex(16)
      client.redirect_uri = @redirect_uri
      client.authorization_uri(
        response_type: :code,
        nonce: session[:miracl_nonce],
        state: session[:miracl_state],
        scope: @provider_info.scopes_supported & [:openid, :email, :user_id, :name].collect(&:to_s)
      )
    end

    def validate_authorization(params, session)
      # Returns access token if validation succeeds or nil if query string
      # doesn't contain code or state.
      # :arg session ruby hash that contains session variables
      # :arg params hash of parameters returned from authorization URL.

      return nil if (params[:code].nil?) || (params[:code].empty?) || (params[:state].nil?) || (params[:state].empty?)
      raise MiraclError.new("Session state differs from response state") if params[:state] != session[:miracl_state]
      client.redirect_uri = @redirect_uri
      client.authorization_code = params[:code]
      access_token = client.access_token! client_auth_method
      session[:miracl_state] = nil
      session[:miracl_nonce] = nil
      session[:miracl_userinfo] = access_token.userinfo!
      session[:miracl_token] = access_token.access_token
    end

    def clear_user_info(session, including_auth = false)
      # Clears session from user info
      # :arg session ruby hash that contains session variables
      # :arg including_auth clear also authentication data

      session[:miracl_token] = nil if including_auth
      session[:miracl_state] = nil
      session[:miracl_nonce] = nil
      session[:miracl_userinfo] = nil
    end

    def is_authorized(session)
      # Returns True if access token is in session
      # :arg session ruby hash that contains session variables

      session[:miracl_token]
    end

    def get_email(session)
      # Returns e-mail of authenticated user. If user is not authenticated or
      # server does not return e-mail as part of user data, returns nil.
      # Data from user data is cached in session. If fresh data is required,
      # use clear_user_info before call to this function.
      # :arg session ruby hash that contains session variables

      userinfo = request_user_info(session)
      return nil unless userinfo
      userinfo.email ? userinfo.email : "None"
    end

    def get_user_id(session)
      # Returns user ID of authenticated user. If user is not authenticated or
      # server does not return user ID as part of user data, returns nil.
      # Data from user data is cached in session. If fresh data is required,
      # use clear_user_info before call to this function.
      # :arg session ruby hash that contains session variables

      userinfo = request_user_info(session)
      return nil unless userinfo
      userinfo.sub ? userinfo.sub : "None"
    end

    private

      def request_user_info(session)
        return nil unless session[:miracl_token]
        return session[:miracl_userinfo] if session[:miracl_userinfo]
        userinfo = OpenIDConnect::AccessToken.new(
          access_token: session[:miracl_token],
          client: client
        ).userinfo!
        session[:miracl_userinfo] = userinfo
        userinfo
      rescue OpenIDConnect::Unauthorized => e
        session[:miracl_token] = nil
        raise MiraclError.new("Userinfo request failed", e)
      rescue OpenIDConnect::BadRequest, OpenIDConnect::HttpError, OpenIDConnect::Forbidden => e
        raise MiraclError.new("Userinfo request failed", e)
      end

      def client_auth_method
        supported = discover!.token_endpoint_auth_methods_supported
        if supported.present? && !supported.include?('client_secret_basic')
          :post
        else
          :basic
        end
      end

      def client
        hash_of_arguments = { identifier: @client_id,
                              secret: @client_secret,
                              token_endpoint: @provider_info.token_endpoint,
                              userinfo_endpoint: @provider_info.userinfo_endpoint,
                              authorization_endpoint: @provider_info.authorization_endpoint,
        }
        @client ||= OpenIDConnect::Client.new as_json(hash_of_arguments)
      end

      def discover!
        SWD.url_builder=URI::HTTP if ISSUER.include? 'http:' #forces SWD to use HTTP if
                                                            #ISSUER doesn't provide SSL discovery endpoint
        OpenIDConnect::Discovery::Provider::Config.discover! ISSUER
      rescue OpenIDConnect::Discovery::DiscoveryFailed => e
        raise MiraclError.new("Invalid ISSUER", e)
      end

      def as_json(options = {})
        [
          :identifier, :secret, :token_endpoint, :userinfo_endpoint, :authorization_endpoint
        ].inject({}) do |hash, key|
          hash.merge!(
            key => options[key]
          )
        end
      end
  end
end
