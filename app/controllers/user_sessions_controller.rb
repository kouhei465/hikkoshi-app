class UserSessionsController < ApplicationController
  before_action :redirect_logged_in_user, only: %i[new create]

  def new; end

  def create
    draft = current_cost_list_draft
    email = User.normalize_value_for(:email, params[:email])
    @user = login(email, params[:password])

    if @user
      retain_cost_list_draft_after_login(draft)
      redirect_to(draft ? result_cost_lists_path : mypage_path, notice: "ログインしました")
    else
      flash.now[:alert] = "ログインに失敗しました"
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    discard_cost_list_draft
    logout
    redirect_to root_path, notice: "ログアウトしました"
  end
end
