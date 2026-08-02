class GoogleOauthsController < ApplicationController
  PROVIDER = :google
  STATE_SESSION_KEY = :google_oauth_state

  def oauth
    return redirect_to(mypage_path, alert: t("google_oauths.already_logged_in")) if logged_in?

    unless google_configured?
      return redirect_to(login_path, alert: t("google_oauths.not_configured"))
    end

    state = SecureRandom.urlsafe_base64(32)
    session[STATE_SESSION_KEY] = state
    login_at(PROVIDER, state:)
  rescue StandardError => error
    session.delete(STATE_SESSION_KEY)
    log_oauth_failure(error)
    redirect_to login_path, alert: t("google_oauths.failed")
  end

  def callback
    expected_state = session.delete(STATE_SESSION_KEY)

    unless valid_state?(expected_state, params[:state])
      return redirect_to(login_path, alert: t("google_oauths.invalid_state"))
    end

    return redirect_to(mypage_path, alert: t("google_oauths.already_logged_in")) if logged_in?

    if params[:error].present?
      message = params[:error] == "access_denied" ? t("google_oauths.cancelled") : t("google_oauths.failed")
      return redirect_to(login_path, alert: message)
    end

    unless google_configured? && params[:code].present?
      return redirect_to(login_path, alert: t("google_oauths.failed"))
    end

    if login_from(PROVIDER)
      return redirect_to(mypage_path, notice: t("google_oauths.logged_in"))
    end

    register_google_user
  rescue ActiveRecord::RecordNotUnique => error
    session.delete(:incomplete_user)
    log_oauth_failure(error)
    redirect_to login_path, alert: t("google_oauths.registration_conflict")
  rescue StandardError => error
    session.delete(:incomplete_user)
    log_oauth_failure(error)
    redirect_to login_path, alert: t("google_oauths.failed")
  end

  private

  def register_google_user
    google_attributes = validated_google_attributes
    return redirect_to(login_path, alert: t("google_oauths.missing_information")) unless google_attributes

    if User.where("LOWER(email) = ?", google_attributes[:email]).exists?
      return redirect_to(login_path, alert: t("google_oauths.duplicate_email"))
    end

    normalize_user_hash!(google_attributes)
    user = create_and_validate_from(PROVIDER)

    unless user.persisted?
      session.delete(:incomplete_user)
      return redirect_to(login_path, alert: t("google_oauths.failed"))
    end

    finish_registration(user)
  end

  def validated_google_attributes
    user_info = @user_hash[:user_info]
    return unless user_info.is_a?(Hash)

    uid = @user_hash[:uid].to_s.strip
    email = user_info["email"].to_s.strip.downcase
    name = user_info["name"].to_s.strip

    return if uid.blank? || email.blank? || name.blank?
    return if user_info.key?("verified_email") && user_info["verified_email"] != true

    { uid:, email:, name: }
  end

  def normalize_user_hash!(attributes)
    @user_hash[:uid] = attributes[:uid]
    @user_hash[:user_info]["email"] = attributes[:email]
    @user_hash[:user_info]["name"] = attributes[:name]
  end

  def finish_registration(user)
    guest_attributes = session[:cost_list_params]&.deep_dup
    save_result = GuestCostListSaver.call(user:, attributes: guest_attributes)

    session.delete(:cost_list_params) if save_result == :saved
    session.delete(:incomplete_user)
    reset_sorcery_session
    auto_login(user)
    after_login!(user)
    session[:cost_list_params] = guest_attributes if save_result == :failed

    redirect_to mypage_path, **registration_flash(save_result)
  end

  def registration_flash(save_result)
    case save_result
    when :saved
      { notice: t("google_oauths.registered_with_cost_list") }
    when :failed
      { alert: t("google_oauths.cost_list_failed") }
    else
      { notice: t("google_oauths.registered") }
    end
  end

  def google_configured?
    config = Sorcery::Controller::Config.google
    config.key.present? && config.secret.present? && config.callback_url.present?
  end

  def valid_state?(expected_state, received_state)
    expected = expected_state.to_s
    received = received_state.to_s

    return false if expected.blank? || received.blank?
    return false unless expected.bytesize == received.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, received)
  end

  def log_oauth_failure(error)
    Rails.logger.warn("Google OAuth failed (#{error.class})")
  end
end
