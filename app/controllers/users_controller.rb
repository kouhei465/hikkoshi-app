class UsersController < ApplicationController
  before_action :redirect_logged_in_user, only: %i[new create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      draft = current_cost_list_draft
      auto_login(@user)
      saved_cost_list = GuestCostListSaver.call(user: @user, attributes: draft&.data)

      if saved_cost_list&.persisted?
        discard_cost_list_draft
        redirect_to mypage_path, notice: "ユーザー登録と費用リストの保存が完了しました"
      elsif saved_cost_list
        retain_cost_list_draft_after_login(draft)
        redirect_to result_cost_lists_path,
                    alert: "ユーザー登録は完了しましたが、費用リストの保存に失敗しました：#{saved_cost_list.errors.full_messages.to_sentence}"
      else
        redirect_to mypage_path, notice: "ユーザー登録が完了しました"
      end
    else
      flash.now[:alert] = "ユーザー登録に失敗しました"
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
