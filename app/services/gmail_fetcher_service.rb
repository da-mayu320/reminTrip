# app/services/gmail_fetcher_service.rb
class GmailFetcherService
  def initialize(user:)
    @user = user
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = google_credentials
  end

  # 直近1年分のメールを取得して解析
  def fetch_travel_infos(max_emails: 50)
    today = Date.today
    one_year_ago = today.prev_year

    query = [
      'from:booking.jal.com',
      'subject:(購入内容 OR JAL)',
      "after:#{one_year_ago.strftime('%Y/%m/%d')}",
      "before:#{today.strftime('%Y/%m/%d')}"
    ].join(' ')

    # Gmail API でメッセージ一覧取得
    messages_response = @service.list_user_messages(
      'me',
      q: query,
      label_ids: ['INBOX'],
      max_results: max_emails
    )

    return [] unless messages_response.messages

    # 各メールを取得して解析
    messages_response.messages.map do |msg|
      full_msg = @service.get_user_message('me', msg.id)
      extract_travel_info_from_text(full_msg.snippet)
    end.compact
  end

  private

  # Google 認証情報を作成
  def google_credentials
    Google::Auth::UserRefreshCredentials.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      scope: ['https://www.googleapis.com/auth/gmail.readonly'],
      access_token: @user.google_access_token,
      refresh_token: @user.google_refresh_token,
      expiration_time: @user.token_expires_at
    )
  end

  # 取得したメール本文から旅行情報を解析する仮メソッド
  def extract_travel_info_from_text(text)
    # ここで正規表現や文字列処理を使って必要な情報を抽出
    # 例: 予約番号・搭乗日・搭乗者など
    { snippet: text } # とりあえずサンプルで snippet を返す
  end
end