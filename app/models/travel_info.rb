class TravelInfo < ApplicationRecord
  belongs_to :user

  # 表示用メソッド
  def departure_datetime
    flight_date ? "#{flight_date} #{departure || '–'}" : "–"
  end

  def arrival_datetime
    flight_date ? "#{flight_date} #{arrival || '–'}" : "–"
  end

  def departure_airport
    departure || "–"
  end

  def arrival_airport
    arrival || "–"
  end
end