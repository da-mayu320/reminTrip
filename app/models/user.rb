class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  encrypts :google_access_token
  encrypts :google_refresh_token

  def self.from_omniauth(auth)
    user = find_or_initialize_by(email: auth.info.email)

    # 初回作成時のみ password を設定
    if user.new_record?
      user.password = Devise.friendly_token[0, 20]
    end

    user.provider             = auth.provider
    user.uid                  = auth.uid
    user.google_access_token  = auth.credentials.token

    # refresh_token は初回しか来ないので注意
    if auth.credentials.refresh_token.present?
      user.google_refresh_token = auth.credentials.refresh_token
    end

    user.token_expires_at     = Time.at(auth.credentials.expires_at)

    user.save!
    user
  end

  def google_connected?
    google_access_token.present? && google_refresh_token.present?
  end

  # Gmail API 用クライアントを返す（トークン自動更新）
  def google_api_client
    client = Signet::OAuth2::Client.new(
      client_id: ENV['GOOGLE_CLIENT_ID'],
      client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      token_credential_uri: 'https://oauth2.googleapis.com/token',
      access_token: google_access_token,
      refresh_token: google_refresh_token,
      expires_at: token_expires_at&.to_i
    )

    if client.expired?
      client.refresh!
      update!(
        google_access_token: client.access_token,
        token_expires_at: Time.at(client.expires_at)
      )
    end

    client
  end
end

