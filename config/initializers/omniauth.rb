Rails.application.config.middleware.use OmniAuth::Builder do
  redirect_uri = Rails.env.production? ? ENV['GOOGLE_REDIRECT_URI_PROD'] : ENV['GOOGLE_REDIRECT_URI_LOCAL']
  OmniAuth.config.allowed_request_methods = [:post, :get]

  provider :google_oauth2,
           ENV['GOOGLE_CLIENT_ID'],
           ENV['GOOGLE_CLIENT_SECRET'],
           {
             scope: 'https://www.googleapis.com/auth/gmail.readonly',
             access_type: 'offline',
             prompt: 'consent',
             redirect_uri: redirect_uri
           }
end
