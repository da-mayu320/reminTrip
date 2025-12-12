class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    # ここにログイン処理を入れる
    # 例としてユーザーを作る/取得してサインイン
    @user = User.from_omniauth(request.env["omniauth.auth"])

    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: "Google") if is_navigational_format?
    else
      session["devise.google_data"] = request.env["omniauth.auth"].except(:extra)
      redirect_to new_user_registration_url, alert: "Googleアカウントでのログインに失敗しました"
    end
  end
end