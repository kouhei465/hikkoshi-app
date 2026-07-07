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
end
