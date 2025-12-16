class CreateTravelInfos < ActiveRecord::Migration[7.0]
  def change
    create_table :travel_infos do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider
      t.string :message_id
      t.string :thread_id
      t.text :snippet
      t.datetime :received_at

      t.timestamps
    end
  end
end
