class GoogleController < ApplicationController
  def callback
    auth_info = request.env['omniauth.auth']

    # 一旦、ログに出すだけ
    Rails.logger.info auth_info.to_json

    redirect_to root_path, notice: "Google連携が成功しました"
  end
end
