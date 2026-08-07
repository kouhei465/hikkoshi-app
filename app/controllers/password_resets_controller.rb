class PasswordResetsController < ApplicationController
  before_action :set_user_from_token, only: %i[edit update]

  def new; end

  def create
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email)
    user.deliver_reset_password_instructions! if user && !user.google_only?

    redirect_to login_path, notice: t(".instructions_sent")
  end

  def edit; end

  def update
    password = password_params[:password]
    @user.password_confirmation = password_params[:password_confirmation]

    if password.nil?
      @user.errors.add(:password, :blank)
      render :edit, status: :unprocessable_entity
    elsif @user.change_password(password)
      redirect_to login_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_from_token
    @token = params[:id]
    @user = User.load_from_reset_password_token(@token)

    return if @user

    redirect_to new_password_reset_path, alert: t("password_resets.invalid_token")
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
