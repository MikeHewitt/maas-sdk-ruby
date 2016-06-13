# Setup

## Installation

Add the following line to Gemfile:

`gem 'miracl_api', :git => 'git://github.com/miracl/maas-sdk-ruby.git'`

And run `bundle install`

Or

1.Download the source:

   `git clone https://github.com/miracl/maas-sdk-ruby.git`

2.Build the gem:

   `cd miracl_api` && `gem build miracl_api.gemspec`

3.Install it from project root:

   `gem install miracl_api/miracl_api-0.1.0.gem`

And run `bundle install`

## Tests

To run tests, run

`bundle install`

From miracl_api root directory and run

`rake test`

To run tests.

# Miracl API

## Details and usage

All interaction with API happens through 'MiraclClient' object. Each application needs to construct instance of `MiraclClient`.

Drop `require 'miracl_api'` at the top of the file you are going to use `MiraclClient`

Miracl API requires map-like object for storing state and additional data (it should be preserved between calls to api). In this document it is called `session`.

### Initialization

To start using Miracl API, `MiraclClient` should be initialized. It can be done when needed or called before each controller action using e.g. before_action in Rails or before {} in Sinatra.

```
@client = MiraclApi::MiraclClient.new({
    client_id: "CLIENT_ID",
    client_secret: "CLIENT_SECRET",
    redirect_uri: "REDIRECT_URI",
    issuer: "ISSUER"
    })
```
`CLIENT_ID` and `CLIENT_SECRET` can be obtained from Miracl(unique per application). Normally it is not necessary to specify Miracl configuration endpoint to MiraclClient but it can be done by passing `issuer: "ISSUER"` along with `client_id`, `client_secret` and `redirect_uri` to `MiraclClient`. `REDIRECT_URI` is URI of your application end-point that will be responsible obtaining token. It should be the same as registered in Miracl system for this client ID.

To check if user session has token use `@client.is_authorized(session)`. You can request additional user data with `@client.get_email(session)` and `@client.get_user_id(session)`. Both methods cache results into `session`. If `nil`  is returned, token is expired and client needs to be authorized once more to access required data.

Use `@client.clear_user_info(session)` to drop cached user data (e-mail and user id).

Use `@client.clear_user_info(session, true)` to clear user authorization status.

### Authorization flow

Authorization flow depends on `mpad.js` browser library. To use it, drop following line
```
<script src="https://demo.dev.miracl.net/mpin/mpad.js" data-authurl="<%=auth_url%>" data-element="btmpin"></script>
```
right before closing `</body>` tag. And drop
```
<div id="btmpin"></div>
```
in the desired location of "Login with M-Pin" button.

If user is not authorized, use `miracl.getAuthorizationRequestUrl(session)` to get authorization request URL and set client internal state. Returned URL should be passed to `data-authurl` attribute like `data-authurl="<%=auth_url%>`. After user interaction with Miracl system user will be sent to `redirect_uri` defined at initialization of `MiraclClient` object.

If user is not authorized, use `@client.get_authorization_request_url(params, session)` to get authorization request URL and set client internal state. Returned URL should be passed to `data-authurl` attribute like `data-authurl="<%=@auth_url%>"`. After user interaction with Miracl system  user will be sent to `redirect_uri` defined at creation of `MiraclClient` object.

To complete authorization pass params hash received on `redirect_uri` to `@client.validate_authorization(params, session)`. This method will return `nil` if user denied authorization and token if authorization succeeded. Token is preserved in `session` so there is no need to save token elsewhere.

### Problems and exceptions

Each call to `MiraclClient` can raise `MiraclError`. It contains `message` and sometimes `exception`. Usually `MiraclError` is raised when API call can't continue and it's best to redirect user to error page if `MiraclError` is raised. `MiraclError` can contain helpful messages when debugging.

## Samples

Sample on Sinatra can be found in the `sample` directory. Replace `CLIENT_ID`, `CLIENT_SECRET` located in `sample.json` with valid data. Do steps written in `Installation` before starting the Sinatra server.

To start server,
`cd samples` && `ruby sinatra_sample.rb`.

Open `http://127.0.0.1:5000/` in your browser to explore the sample.

In case you haven't installed Sinatra before, run
`gem install sinatra`
 before running sample app.
