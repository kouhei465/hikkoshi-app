class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      auto_login(@user)

      if session[:cost_list_params].present?
        cost_list = @user.cost_lists.build(session[:cost_list_params])
        cost_list.title = "引っ越し費用リスト"

        if cost_list.save
          session.delete(:cost_list_params)
          redirect_to cost_list_path(cost_list), notice: "ユーザー登録と費用リストの保存が完了しました"
        else
          redirect_to mypage_path, alert: "ユーザー登録は完了しましたが、費用リストの保存に失敗しました"
        end
      else
        redirect_to mypage_path, notice: "ユーザー登録が完了しました"
      end
    else
      flash.now[:alert] = "ユーザー登録に失敗しました"
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
