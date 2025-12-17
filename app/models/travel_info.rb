class TravelInfo < ApplicationRecord
  belongs_to :user

  # JAL・新幹線用
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

  # Booking.com 用
  def checkin_datetime
    date ? "#{date} #{departure || '–'}" : "–" # date はチェックイン日, departure はホテル名
  end

  def checkout_datetime
    checkout_date ? "#{checkout_date} #{departure || '–'}" : "–"
  end

  def hotel_name
    departure || "–"
  end
end