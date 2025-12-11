class GoogleController < ApplicationController
  require "google/apis/gmail_v1"
  require "signet/oauth_2/client"
  require "cgi"

  def auth
    client_id = ENV['GOOGLE_CLIENT_ID']
    redirect_uri = Rails.env.production? ? 
                     "https://remintrip.onrender.com/auth/google_oauth2/callback" : 
                     "http://localhost:3000/auth/google_oauth2/callback"
    scope = "https://www.googleapis.com/auth/gmail.readonly"

    # OAuth URL を手動で作成
    url = "https://accounts.google.com/o/oauth2/v2/auth?" +
          "client_id=#{client_id}" +
          "&redirect_uri=#{CGI.escape(redirect_uri)}" +
          "&response_type=code" +        # ← 必須
          "&scope=#{CGI.escape(scope)}" +
          "&access_type=offline" +
          "&prompt=consent"

    redirect_to url, allow_other_host: true
  end

  def callback
    code = params[:code]
    client_id = ENV['GOOGLE_CLIENT_ID']
    client_secret = ENV['GOOGLE_CLIENT_SECRET']
    redirect_uri = Rails.env.production? ? 
                     "https://remintrip.onrender.com/auth/google_oauth2/callback" : 
                     "http://localhost:3000/auth/google_oauth2/callback"

    client = Signet::OAuth2::Client.new(
      client_id: client_id,
      client_secret: client_secret,
      token_credential_uri: "https://oauth2.googleapis.com/token",
      code: code,
      redirect_uri: redirect_uri
    )

    client.fetch_access_token!

    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = client

    messages = service.list_user_messages('me', max_results: 5)
    render plain: messages.to_json
  end
end
