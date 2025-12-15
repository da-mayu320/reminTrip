# app/services/gmail_fetcher_service.rb
class GmailFetcherService
  require 'google/apis/gmail_v1'
  require 'googleauth'
  require 'base64'
  require 'nokogiri'

  def initialize(user:)
    @user = user
    @service = Google::Apis::GmailV1::GmailService.new
    @service.authorization = google_credentials
  end

  def fetch_latest_travel_info(max_emails: 10)
    messages = @service.list_user_messages(
    'me',
    q: 'from:booking.jal.com subject:(購入内容 OR JAL)',
    max_results: max_emails
  )&.messages

    return nil if messages.blank?

    messages.each do |msg|
      body_text = get_message_body(msg.id)
      next if body_text.blank?

      info = extract_travel_info_from_text(body_text)

      # ⭐ STEP3：予約番号が取れたメールだけ採用
      next unless info&.dig(:reservation_number)

      return info
    end

    nil
  end

  private

  def google_credentials
    Google::Auth::UserRefreshCredentials.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      scope: ['https://www.googleapis.com/auth/gmail.readonly'],
      refresh_token: @user.google_refresh_token
    )
  end

  # ★ 正式採用する本文取得ロジック
  def get_message_body(message_id)
    message = @service.get_user_message('me', message_id)
    html_part = find_html_part(message.payload)
    return nil if html_part&.body&.data.blank?

    encoding = html_part.headers
                        &.find { |h| h.name == 'Content-Transfer-Encoding' }
                        &.value
                        &.downcase

    raw = html_part.body.data

    text = Base64.urlsafe_decode64(raw.gsub(/\s/, ''))

    Nokogiri::HTML(text).text.strip
  rescue => e
    Rails.logger.error "get_message_body error: #{e.message}"
    nil
  end

  def find_html_part(payload)
    return payload if payload.mime_type == 'text/html'
    return nil unless payload.parts

    payload.parts.find { |p| p.mime_type == 'text/html' }
  end

  def decode_base64(data)
    return nil if data.blank?

    cleaned = data.gsub(/\s/, '')
    Base64.urlsafe_decode64(cleaned)
  rescue ArgumentError => e
    Rails.logger.warn "base64 decode error: #{e.message}"
    nil
  end

  def extract_travel_info_from_text(text)
    {
      reservation_number: text[/予約番号\s*([A-Z0-9]+)/, 1],
      outbound_flight: text[/(JAL\d{3,4})便/, 1],
      outbound_date: text[/(\d{4}年\d{1,2}月\d{1,2}日)/, 1]
    }.compact.presence
  end
end
