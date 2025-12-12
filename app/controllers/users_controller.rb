class UsersController < ApplicationController
  before_action :authenticate_user!  # ログイン必須

  def show
    @user = current_user
  end
end

