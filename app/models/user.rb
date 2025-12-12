class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]
         
  encrypts :google_access_token
  encrypts :google_refresh_token

  has_many :boards, dependent: :destroy

  def self.from_omniauth(auth)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize

    user.email = auth.info.email
    user.name  = auth.info.name

  # 初回ユーザーはパスワード生成
    user.password ||= Devise.friendly_token[0, 20]

  # トークン更新は毎回やる！
    user.google_access_token  = auth.credentials.token
    user.google_refresh_token = auth.credentials.refresh_token if auth.credentials.refresh_token.present?

    user.save!
    user
  end

  def google_connected?
    provider.present? && uid.present?
  end
end
