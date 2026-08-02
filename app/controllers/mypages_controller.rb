class MypagesController < ApplicationController
  before_action :require_logged_in_user
  before_action :reject_google_only_user, only: %i[edit update]

  def show
    @cost_lists = current_user.cost_lists.order(created_at: :desc)
  end

  def edit
    prepare_email_form
  end

  def update
    permitted_params = email_change_params
    prepare_email_form(permitted_params[:email])

    if permitted_params[:current_password].blank?
      return render_update_error(t(".current_password_blank"))
    end

    unless current_user.valid_password?(permitted_params[:current_password])
      return render_update_error(t(".invalid_current_password"))
    end

    normalized_email = permitted_params[:email].to_s.strip.downcase

    if normalized_email.blank?
      return render_update_error(t(".email_blank"))
    end

    if normalized_email == @current_email.to_s.strip.downcase
      return render_update_error(t(".same_email"))
    end

    if email_used_by_another_user?(normalized_email)
      return render_update_error(t(".email_taken"))
    end

    if current_user.update(email: normalized_email)
      redirect_to mypage_path, notice: t(".success")
    else
      render_update_error(t(".failure"))
    end
  end

  private

  def require_logged_in_user
    return if logged_in?

    redirect_to login_path, alert: "ログインしてください"
  end

  def reject_google_only_user
    return unless current_user.google_only?

    redirect_to mypage_path, alert: t("mypages.google_only_edit_forbidden")
  end

  def email_change_params
    params.require(:user).permit(:email, :current_password)
  end

  def prepare_email_form(submitted_email = nil)
    @user = current_user
    @current_email = current_user.email
    @submitted_email = submitted_email
  end

  def email_used_by_another_user?(email)
    User.where.not(id: current_user.id).where("LOWER(email) = ?", email).exists?
  end

  def render_update_error(message)
    flash.now[:alert] = message
    render :edit, status: :unprocessable_content
  end
end
