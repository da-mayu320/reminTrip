class TravelInfosController < ApplicationController
  before_action :authenticate_user!  # Deviseを使用している場合

  # 旅行情報一覧
  def index
    @travel_infos = current_user.travel_infos&.order(flight_date: :desc) || []
  end

  # Gmailから旅行情報取得
  def fetch_from_gmail
    service = GmailFetcherService.new(user: current_user)
    service.fetch_and_save_travel_infos(provider: 'JAL', max_emails: 50)

    redirect_to travel_infos_path, notice: "最新の旅行情報を取得しました。"
  rescue StandardError => e
    Rails.logger.error "[GmailFetchError] #{e.class} #{e.message}\n#{e.backtrace.join("\n")}"
    redirect_to travel_infos_path, alert: "旅行情報の取得に失敗しました（#{e.class}）"
  end
end