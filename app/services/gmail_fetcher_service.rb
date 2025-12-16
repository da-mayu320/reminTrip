# app/services/gmail_fetcher_service.rb
class GmailFetcherService
  PROVIDERS = {
    'JAL' => {
      from: 'booking.jal.com',
      subject: '(購入内容 OR JAL)'
    }
  }.freeze

  def initialize(user:)
    @user = user
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = google_credentials
  end

  # プロバイダ指定で取得＆DB保存
  def fetch_and_save_travel_infos(provider: 'JAL', max_emails: 50)
    travel_infos = fetch_travel_infos(provider: provider, max_emails: max_emails)

    travel_infos.each do |info|
      # flight_date または reservation_number が存在しない場合は保存しない
      next if info[:flight_date].nil? && info[:reservation_number].nil?

      TravelInfo.create!(
        user: @user,
        provider: provider,
        snippet: info[:snippet],
        message_id: info[:message_id],
        thread_id: info[:thread_id],
        flight_date: info[:flight_date],
        reservation_number: info[:reservation_number],
        departure: info[:departure],
        arrival: info[:arrival],
        received_at: info[:received_at]
      )
    end
  end

  # Gmail 取得＆解析
  def fetch_travel_infos(provider: 'JAL', max_emails: 50)
    config = PROVIDERS[provider]
    return [] unless config

    today = Date.today
    one_year_ago = today.prev_year

    query = [
      "from:#{config[:from]}",
      "subject:#{config[:subject]}",
      "after:#{one_year_ago.strftime('%Y/%m/%d')}",
      "before:#{today.strftime('%Y/%m/%d')}"
    ].join(' ')

    messages_response = @service.list_user_messages(
      'me',
      q: query,
      label_ids: ['INBOX'],
      max_results: max_emails
    )

    return [] unless messages_response.messages

    messages_response.messages.map do |msg|
      full_msg = @service.get_user_message('me', msg.id)
      extract_travel_info_from_text(full_msg.snippet)
    end.compact
  end

  private

  def google_credentials
    creds = Google::Auth::UserRefreshCredentials.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      scope: ['https://www.googleapis.com/auth/gmail.readonly'],
      access_token: @user.google_access_token,
      refresh_token: @user.google_refresh_token,
      expiration_time: @user.token_expires_at
    )

    if creds.expired?
      creds.refresh!
      @user.update!(
        google_access_token: creds.access_token,
        token_expires_at: creds.expires_at
      )
    end

    creds
  end

  # メール本文から必要情報を抽出
  def extract_travel_info_from_text(text)
    # 予約番号
    reservation_number = text[/予約番号\s*([A-Z0-9]+)/, 1]

    # 搭乗日
    flight_date = text[/旅程\d+\s*(\d{4}年\d+月\d+日)/, 1]
    flight_date = Date.strptime(flight_date, "%Y年%m月%d日") rescue nil

    # 出発地・到着地（JALのメールでは「出発空港：XXX」「到着空港：XXX」の形式）
    departure = text[/出発.*?：\s*(\S+)/, 1]
    arrival   = text[/到着.*?：\s*(\S+)/, 1]

    {
      snippet: text,
      message_id: nil,   # 必要に応じて full_msg.id を入れる
      thread_id: nil,    # 必要に応じて full_msg.thread_id を入れる
      reservation_number: reservation_number,
      flight_date: flight_date,
      departure: departure,
      arrival: arrival,
      received_at: nil   # 必要に応じて full_msg.internal_date を変換して入れる
    }
  end
end