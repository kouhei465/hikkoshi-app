class AccountDeletionsController < ApplicationController
  CONFIRMATION_FIELDS = %i[
    user_information_confirmed
    google_authentication_confirmed
    cost_data_confirmed
    irreversible_confirmed
  ].freeze
  PERMITTED_FIELDS = (CONFIRMATION_FIELDS + [ :current_password ]).freeze

  before_action :require_logged_in_user

  def show
    @confirmations = CONFIRMATION_FIELDS.index_with(false)
    @password_required = !current_user.google_only?
  end

  def destroy
    permitted_params = account_deletion_params
    @confirmations = confirmations_from(permitted_params)
    @password_required = !current_user.google_only?

    return render_deletion_error(t(".confirmations_incomplete")) unless @confirmations.values.all?

    if @password_required
      current_password = permitted_params[:current_password].to_s
      return render_deletion_error(t(".current_password_blank")) if current_password.blank?
      unless current_user.valid_password?(current_password)
        return render_deletion_error(t(".invalid_current_password"))
      end
    end

    user = current_user
    return render_deletion_error(t(".failure")) unless destroy_account(user)

    reset_session
    redirect_to root_path, notice: t(".success")
  end

  private

  def account_deletion_params
    params.permit(account_deletion: PERMITTED_FIELDS)[:account_deletion] || ActionController::Parameters.new
  end

  def confirmations_from(permitted_params)
    CONFIRMATION_FIELDS.index_with do |field|
      boolean_type.cast(permitted_params[field])
    end
  end

  def boolean_type
    @boolean_type ||= ActiveModel::Type::Boolean.new
  end

  def destroy_account(user)
    ActiveRecord::Base.transaction do
      user.destroy!
    end

    true
  rescue StandardError => error
    Rails.logger.error("Account deletion failed (user_id=#{user.id}, error=#{error.class})")
    false
  end

  def render_deletion_error(message)
    flash.now[:alert] = message
    render :show, status: :unprocessable_content
  end
end
