class UserSessionsController < ApplicationController
  before_action :redirect_logged_in_user, only: %i[new create]

  def new; end

  def create
    email = User.normalize_value_for(:email, params[:email])
    @user = login(email, params[:password])

    if @user
      redirect_to mypage_path, notice: "ログインしました"
    else
      flash.now[:alert] = "ログインに失敗しました"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: "ログアウトしました"
  end
end
