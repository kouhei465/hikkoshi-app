require "rails_helper"
require "webmock/rspec"

RSpec.describe GoogleRoutesClient do
  subject(:client) { described_class.new(api_key: api_key) }

  let(:api_key) { "test-google-maps-api-key" }
  let(:origin) { "東京都新宿区西新宿2丁目8-1" }
  let(:destination) { "神奈川県横浜市中区日本大通1" }
  let(:endpoint) { described_class::ENDPOINT.to_s }

  def stub_routes_request(status: 200, body:)
    stub_request(:post, endpoint).with(
      body: {
        origin: { address: origin },
        destination: { address: destination },
        travelMode: "DRIVE",
        regionCode: "JP"
      }.to_json,
      headers: {
        "Content-Type" => "application/json",
        "X-Goog-Api-Key" => api_key,
        "X-Goog-FieldMask" => "routes.distanceMeters"
      }
    ).to_return(status:, body:, headers: { "Content-Type" => "application/json" })
  end

  describe "#distance_meters" do
    it "正常レスポンスからdistanceMetersを取得する" do
      request = stub_routes_request(body: { routes: [ { distanceMeters: 123_456 } ] }.to_json)

      expect(client.distance_meters(origin:, destination:)).to eq(123_456)
      expect(request).to have_been_requested.once
    end

    it "routesが空の場合は経路なしエラーにする" do
      stub_routes_request(body: { routes: [] }.to_json)

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::RouteNotFoundError)
    end

    it "400レスポンスの場合はリクエストエラーにする" do
      stub_routes_request(status: 400, body: { error: { message: "invalid request" } }.to_json)

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::RequestError)
    end

    it "403レスポンスの場合は認証エラーにする" do
      stub_routes_request(status: 403, body: { error: { message: "forbidden" } }.to_json)

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::AuthenticationError)
    end

    it "500レスポンスの場合は外部APIエラーにする" do
      stub_routes_request(status: 500, body: { error: { message: "server error" } }.to_json)

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::UpstreamError)
    end

    it "タイムアウトの場合はタイムアウトエラーにする" do
      stub_request(:post, endpoint).to_timeout

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::TimeoutError)
    end

    it "不正なJSONの場合はレスポンスエラーにする" do
      stub_routes_request(body: "not-json")

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::InvalidResponseError)
    end

    it "distanceMetersが不正な型の場合はレスポンスエラーにする" do
      stub_routes_request(body: { routes: [ { distanceMeters: "123456" } ] }.to_json)

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::InvalidResponseError)
    end

    it "distanceMetersが0以下の場合はレスポンスエラーにする" do
      stub_routes_request(body: { routes: [ { distanceMeters: 0 } ] }.to_json)

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::InvalidResponseError)
    end

    it "APIキーが未設定の場合は外部通信せず設定エラーにする" do
      client = described_class.new(api_key: nil)

      expect do
        client.distance_meters(origin:, destination:)
      end.to raise_error(described_class::ConfigurationError)
      expect(a_request(:post, endpoint)).not_to have_been_made
    end
  end
end
