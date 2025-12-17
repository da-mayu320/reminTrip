class TravelInfosController < ApplicationController
  before_action :authenticate_user!

  def index
    @flights = current_user.travel_infos.order(flight_date: :asc)
  end

  def fetch_from_gmail
    GmailFetcherService
      .new(user: current_user)
      .fetch_and_save_travel_infos(provider: 'JAL', max_emails: 10)

    redirect_to travel_infos_path, notice: 'Gmailから旅行情報を取得しました'
  rescue => e
    Rails.logger.error e
    redirect_to travel_infos_path, alert: 'メールの取得に失敗しました'
  end
end
