class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  private

  def require_logged_in_user
    return if logged_in?

    redirect_to login_path, alert: "ログインしてください"
  end

  def redirect_logged_in_user
    return unless logged_in?

    redirect_to mypage_path, alert: "すでにログインしています"
  end
end
