require "rails_helper"

RSpec.describe "静的ページ", type: :request do
  describe "GET /terms" do
    it "正常にアクセスできること" do
      get terms_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /privacy" do
    it "正常にアクセスできること" do
      get privacy_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /guide" do
    it "正常にアクセスできること" do
      get guide_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("使い方")
    end
  end
end
