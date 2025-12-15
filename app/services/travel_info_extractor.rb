class TravelInfoExtractor
  def self.extract(text)
    info = {}

    # 予約番号
    if text =~ /(予約番号|注文番号)[:：\s]*([A-Z0-9-]+)/
      info[:reservation_number] = $2
    end

    # 出発日時
    if text =~ /出発(?:日|日時)?[:：\s]*(\d{4}年\d{1,2}月\d{1,2}日)\s*(\d{1,2}:\d{2})?/
      info[:departure_datetime] = parse_datetime($1, $2)
    end

    # 到着日時
    if text =~ /到着(?:日|日時)?[:：\s]*(\d{4}年\d{1,2}月\d{1,2}日)\s*(\d{1,2}:\d{2})?/
      info[:arrival_datetime] = parse_datetime($1, $2)
    end

    # 出発場所
    if text =~ /出発(?:地|場所)[:：\s]*([^\n]+)/ 
      info[:departure_place] = $1.strip
    end

    # 到着場所
    if text =~ /到着(?:地|場所)[:：\s]*([^\n]+)/
      info[:arrival_place] = $1.strip
    end

    # 宿泊施設
    if text =~ /(宿泊施設|ホテル名)[:：\s]*([^\n]+)/
      info[:hotel] = $2.strip
    end

    info
  end

  def self.parse_datetime(date_str, time_str)
    date = Date.strptime(date_str, '%Y年%m月%d日')
    time_str ? DateTime.parse("#{date} #{time_str}") : date
  rescue
    nil
  end
end
