class GoogleController < ApplicationController
  before_action :authenticate_user!

  # Gmail 認証ページにリダイレクト
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

    current_user.update!(
      google_access_token: token_data['access_token'],
      google_refresh_token: token_data['refresh_token'],
      token_expires_at: Time.current + token_data['expires_in'].to_i.seconds
    )

    redirect_to root_path, notice: "Googleアカウントを連携しました"
  end

  # 最新メール取得
  def read_email
    results = fetch_travel_info
    render json: results
  end

  private

  def fetch_travel_info(max_emails: 20)
    service = Google::Apis::GmailV1::GmailService.new
    service.authorization = current_user.google_api_client

    messages = service.list_user_messages('me', max_results: max_emails)&.messages
    return [] if messages.blank?

    travel_infos = []

    messages.each do |msg|
      message = service.get_user_message('me', msg.id)

      html = GmailParser.extract_html(message)
      next unless html

      text = GmailParser.html_to_text(html)
      # 旅行っぽいメールだけ対象
      next unless text =~ /予約|ホテル|航空|搭乗|宿泊|出発|到着/

      info = TravelInfoExtractor.extract(text)
      travel_infos << info unless info.empty?
    end

    travel_infos
  end
end
