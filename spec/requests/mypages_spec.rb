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

    context "ログイン済みの場合" do
      it "複数の費用リストと各操作への導線が表示されること" do
        user = User.create!(
          name: "一覧テストユーザー",
          email: "mypage@example.com",
          password: "password",
          password_confirmation: "password"
        )
        first_cost_list = user.cost_lists.create!(title: "A物件の費用")
        second_cost_list = user.cost_lists.create!(title: "B物件の費用")

        post login_path, params: {
          email: user.email,
          password: "password"
        }

        get mypage_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("A物件の費用")
        expect(response.body).to include("B物件の費用")
        expect(response.body).to include("詳細を見る")
        expect(response.body).to include("編集する")
        expect(response.body).to include("名前を変更")
        expect(response.body).to include("削除する")
        expect(response.body).to include(update_title_cost_list_path(first_cost_list))
        expect(response.body).to include(update_title_cost_list_path(second_cost_list))

        modal_ids = response.body.scan(/id="(rename-cost-list-modal-\d+)"/).flatten

        expect(modal_ids).to contain_exactly(
          "rename-cost-list-modal-#{first_cost_list.id}",
          "rename-cost-list-modal-#{second_cost_list.id}"
        )
      end
    end
  end
end
