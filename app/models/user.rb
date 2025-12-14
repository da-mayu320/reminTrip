class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  encrypts :google_access_token
  encrypts :google_refresh_token

  has_many :boards, dependent: :destroy

  def self.from_omniauth(auth)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize

    user.email = auth.info.email
    user.name  = auth.info.name if user.name.blank?
    user.password ||= Devise.friendly_token[0, 20]

    user.google_access_token  = auth.credentials.token
    user.google_refresh_token = auth.credentials.refresh_token if auth.credentials.refresh_token.present?
    user.token_expires_at     = Time.at(auth.credentials.expires_at)

    user.save!
    user
  end

  def google_connected?
    provider.present? && uid.present?
  end
end

