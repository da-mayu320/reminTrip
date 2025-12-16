class TravelInfosController < ApplicationController
  before_action :authenticate_user!

  def index
    infos = GmailFetcherService.new(user: current_user).fetch_travel_infos

    def index
    # まず Gmail から取得して DB に保存
    GmailFetcherService.new(user: current_user).fetch_and_save_travel_infos

    # DBから取得してビュー表示
    @travel_infos = current_user.travel_infos.order(created_at: :desc)
    end
  end
end