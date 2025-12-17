require 'nokogiri'
require 'zlib'
require 'stringio'
require 'mail'
require 'nkf'
require 'date'
require 'google/apis/gmail_v1'
require 'googleauth'

class GmailFetcherService
  PROVIDERS = {
    'JAL' => { from: 'booking.jal.com', subject: '(購入内容 OR JAL)' },
    'Booking.com' => { from: 'noreply@booking.com', subject: 'Your Booking Confirmation' },
    'Shinkansen' => { from: 'yoyaku@expy.jp', subject: '予約内容' }
  }.freeze

  def initialize(user:)
    @user = user
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = google_credentials
  end

  def fetch_and_save_travel_infos(provider: 'JAL', max_emails: 50)
    fetch_travel_infos(provider: provider, max_emails: max_emails).each do |infos|
      Array(infos).each do |info|
        info.merge!(user_id: @user.id, provider: provider)
        begin
          TravelInfo.create!(info)
        rescue => e
          Rails.logger.error "[GmailFetchError] #{e.class}: #{e.message}\n#{e.backtrace.join("\n")}"
        end
      end
    end
  end

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

    messages_response = @service.list_user_messages('me', q: query, label_ids: ['INBOX'], max_results: max_emails)
    return [] unless messages_response.messages

    messages_response.messages.map do |msg|
      full_msg = @service.get_user_message('me', msg.id)
      raw_data = extract_body_data(full_msg.payload)
      next if raw_data.blank?

      decoded = safe_base64_decode(raw_data)
      decoded = Mail::Encodings::QuotedPrintable.decode(decoded) rescue decoded
      charset = detect_charset(full_msg.payload)
      decoded = NKF.nkf("-w --ic=#{charset}", decoded)
      text = full_msg.payload.mime_type == 'text/html' ? Nokogiri::HTML(decoded).text : decoded
      text = text.gsub(/\s+/, ' ').strip

      infos = extract_travel_info_from_text(text, @user, provider)
      Array(infos).each do |info|
        info[:message_id] = full_msg.id
        info[:thread_id] = full_msg.thread_id
        info[:snippet] = full_msg.snippet
        info[:received_at] = full_msg.internal_date ? Time.at(full_msg.internal_date.to_i / 1000) : nil
      end
      infos
    end.compact
  end

  private

  def extract_body_data(payload)
    if payload.body&.data
      payload.body.data
    elsif payload.parts
      payload.parts.each do |part|
        data = extract_body_data(part)
        return data if data.present?
      end
      nil
    else
      nil
    end
  end

  def detect_charset(payload)
    content_type_header = payload.headers.find { |h| h.name.downcase == 'content-type' }&.value
    charset = content_type_header[/charset="?([\w\-]+)"?/i, 1] if content_type_header
    charset || 'UTF-8'
  end

  def safe_base64_decode(data)
    return nil if data.blank?
    Base64.urlsafe_decode64(data.tr("\n", ''))
  rescue ArgumentError
    Rails.logger.warn "BASE64 DECODE FAILED, using raw text"
    data
  end

  # JALメールの情報抽出
  def extract_travel_info_from_text(text, user, provider)
    case provider
    when 'JAL'
      normalized_text = text.gsub(/\r\n?/, "\n").gsub(/[　]/, ' ').strip
      reservation_number = normalized_text[/〔予約番号〕\s*\n?\s*([A-Z0-9]+)/, 1] || "–"

      flights = []
      lines = normalized_text.split("\n").map(&:strip)
      current_date = nil
      current_flight_no = nil

      lines.each do |line|
        # 日付行（例：2025年6月25日（水）　JAL2243便）
        if line =~ /(\d{4})年(\d{1,2})月(\d{1,2})日.*?([A-Z0-9]+)?便?/
          y, m, d = $1.to_i, $2.to_i, $3.to_i
          current_date = Date.new(y, m, d)
          current_flight_no = $4 || "–"
          next
        end

        # 出発→到着行（空白・全角スペース・タブ対応）
        if line =~ /([\p{Han}\p{Hiragana}\p{Katakana}ー\(\)・]+)\s*(\d{1,2}:\d{2})発\s*[\t ]*→[\t ]*([\p{Han}\p{Hiragana}\p{Katakana}ー\(\)・]+)\s*(\d{1,2}:\d{2})着/
          dep, dep_time, arr, arr_time = $1.strip, $2, $3.strip, $4
          flights << {
            user_id: user.id,
            reservation_number: reservation_number,
            flight_date: current_date,
            flight_number: current_flight_no,
            departure: dep,
            departure_time: dep_time,
            arrival: arr,
            arrival_time: arr_time
          }
        end
      end

      flights

    when 'Booking.com'
      [{
        reservation_number: text[/ID[:：]?\s*(\d+)/,1] || "–",
        hotel_name: text[/予約が確定しました！\s*([^\n]+)/,1] || "–",
        checkin_date: text[/(\d{4}年\d{1,2}月\d{1,2}日).*?チェックイン/,1],
        checkout_date: text[/(\d{4}年\d{1,2}月\d{1,2}日).*?チェックアウト/,1]
      }]

    when 'Shinkansen'
      infos = []
      reservation_number = text[/確認番号\s*([0-9]+)/,1] || "–"
      text.scan(/乗車日\s*([\d年\d月\d日]+).*?([^\s]+)\(([\d:]+)\).*?→([^\s]+)\(([\d:]+)\)/) do |date_str, dep, dep_time, arr, arr_time|
        flight_date = nil
        begin
          flight_date = Date.strptime(date_str, "%Y年%m月%d日")
        rescue
          flight_date = nil
        end
        infos << {
          reservation_number: reservation_number,
          flight_date: flight_date,
          departure: dep,
          departure_time: dep_time,
          arrival: arr,
          arrival_time: arr_time
        }
      end
      infos
    else
      []
    end
  end

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
