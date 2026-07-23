require "rails_helper"

RSpec.describe "トップページ", type: :request do
  describe "GET /" do
    it "正常にアクセスできること" do
      get root_path

      expect(response).to have_http_status(:ok)
    end

    it "サイト名がtitle要素とヘッダーに表示されること" do
      get root_path

      document = Nokogiri::HTML(response.body)

      expect(document.at_css("title").text).to eq("引っ越し費用まとめ帳")
      expect(document.at_css("header a[href='/']").text).to eq("引っ越し費用まとめ帳")
    end
  end
end
