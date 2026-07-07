require "rails_helper"

RSpec.describe "マイページ", type: :request do
  describe "GET /mypage" do
    context "未ログインの場合" do
      it "ログインページにリダイレクトされること" do
        get mypage_path

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("ログインしてください")
      end
    end
  end
end
