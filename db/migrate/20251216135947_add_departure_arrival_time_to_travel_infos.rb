class AddDepartureArrivalTimeToTravelInfos < ActiveRecord::Migration[7.0]
  def change
    add_column :travel_infos, :departure_time, :string
    add_column :travel_infos, :arrival_time, :string
  end
end
