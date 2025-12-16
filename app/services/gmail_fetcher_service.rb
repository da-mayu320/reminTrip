require 'nokogiri'
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

  def safe_base64_decode(data)
    return nil if data.blank?

    # Gmail APIは padding (=) を省略するので補正が必要
    data += '=' * ((4 - data.length % 4) % 4)

    decoded = Base64.urlsafe_decode64(data)

    # 文字化け防止
    decoded.force_encoding('UTF-8')
  rescue ArgumentError => e
    Rails.logger.error "BASE64 DECODE ERROR: #{e.message}"
    nil
  end


  def extract_body_data(payload, message_id = nil)
    return nil unless payload

    # 直接 data がある場合
    if payload.body&.data.present?
      Rails.logger.info "FOUND inline body"
      return payload.body.data
    end

    # attachment の場合
    if payload.body&.attachment_id.present? && message_id.present?
      Rails.logger.info "FOUND attachment body"

      attachment = @service.get_user_message_attachment(
        'me',
        message_id,
        payload.body.attachment_id
      )

      return attachment.data
    end

    # parts を再帰的に探索
    if payload.parts
      payload.parts.each do |part|
        found = extract_body_data(part, message_id)
        return found if found.present?
      end
    end

    nil
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
        reservation_number: info[:reservation_number],
        flight_date: info[:flight_date],
        departure: info[:departure],
        departure_time: info[:departure_time],
        arrival: info[:arrival],
        arrival_time: info[:arrival_time],
        received_at: info[:received_at]
      )
    end
  end

  # Gmail取得＆HTML解析
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

    messages_response.messages.flat_map do |msg|
      Rails.logger.info "===== MESSAGE LOOP START ====="
      full_msg = @service.get_user_message('me', msg.id)
      @current_message_id = full_msg.id

      raw_data = extract_body_data(full_msg.payload, full_msg.id)
      Rails.logger.info "BODY_DATA_PRESENT=#{raw_data.present?}"

      decoded = safe_base64_decode(raw_data)
      Rails.logger.info "DECODED_PRESENT=#{decoded.present?}"

      next [] if decoded.blank?

      text = Nokogiri::HTML(decoded).text.gsub(/\s+/, ' ').strip

      Rails.logger.info "===== TEXT START ====="
      Rails.logger.info text.first(500)
      Rails.logger.info "===== TEXT END ====="


      extract_travel_info_from_text(text, full_msg)
    end
  end

  private

  # HTMLから情報を抽出
  def extract_travel_info_from_text(text, full_msg)
    travel_infos = []
    # 予約番号
    reservation_number = text[/予約番号\s*([A-Z0-9]+)/, 1] || "–"

    # 旅程ブロックを抽出
    text.scan(
      /旅程\d+\s*
       (\d{4}年\d{1,2}月\d{1,2}日).*?
       ([^\d\s]+(?:\([^)]+\))?)\s*(\d{2}:\d{2})発\s*
       ([^\d\s]+(?:\([^)]+\))?)\s*(\d{2}:\d{2})着
      /x
    ) do |date_str, dep_airport, dep_time, arr_airport, arr_time|
      
      flight_date = Date.strptime(date_str, "%Y年%m月%d日") rescue nil

      received_at =
        begin
          Time.at(full_msg.internal_date.to_i / 1000)
        rescue
          nil
        end

      travel_infos << {
        snippet: text,
        message_id: full_msg.id,
        thread_id: full_msg.thread_id,
        reservation_number: reservation_number,
        flight_date: flight_date,
        departure: dep_airport,
        departure_time: dep_time,
        arrival: arr_airport,
        arrival_time: arr_time,
        received_at: received_at
      }
    end

    travel_infos
  end

  # Google認証
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
end