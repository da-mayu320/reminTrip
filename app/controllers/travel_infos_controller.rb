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

    # 取得後に一覧ページへ遷移
    redirect_to travel_infos_path, notice: "最新の旅行情報を取得しました。"
  rescue Google::Apis::AuthorizationError => e
    # 認証失敗時はユーザー画面に戻して再連携を促す
    redirect_to user_path, alert: "Gmailの認証に失敗しました。再連携してください。"
  end
end