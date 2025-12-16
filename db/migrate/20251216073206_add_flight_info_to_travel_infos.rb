class AddFlightInfoToTravelInfos < ActiveRecord::Migration[7.0]
  def change
    add_column :travel_infos, :flight_date, :date
    add_column :travel_infos, :reservation_number, :string
    add_column :travel_infos, :departure, :string
    add_column :travel_infos, :arrival, :string
  end
end
