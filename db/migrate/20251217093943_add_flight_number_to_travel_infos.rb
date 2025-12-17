class AddFlightNumberToTravelInfos < ActiveRecord::Migration[7.0]
  def change
    add_column :travel_infos, :flight_number, :string
  end
end
