class MovingEstimatesController < ApplicationController
  MAX_ADDRESS_LENGTH = 200
  POSTAL_CODE_PATTERN = /\A([0-9]{3})-?([0-9]{4})\z/
  POSTAL_CODE_CANDIDATE_PATTERN = /\A[0-9-]+\z/

  def create
    addresses = params.permit(:origin, :destination)
    origin = normalize_input(addresses[:origin])
    destination = normalize_input(addresses[:destination])

    return render_error("出発地を入力してください", :unprocessable_content) if origin.blank?
    return render_error("到着地を入力してください", :unprocessable_content) if destination.blank?
    return render_error("出発地は200文字以内で入力してください", :unprocessable_content) if origin.length > MAX_ADDRESS_LENGTH
    if destination.length > MAX_ADDRESS_LENGTH
      return render_error("到着地は200文字以内で入力してください", :unprocessable_content)
    end
    return render_postal_code_error("出発地") if invalid_postal_code?(origin)
    return render_postal_code_error("到着地") if invalid_postal_code?(destination)

    origin = normalize_postal_code(origin)
    destination = normalize_postal_code(destination)

    distance_meters = GoogleRoutesClient.new.distance_meters(origin:, destination:)
    estimated_amount = MovingEstimateCalculator.call(distance_meters)

    render json: {
      distance_meters:,
      distance_km: (distance_meters / 1000.0).round(1),
      estimated_amount:
    }
  rescue GoogleRoutesClient::RequestError, GoogleRoutesClient::RouteNotFoundError => error
    log_failure(error)
    render_error("住所を特定できないか、経路が見つかりませんでした", :unprocessable_content)
  rescue GoogleRoutesClient::ConfigurationError, GoogleRoutesClient::AuthenticationError => error
    log_failure(error)
    render_error("距離計算機能を利用できません", :service_unavailable)
  rescue GoogleRoutesClient::TimeoutError => error
    log_failure(error)
    render_error("距離計算がタイムアウトしました。時間をおいて再度お試しください", :gateway_timeout)
  rescue GoogleRoutesClient::UpstreamError, GoogleRoutesClient::InvalidResponseError => error
    log_failure(error)
    render_error("距離を計算できませんでした。時間をおいて再度お試しください", :bad_gateway)
  end

  private

  def normalize_input(value)
    return unless value.is_a?(String)

    value.squish.tr("０-９", "0-9").tr("－", "-")
  end

  def invalid_postal_code?(value)
    value.match?(POSTAL_CODE_CANDIDATE_PATTERN) && !value.match?(POSTAL_CODE_PATTERN)
  end

  def normalize_postal_code(value)
    match = POSTAL_CODE_PATTERN.match(value)
    return value unless match

    "日本 〒#{match[1]}-#{match[2]}"
  end

  def render_postal_code_error(label)
    render_error("#{label}の郵便番号は「123-4567」または「1234567」の形式で入力してください", :unprocessable_content)
  end

  def render_error(message, status)
    render json: { error: message }, status:
  end

  def log_failure(error)
    Rails.logger.warn("Moving estimate failed (#{error.class})")
  end
end
