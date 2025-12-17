class AddCheckoutDateToTravelInfos < ActiveRecord::Migration[7.0]
  def change
    add_column :travel_infos, :checkout_date, :date
  end
end
