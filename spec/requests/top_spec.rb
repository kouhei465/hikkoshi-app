require "rails_helper"

RSpec.describe "トップページ", type: :request do
  describe "GET /" do
    it "正常にアクセスできること" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end
end
