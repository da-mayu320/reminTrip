class AddGoogleTokensToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :google_access_token, :string
    add_column :users, :google_refresh_token, :string
    add_column :users, :token_expires_at, :datetime
  end
end
