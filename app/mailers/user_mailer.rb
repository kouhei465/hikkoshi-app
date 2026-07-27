class UserMailer < ApplicationMailer
  def reset_password_email(user)
    @user = user
    @reset_password_url = edit_password_reset_url(@user.reset_password_token)

    mail(
      to: @user.email,
      subject: I18n.t("user_mailer.reset_password_email.subject")
    )
  end
end
