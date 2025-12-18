class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    auth = request.env["omniauth.auth"]
    @user = User.from_omniauth(auth)

    if @user.persisted?
      sign_in @user, event: :authentication
      redirect_to travel_infos_path, notice: "Googleでログインしました"
    else
      redirect_to root_path, alert: "Google認証に失敗しました"
    end
  end
end
