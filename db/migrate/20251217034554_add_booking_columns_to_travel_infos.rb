class AddBookingColumnsToTravelInfos < ActiveRecord::Migration[7.0]
  def change
    add_column :travel_infos, :checkin_date, :date unless column_exists?(:travel_infos, :checkin_date)
    add_column :travel_infos, :checkout_date, :date unless column_exists?(:travel_infos, :checkout_date)
    add_column :travel_infos, :hotel_name, :string unless column_exists?(:travel_infos, :hotel_name)
  end
end

