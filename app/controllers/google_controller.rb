class GoogleController < ApplicationController
  require "signet/oauth_2/client"
  require "google/apis/gmail_v1"
  require "cgi"

  before_action :authenticate_user!  # ログイン必須

  # Google OAuth にリダイレクト
  def auth
    client_id = ENV['GOOGLE_CLIENT_ID']
    redirect_uri = auth_google_callback_url
    scope = "https://www.googleapis.com/auth/gmail.readonly"

    url = "https://accounts.google.com/o/oauth2/v2/auth?" +
          "client_id=#{client_id}" +
          "&redirect_uri=#{CGI.escape(redirect_uri)}" +
          "&response_type=code" +
          "&scope=#{CGI.escape(scope)}" +
          "&access_type=offline" +
          "&prompt=consent"

    redirect_to url, allow_other_host: true
  end

  # OAuth コールバック
  def callback
    code = params[:code]
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: "https://oauth2.googleapis.com/token",
      code: code,
      redirect_uri: auth_google_callback_url
    )

    token_data = client.fetch_access_token!

    # トークン保存
    current_user.update(
      google_access_token: token_data['access_token'],
      google_refresh_token: token_data['refresh_token'],
      token_expires_at: Time.now + token_data['expires_in'].to_i.seconds
    )

    redirect_to root_path, notice: "Googleアカウントを連携しました"
  end
end

def fetch_travel_emails
  client = Signet::OAuth2::Client.new(
    client_id: ENV['GOOGLE_CLIENT_ID'],
    client_secret: ENV['GOOGLE_CLIENT_SECRET'],
    token_credential_uri: 'https://oauth2.googleapis.com/token',
    access_token: current_user.google_access_token,
    refresh_token: current_user.google_refresh_token
  )

  service = Google::Apis::GmailV1::GmailService.new
  service.authorization = client

  messages = service.list_user_messages('me', max_results: 10).messages || []

  travel_info = []

  messages.each do |msg|
    message = service.get_user_message('me', msg.id)
    body = message.payload.parts&.map(&:body)&.map(&:data)&.join || ""
    body = Base64.urlsafe_decode64(body) rescue body

    # 正規表現で旅行情報抽出（例: 「旅行先: 東京」）
    travel_info += body.scan(/旅行先:\s*(\S+)/)
  end

  render plain: travel_info.flatten.join(", ")
end
