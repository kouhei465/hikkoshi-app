require "json"
require "net/http"
require "openssl"
require "uri"

class GoogleRoutesClient
  ENDPOINT = URI("https://routes.googleapis.com/directions/v2:computeRoutes")
  FIELD_MASK = "routes.distanceMeters"
  OPEN_TIMEOUT = 3
  READ_TIMEOUT = 5
  WRITE_TIMEOUT = 5

  class Error < StandardError; end
  class ConfigurationError < Error; end
  class RequestError < Error; end
  class AuthenticationError < Error; end
  class RouteNotFoundError < Error; end
  class UpstreamError < Error; end
  class TimeoutError < Error; end
  class InvalidResponseError < Error; end

  def initialize(
    api_key: ENV["GOOGLE_MAPS_API_KEY"],
    open_timeout: OPEN_TIMEOUT,
    read_timeout: READ_TIMEOUT,
    write_timeout: WRITE_TIMEOUT
  )
    @api_key = api_key
    @open_timeout = open_timeout
    @read_timeout = read_timeout
    @write_timeout = write_timeout
  end

  def distance_meters(origin:, destination:)
    raise_failure(ConfigurationError, :api_key_missing) if api_key.blank?

    response = perform_request(origin:, destination:)
    handle_http_error(response) unless response.is_a?(Net::HTTPSuccess)
    extract_distance(response.body)
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
    raise_failure(TimeoutError, :timeout)
  rescue SocketError, EOFError, SystemCallError, OpenSSL::SSL::SSLError, Net::ProtocolError
    raise_failure(UpstreamError, :connection)
  end

  private

  attr_reader :api_key, :open_timeout, :read_timeout, :write_timeout

  def perform_request(origin:, destination:)
    request = Net::HTTP::Post.new(ENDPOINT.request_uri)
    request["Content-Type"] = "application/json"
    request["X-Goog-Api-Key"] = api_key
    request["X-Goog-FieldMask"] = FIELD_MASK
    request.body = {
      origin: { address: origin },
      destination: { address: destination },
      travelMode: "DRIVE",
      regionCode: "JP"
    }.to_json

    Net::HTTP.start(
      ENDPOINT.host,
      ENDPOINT.port,
      use_ssl: true,
      open_timeout:,
      read_timeout:,
      write_timeout:
    ) do |http|
      http.request(request)
    end
  end

  def handle_http_error(response)
    status = response.code.to_i
    error_class = case status
    when 400
                    RequestError
    when 401, 403
                    AuthenticationError
    else
                    UpstreamError
    end

    raise_failure(error_class, :http_error, status:)
  end

  def extract_distance(body)
    payload = JSON.parse(body)
    routes = payload["routes"] if payload.is_a?(Hash)

    raise_failure(InvalidResponseError, :invalid_routes) unless routes.is_a?(Array)
    raise_failure(RouteNotFoundError, :route_not_found) if routes.empty?

    distance = routes.first["distanceMeters"] if routes.first.is_a?(Hash)
    raise_failure(InvalidResponseError, :invalid_distance) unless distance.is_a?(Integer) && distance.positive?

    distance
  rescue JSON::ParserError
    raise_failure(InvalidResponseError, :invalid_json)
  end

  def raise_failure(error_class, reason, status: nil)
    details = [ "reason=#{reason}" ]
    details << "status=#{status}" if status
    Rails.logger.warn("Google Routes API request failed (#{details.join(', ')})")
    raise error_class
  end
end
