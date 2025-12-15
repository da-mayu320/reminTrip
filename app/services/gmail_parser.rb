class GmailParser
  require 'base64'

  # GmailのMessageオブジェクトからHTML本文を取り出す
  def self.extract_html(message)
    parts = message.payload.parts
    return nil if parts.blank?

    html_part = parts.find { |p| p.mime_type == 'text/html' }
    return nil if html_part&.body&.data.blank?

    decode_base64(html_part.body.data)
  end

  private

  def self.decode_base64(data)
    return nil if data.blank?

    # Gmailのbase64は改行・空白が混じるため除去
    cleaned = data.gsub(/\s/, '')

    Base64.urlsafe_decode64(cleaned)
  rescue ArgumentError => e
    Rails.logger.warn "GmailParser.extract_html base64 error: #{e.message}"
    nil
  end
end
