require 'google/apis/gmail_v1'
require 'googleauth'
require 'base64'

class GmailFetcherService
  def initialize(user:)
    @user = user
    @gmail = build_gmail_client
  end
  
  def fetch_and_save_travel_infos(provider:, max_emails:)
    flights = fetch_travel_infos(provider: provider, max_emails: max_emails)

    flights.each do |f|
      # すでに同じ user_id + reservation_number + flight_number + flight_date が存在していれば保存しない
      TravelInfo.find_or_create_by(
        user_id: @user.id,
        reservation_number: f[:reservation_number],
        flight_number: f[:flight_number],
        flight_date: f[:flight_date]
      ) do |ti|
        ti.departure      = f[:departure]
        ti.departure_time = f[:departure_time]
        ti.arrival        = f[:arrival]
        ti.arrival_time   = f[:arrival_time]
      end
    end
  end

  def fetch_travel_infos(provider:, max_emails:)
    messages = @gmail.list_user_messages(
      'me',
      max_results: max_emails,
      q: 'from:booking.jal.com'
    ).messages || []

    messages.flat_map do |msg|
      mail = @gmail.get_user_message('me', msg.id)
      body = extract_body(mail)
      parse_jal_mail(body)
    end
    .uniq { |f| [f[:flight_date], f[:flight_number]] }
  end

  private

  def build_gmail_client
    service = Google::Apis::GmailV1::GmailService.new
    service.authorization =
      Google::Auth::UserRefreshCredentials.new(
        client_id: ENV['GOOGLE_CLIENT_ID'],
        client_secret: ENV['GOOGLE_CLIENT_SECRET'],
        scope: ['https://www.googleapis.com/auth/gmail.readonly'],
        refresh_token: @user.google_refresh_token
      )
    service
  end

  def extract_body(mail)
    part =
      mail.payload.parts&.find { |p| p.mime_type == 'text/plain' } ||
      mail.payload.parts&.find { |p| p.mime_type == 'text/html' }

    return '' unless part&.body&.data

    decoded = Base64.urlsafe_decode64(part.body.data)

    # ★ここが重要（Encoding Fix）
    decoded.force_encoding('UTF-8')
           .encode('UTF-8', invalid: :replace, undef: :replace)
  rescue
    part.body.data.to_s
  end

  def parse_jal_mail(text)
    text = text.to_s
               .force_encoding('UTF-8')
               .encode('UTF-8', invalid: :replace, undef: :replace)
    text = text.gsub(/<[^>]+>/, "\n")
    
    puts "===== RAW MAIL BODY ====="
    puts text
    puts "======================"

    reservation_number = text[/〔?予約番号〕?[\s　]*\n[\s　]*([A-Z0-9]{5,6})/, 1] || "–"
    
    puts "===== EXTRACTED RESERVATION NUMBER ====="
    puts reservation_number
    puts "========================================"
    
    lines = text.split(/\R/).map(&:strip)

    flights = []
    current_date = nil
    current_flight_no = nil

    lines.each do |line|
      # ① 日付 + 便名
      if line =~ /(\d{4})年(\d{1,2})月(\d{1,2})日.*?(JAL\d+)/
        y, m, d = $1.to_i, $2.to_i, $3.to_i
        current_date = Date.new(y, m, d)
        current_flight_no = $4
        next
      end

      # ② 発 → 着（ガード付き）
      match = line.match(/(.+?)\s*(\d{2}:\d{2})発.*?(.+?)\s*(\d{2}:\d{2})着/)
      next unless match
      next unless current_date

      dep, dep_time, arr, arr_time = match.captures
      next if dep.nil? || arr.nil?

      flights << {
        reservation_number: reservation_number,
        flight_date: current_date,
        flight_number: current_flight_no,
        departure: dep.strip.gsub(/\A[　\s]+/, ''),
        departure_time: dep_time,
        arrival: arr.strip.gsub(/\A[→　\s]+/, ''),
        arrival_time: arr_time
      }
    end

    puts "===== EXTRACTED FLIGHTS ====="
    puts flights.inspect
    puts "=============================="

    flights
  end
end
