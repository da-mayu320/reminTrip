class GoogleController < ApplicationController
  require "google/apis/gmail_v1"
  require "signet/oauth_2/client"
  require "cgi"

  # Googleログインへリダイレクト
  def auth
    client_id = ENV['GOOGLE_CLIENT_ID']
    redirect_uri = Rails.env.production? ? 
                     "https://remintrip.onrender.com/auth/google_oauth2/callback" : 
                     "http://localhost:3000/auth/google_oauth2/callback"
    scope = "https://www.googleapis.com/auth/gmail.readonly"

    # OAuth URL を手動で作成（response_type=code を必ず含める）
    url = "https://accounts.google.com/o/oauth2/v2/auth?" +
          "client_id=#{client_id}" +
          "&redirect_uri=#{CGI.escape(redirect_uri)}" +
          "&response_type=code" +
          "&scope=#{CGI.escape(scope)}" +
          "&access_type=offline" +
          "&prompt=consent"

    # URLをブラウザに飛ばす
    redirect_to url, allow_other_host: true
  end

  # Googleから返ってきたとき
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

    # アクセストークンを取得
    begin
      client.fetch_access_token!
    rescue => e
      render plain: "アクセストークン取得エラー: #{e.message}" and return
    end

    # Gmail API 呼び出し
    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = client

    begin
      messages = service.list_user_messages('me', max_results: 5)
      render plain: messages.to_json
    rescue => e
      render plain: "Gmail API呼び出しエラー: #{e.message}"
    end
  end
end
