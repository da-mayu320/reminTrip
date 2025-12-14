# app/services/gmail_service.rb
require "google/apis/gmail_v1"
require "signet/oauth_2/client"

class GmailService
  def initialize(user)
    @user = user
  end

  # ★ 最小：Gmailを1件取得
  def fetch_one_message
    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = credentials

    result = service.list_user_messages('me', max_results: 1)
    result.messages
  end

  private

  def credentials
    Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      access_token: @user.google_access_token,
      refresh_token: @user.google_refresh_token,
      token_credential_uri: "https://oauth2.googleapis.com/token"
    )
  end
end
