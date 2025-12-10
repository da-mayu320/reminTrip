class CreateBoards < ActiveRecord::Migration[7.0]
  def change
    create_table :boards do |t|
      t.string :title
      t.string :departure_place
      t.datetime :departure_time
      t.string :arrival_place
      t.datetime :arrival_time
      t.string :booking_code
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
