require "rails_helper"

RSpec.describe "引っ越し業者費用の距離概算", type: :request do
  let(:origin) { "東京都新宿区西新宿2丁目8-1" }
  let(:destination) { "神奈川県横浜市中区日本大通1" }
  let(:routes_client) { instance_double(GoogleRoutesClient) }

  before do
    allow(GoogleRoutesClient).to receive(:new).and_return(routes_client)
    allow(routes_client).to receive(:distance_meters)
  end

  describe "POST /moving_estimate" do
    it "通常の住所はそのまま使用し、距離と概算金額を返す" do
      allow(routes_client).to receive(:distance_meters).with(origin:, destination:).and_return(123_456)

      post moving_estimate_path, params: { origin:, destination: }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "distance_meters" => 123_456,
        "distance_km" => 123.5,
        "estimated_amount" => 50_000
      )
    end

    it "ハイフンありの郵便番号を日本の地点として正規化し、距離と概算金額を返す" do
      normalized_origin = "日本 〒870-0831"
      allow(routes_client).to receive(:distance_meters)
        .with(origin: normalized_origin, destination:)
        .and_return(12_345)

      post moving_estimate_path, params: { origin: " 870-0831 ", destination: }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        "distance_meters" => 12_345,
        "distance_km" => 12.3,
        "estimated_amount" => 30_000
      )
    end

    it "ハイフンなしの郵便番号を正規化する" do
      allow(routes_client).to receive(:distance_meters)
        .with(origin:, destination: "日本 〒870-0831")
        .and_return(123_456)

      post moving_estimate_path, params: { origin:, destination: "8700831" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(routes_client).to have_received(:distance_meters)
        .with(origin:, destination: "日本 〒870-0831")
    end

    it "全角数字と全角ハイフンを半角化して郵便番号を正規化する" do
      allow(routes_client).to receive(:distance_meters)
        .with(origin: "日本 〒870-0831", destination:)
        .and_return(123_456)

      post moving_estimate_path, params: { origin: "８７０－０８３１", destination: }, as: :json

      expect(response).to have_http_status(:ok)
      expect(routes_client).to have_received(:distance_meters)
        .with(origin: "日本 〒870-0831", destination:)
    end

    it "駅名や施設名を変更せず使用する" do
      station = "東京駅"
      facility = "東京スカイツリー"
      allow(routes_client).to receive(:distance_meters)
        .with(origin: station, destination: facility)
        .and_return(10_000)

      post moving_estimate_path, params: { origin: station, destination: facility }, as: :json

      expect(response).to have_http_status(:ok)
      expect(routes_client).to have_received(:distance_meters)
        .with(origin: station, destination: facility)
    end

    it "数字とハイフンだけの不正な郵便番号形式はAPIを呼ばず入力エラーを返す" do
      [ "870-831", "8700-831", "870--0831", "870083" ].each do |invalid_postal_code|
        post moving_estimate_path,
             params: { origin: invalid_postal_code, destination: },
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq(
          "error" => "出発地の郵便番号は「123-4567」または「1234567」の形式で入力してください"
        )
      end

      expect(routes_client).not_to have_received(:distance_meters)
    end

    it "出発地が空の場合はAPIを呼ばず入力エラーを返す" do
      post moving_estimate_path, params: { origin: " ", destination: }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "出発地を入力してください")
      expect(routes_client).not_to have_received(:distance_meters)
    end

    it "到着地が空の場合はAPIを呼ばず入力エラーを返す" do
      post moving_estimate_path, params: { origin:, destination: " " }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "到着地を入力してください")
      expect(routes_client).not_to have_received(:distance_meters)
    end

    it "住所が200文字を超える場合はAPIを呼ばず入力エラーを返す" do
      post moving_estimate_path, params: { origin: "あ" * 201, destination: }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "出発地は200文字以内で入力してください")
      expect(routes_client).not_to have_received(:distance_meters)
    end

    it "サービスでエラーが起きた場合は安全な日本語エラーを返す" do
      allow(routes_client).to receive(:distance_meters).and_raise(GoogleRoutesClient::UpstreamError)

      post moving_estimate_path, params: { origin:, destination: }, as: :json

      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body).to eq(
        "error" => "距離を計算できませんでした。時間をおいて再度お試しください"
      )
    end

    it "APIキーなどの秘密情報をレスポンスに含めない" do
      secret = "response-must-not-contain-this-api-key"
      allow(routes_client).to receive(:distance_meters)
        .and_raise(GoogleRoutesClient::AuthenticationError, secret)

      post moving_estimate_path, params: { origin:, destination: }, as: :json

      expect(response).to have_http_status(:service_unavailable)
      expect(response.body).not_to include(secret)
      expect(response.body).not_to include("GOOGLE_MAPS_API_KEY")
    end
  end
end
