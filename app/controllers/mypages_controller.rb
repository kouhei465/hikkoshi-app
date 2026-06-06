class MypagesController < ApplicationController
  def show
    return redirect_to login_path, alert: "ログインしてください" unless logged_in?

    @cost_lists = current_user.cost_lists.order(created_at: :desc)
  end
end
