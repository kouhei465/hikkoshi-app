class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      auto_login(@user)

      case GuestCostListSaver.call(user: @user, attributes: session[:cost_list_params])
      when :saved
        session.delete(:cost_list_params)
        redirect_to mypage_path, notice: "ユーザー登録と費用リストの保存が完了しました"
      when :failed
        redirect_to mypage_path, alert: "ユーザー登録は完了しましたが、費用リストの保存に失敗しました"
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
